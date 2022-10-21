//
//  ProfileBodyCell.swift
//  Spot
//
//  Created by Arnold Lee on 2022/6/27.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import UIKit

class ProfileBodyCell: UICollectionViewCell {
    private var mapImage: UIImageView!
    private var mapName: UILabel!
    private var friendsCount: UILabel!
    private var friendsIcon: UIImageView!
    private var likesCount: UILabel!
    private var postsCount: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        if mapImage != nil { mapImage.sd_cancelCurrentImageLoad() }
    }

    public func cellSetup(mapData: CustomMap) {
        mapImage.sd_setImage(with: URL(string: mapData.imageURL))
        if mapData.secret {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image!.size.width, height: imageAttachment.image!.size.height)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " \(mapData.mapName)"))
            self.mapName.attributedText = completeText
        } else {
            self.mapName.text = mapData.mapName
        }
        self.friendsCount.text = mapData.memberIDs.count == 1 ? "" : "\(mapData.memberIDs.count)"
        self.friendsIcon.snp.updateConstraints {
            $0.width.equalTo(mapData.memberIDs.count == 1 ? 0 : 13.33)
        }
        self.friendsIcon.isHidden = mapData.memberIDs.count == 1
        self.likesCount.text = mapData.likers.count != 0 ? (mapData.memberIDs.count == 1 ? "\(mapData.likers.count) likes" : " • \(mapData.likers.count) likes") : ""
        self.postsCount.text = mapData.postLocations.count != 0 ? ((mapData.memberIDs.count == 1 && mapData.likers.count == 0) ? "\(mapData.postLocations.count) posts" : " • \(mapData.postLocations.count) posts") : ""
    }
}

extension ProfileBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        mapImage = UIImageView {
            $0.image = R.image.signuplogo()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 14
            contentView.addSubview($0)
        }
        mapImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182 / 195)
        }

        mapName = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.text = ""
            contentView.addSubview($0)
        }
        mapName.snp.makeConstraints {
            $0.leading.trailing.equalTo(mapImage)
            $0.top.equalTo(mapImage.snp.bottom).offset(6)
        }

        friendsCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        friendsCount.snp.makeConstraints {
            $0.leading.equalTo(mapImage)
            $0.top.equalTo(mapName.snp.bottom).offset(1)
            $0.trailing.lessThanOrEqualToSuperview()
        }

        friendsIcon = UIImageView {
            $0.image = UIImage(named: "Friends")?.withRenderingMode(.alwaysTemplate)
            $0.tintColor = UIColor(red: 0.658, green: 0.658, blue: 0.658, alpha: 1)
            $0.contentMode = .scaleAspectFit
            $0.layer.masksToBounds = true
            contentView.addSubview($0)
        }
        friendsIcon.snp.makeConstraints {
            $0.leading.equalTo(friendsCount.snp.trailing).offset(3)
            $0.top.equalTo(friendsCount).offset(3)
            $0.width.equalTo(13.33)
            $0.height.equalTo(10)
        }

        likesCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        likesCount.snp.makeConstraints {
            $0.leading.equalTo(friendsIcon.snp.trailing)
            $0.top.equalTo(friendsCount)
            $0.trailing.lessThanOrEqualToSuperview()
        }

        postsCount = UILabel {
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
            $0.text = ""
            contentView.addSubview($0)
        }
        postsCount.snp.makeConstraints {
            $0.leading.equalTo(likesCount.snp.trailing)
            $0.top.equalTo(friendsCount)
            $0.trailing.lessThanOrEqualToSuperview()
        }
    }
}
