//
//  CustomMapHeaderCell.swift
//  Spot
//
//  Created by Arnold on 7/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import SnapKit
import UIKit
import SDWebImage

protocol CustomMapHeaderDelegate: AnyObject {
    func openFriendsList(add: Bool)
    func openEditMap()
    func followMap()
    func shareMap()
    func openFounderProfile()
}

final class CustomMapHeaderCell: UICollectionViewCell {
    var mapData: CustomMap?
    weak var delegate: CustomMapHeaderDelegate?
    private var memberProfiles: [UserProfile] = []

    private lazy var mapCoverImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 19
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private lazy var mapName: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        label.text = ""
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var mapCreatorProfileImage1 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage2 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage3 = MapCreatorProfileImage(frame: .zero)
    private lazy var mapCreatorProfileImage4 = MapCreatorProfileImage(frame: .zero)

    private lazy var mapCreatorCount: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 13)
        label.text = ""
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var founderButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(founderTap), for: .touchUpInside)
        button.setTitleColor(UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 13)
        return button
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.851, green: 0.851, blue: 0.851, alpha: 1)
        return view
    }()

    private lazy var joinedCount: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(friendsListTap), for: .touchUpInside)
        button.setTitleColor(UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 13)
        return button
    }()

    private lazy var secretMapCreatorsButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(friendsListTap), for: .touchUpInside)
        return button
    }()

    lazy var actionButton: PillButtonWithImage = {
        let button = PillButtonWithImage()
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = .clear
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 12
        button.isHidden = true
        button.addTarget(self, action: #selector(actionButtonAction), for: .touchUpInside)
        return button
    }()

    private lazy var shareMapButton: UIButton = {
        let button = PillButtonWithImage()
        button.setUp(image: UIImage(named: "WhiteShareButton") ?? UIImage(), title: "Share Map", titleColor: .white)
        button.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
        button.isHidden = true
        button.addTarget(self, action: #selector(shareMapTap), for: .touchUpInside)
        return button
    }()

    private lazy var editButton: UIButton = {
        let button = UIButton()
        button.setTitle("Edit Map", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 12
        button.isHidden = true
        button.addTarget(self, action: #selector(editTap), for: .touchUpInside)
        return button
    }()

    private lazy var mapBio: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.00)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        label.text = ""
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapCoverImage.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage1.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage2.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage3.sd_cancelCurrentImageLoad()
        mapCreatorProfileImage4.sd_cancelCurrentImageLoad()
    }

    public func cellSetup(mapData: CustomMap?, memberProfiles: [UserProfile]) {
        guard mapData != nil else { return }
        self.mapData = mapData
        self.memberProfiles = memberProfiles

        setMapName()
        setMapMemberInfo()
        setActionButton()

        mapBio.text = mapData?.mapDescription ?? ""
    }
}

extension CustomMapHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(mapCoverImage)
        mapCoverImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalTo(15)
            $0.width.height.equalTo(84)
        }

        contentView.addSubview(mapName)
        mapName.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(12)
            $0.bottom.equalTo(mapCoverImage.snp.centerY).offset(-2)
            $0.trailing.equalToSuperview().inset(14)
        }

        contentView.addSubview(mapCreatorProfileImage1)
        mapCreatorProfileImage1.snp.makeConstraints {
            $0.top.equalTo(mapName.snp.bottom).offset(4)
            $0.leading.equalTo(mapName)
            $0.width.equalTo(28)
            $0.height.equalTo(31.5)
        }

        contentView.addSubview(mapCreatorProfileImage2)
        mapCreatorProfileImage2.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage1).offset(19)
            $0.width.equalTo(28)
            $0.height.equalTo(31.5)
        }

        contentView.addSubview(mapCreatorProfileImage3)
        mapCreatorProfileImage3.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage2).offset(19)
            $0.width.equalTo(28)
            $0.height.equalTo(31.5)
        }

        contentView.addSubview(mapCreatorProfileImage4)
        mapCreatorProfileImage4.snp.makeConstraints {
            $0.top.equalTo(mapCreatorProfileImage1)
            $0.leading.equalTo(mapCreatorProfileImage3).offset(19)
            $0.width.equalTo(28)
            $0.height.equalTo(31.5)
        }

        contentView.addSubview(mapCreatorCount)

        contentView.addSubview(founderButton)
        founderButton.snp.makeConstraints {
            $0.leading.equalTo(mapName)
            $0.top.equalTo(mapName.snp.bottom).offset(2)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(founderButton.snp.trailing).offset(5)
            $0.centerY.equalTo(founderButton).offset(1)
            $0.height.width.equalTo(2)
        }

        contentView.addSubview(joinedCount)
        joinedCount.snp.makeConstraints {
            $0.centerY.equalTo(founderButton)
            $0.leading.equalTo(separatorView.snp.trailing).offset(5)
        }

        contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.bottom.equalToSuperview().inset(12)
        }

        contentView.addSubview(editButton)
        let spacing: CGFloat = 18 + 14 + 6
        editButton.snp.makeConstraints {
            $0.leading.bottom.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.42)
        }

        contentView.addSubview(shareMapButton)
        shareMapButton.snp.makeConstraints {
            $0.leading.equalTo(editButton.snp.trailing).offset(6)
            $0.top.height.equalTo(actionButton)
            $0.width.equalTo((UIScreen.main.bounds.width - spacing) * 0.58)
        }

        contentView.addSubview(mapBio)
        mapBio.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(19)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(12)
        }

        contentView.addSubview(secretMapCreatorsButton)
    }

    private func setMapName() {
        guard let mapData = mapData else { return }
        if mapData.secret {
            let str = mapData.mapName
            mapName.attributedText = str.getAttributedStringWithImage(image: UIImage(named: "PinkLockIcon") ?? UIImage(), topOffset: 0)
        } else {
            mapName.text = mapData.mapName
            mapName.sizeToFit()
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        mapCoverImage.sd_setImage(with: URL(string: mapData.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
    }

    private func setMapMemberInfo() {
        guard let mapData = mapData, !mapData.memberIDs.isEmpty else { return }

        if mapData.memberIDs.count < 7 && mapData.secret {
            if memberProfiles.isEmpty { return }
            founderButton.isHidden = true
            separatorView.isHidden = true
            joinedCount.isHidden = true
            let userTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            let image1 = memberProfiles[0].getAvatarImage()
            if image1 != UIImage() {
                mapCreatorProfileImage1.image = image1
            } else {
                mapCreatorProfileImage1.sd_setImage(with: URL(string: memberProfiles[0].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
            }

            switch memberProfiles.count {
            case 1:
                mapCreatorCount.text = "\(memberProfiles[0].username)"
            case 2:
                mapCreatorCount.text = "\(memberProfiles[0].username) & \(memberProfiles[1].username)"
                let image2 = memberProfiles[1].getAvatarImage()
                if image2 != UIImage () {
                    mapCreatorProfileImage2.image = image2
                } else {
                    mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }
            case 3:
                mapCreatorCount.text = "\(memberProfiles[0].username) + \(mapData.memberIDs.count - 1)"
                let image2 = memberProfiles[1].getAvatarImage()
                if image2 != UIImage () {
                    mapCreatorProfileImage2.image = image2
                } else {
                    mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }

                let image3 = memberProfiles[2].getAvatarImage()
                if image3 != UIImage () {
                    mapCreatorProfileImage3.image = image3
                } else {
                    mapCreatorProfileImage3.sd_setImage(with: URL(string: memberProfiles[2].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }
            case 4:
                mapCreatorCount.text = "\(memberProfiles[0].username) + \(mapData.memberIDs.count - 1)"
                let image2 = memberProfiles[1].getAvatarImage()
                if image2 != UIImage () {
                    mapCreatorProfileImage2.image = image2
                } else {
                    mapCreatorProfileImage2.sd_setImage(with: URL(string: memberProfiles[1].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }

                let image3 = memberProfiles[2].getAvatarImage()
                if image3 != UIImage () {
                    mapCreatorProfileImage3.image = image3
                } else {
                    mapCreatorProfileImage3.sd_setImage(with: URL(string: memberProfiles[2].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }

                let image4 = memberProfiles[3].getAvatarImage()
                if image4 != UIImage () {
                    mapCreatorProfileImage4.image = image4
                } else {
                    mapCreatorProfileImage4.sd_setImage(with: URL(string: memberProfiles[3].avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: userTransformer])
                }
            default:
                return
            }
            makeMapNameConstraints()
        } else {
            // show joined icon if >7 members
            founderButton.isHidden = false
            founderButton.setTitle("by \(mapData.posterUsernames.first ?? "")", for: .normal)
            separatorView.isHidden = false
            joinedCount.isHidden = false
            joinedCount.setTitle("\(mapData.memberIDs.count) joined", for: .normal)
        }
    }

    private func makeMapNameConstraints() {
        mapCreatorCount.snp.removeConstraints()
        secretMapCreatorsButton.snp.removeConstraints()
        let joinedShowing = mapData?.memberIDs.count ?? 0 > 6 || !(mapData?.secret ?? false)

        mapCreatorProfileImage1.isHidden = joinedShowing
        mapCreatorProfileImage2.isHidden = joinedShowing || memberProfiles.count < 2
        mapCreatorProfileImage3.isHidden = joinedShowing || memberProfiles.count < 3
        mapCreatorProfileImage4.isHidden = joinedShowing || memberProfiles.count < 4

        mapCreatorCount.snp.makeConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(14)
            if joinedShowing {
                $0.leading.equalTo(mapName)
                $0.top.equalTo(mapName.snp.bottom).offset(7)
            } else {
                $0.centerY.equalTo(mapCreatorProfileImage1).offset(2)
                switch memberProfiles.count {
                case 1: $0.leading.equalTo(mapCreatorProfileImage1.snp.trailing).offset(3)
                case 2: $0.leading.equalTo(mapCreatorProfileImage2.snp.trailing).offset(3)
                case 3: $0.leading.equalTo(mapCreatorProfileImage3.snp.trailing).offset(3)
                case 4: $0.leading.equalTo(mapCreatorProfileImage4.snp.trailing).offset(3)
                default: return
                }
            }
        }

        secretMapCreatorsButton.snp.makeConstraints {
            $0.leading.equalTo(mapCoverImage.snp.trailing).offset(5)
            $0.top.equalTo(mapName.snp.bottom).offset(4)
            $0.height.equalTo(28)
            $0.trailing.equalTo(mapCreatorCount.snp.trailing)
        }
    }

    private func setActionButton() {
        guard let mapData = mapData else { return }
        if mapData.founderID == UserDataModel.shared.uid {
            // show 2 button view
            actionButton.isHidden = true
            editButton.isHidden = false
            shareMapButton.isHidden = false

        } else {
            // show singular action button
            actionButton.isHidden = false
            editButton.isHidden = true
            shareMapButton.isHidden = true

            if mapData.likers.contains(UserDataModel.shared.uid) {
                print("set up share map")
                actionButton.setUp(image: UIImage(named: "WhiteShareButton"), title: "Share map", titleColor: .white)
                actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)

            } else if !mapData.secret, !mapData.likers.isEmpty {
                print("set up join map")
                actionButton.setUp(image: UIImage(), title: "Join map", titleColor: .black)
                actionButton.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
            } else {
                actionButton.isHidden = true
            }
        }
    }

    @objc func editTap() {
        delegate?.openEditMap()
    }

    @objc func actionButtonAction() {
        let titleText = actionButton.label.text
        switch titleText {
        case "Join map":
            delegate?.followMap()
        default:
            delegate?.shareMap()
        }
    }

    @objc func friendsListTap() {
        Mixpanel.mainInstance().track(event: "CustomMapMembersTap")
        delegate?.openFriendsList(add: false)
    }

    @objc func founderTap() {
        Mixpanel.mainInstance().track(event: "CustomMapFounderTap")
        delegate?.openFounderProfile()
    }

    @objc func shareMapTap() {
        delegate?.shareMap()
    }
}

class MapCreatorProfileImage: UIImageView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFill
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
