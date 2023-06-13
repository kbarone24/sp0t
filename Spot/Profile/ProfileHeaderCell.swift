//
//  ProfileHeaderCell.swift
//  Spot
//
//  Created by Arnold on 6/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Mixpanel
import SnapKit
import UIKit
import SDWebImage

enum ProfileRelation {
    case myself
    case friend
    case pending
    case stranger
    case received
    case blocked
}

class ProfileHeaderCell: UICollectionViewCell {
    private var profile: UserProfile?
    private var relation: ProfileRelation = .stranger

    private lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = true 
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 22)
        label.text = ""
        return label
    }()

    private lazy var bioLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1.00)
        label.font = UIFont(name: "SFCompactText-Medium", size: 14)
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    public lazy var friendListButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "FriendsIcon"), for: .normal)
        button.setTitle("", for: .normal)
        button.setTitleColor(UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1), for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        return button
    }()

    public lazy var actionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Edit profile", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 12
        return button
    }()

    private lazy var inviteFriendsButton: PillButtonWithImage = {
        let button = PillButtonWithImage()
        button.setUp(image: UIImage(named: "BlackShareButton"), title: "Invite Friends", titleColor: .black)
        button.backgroundColor = UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1)
        button.isHidden = true
        button.addTarget(self, action: #selector(inviteFriendsTap), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        inviteFriendsButton.addGradient()
    }

    public func cellSetup(userProfile: UserProfile, relation: ProfileRelation) {
        self.profile = userProfile

        let image = userProfile.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else {
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: userProfile.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        }
        usernameLabel.text = userProfile.username
        bioLabel.text = userProfile.userBio
        
        friendListButton.setTitle("\(userProfile.friendIDs.count) friends", for: .normal)
        friendListButton.isHidden = relation != .myself && relation != .friend

        self.relation = relation
        switch relation {
        case .myself:
            actionButton.setTitle("Edit profile", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(.white, for: .normal)

            inviteFriendsButton.isHidden = false
            actionButton.snp.updateConstraints {
                $0.trailing.equalTo(-232)
            }
        case .friend:
            actionButton.setImage(UIImage(named: "FriendsIcon")?.withRenderingMode(.alwaysTemplate), for: .normal)
            actionButton.imageView?.tintColor = .white
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Friends", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(.white, for: .normal)
        case .pending:
            actionButton.setImage(UIImage(named: "FriendsPendingIcon")?.withRenderingMode(.alwaysTemplate), for: .normal)
            actionButton.imageView?.tintColor = .white
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(.white, for: .normal)
        case .stranger, .received:
            actionButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.imageView?.tintColor = nil
            actionButton.setTitle(relation == .stranger ? "Add friend" : "Accept friend request", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            actionButton.setTitleColor(.black, for: .normal)
        case .blocked:
            actionButton.setTitle("Blocked", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
            actionButton.setTitleColor(.black, for: .normal)
        }

        updateConstraintsForEmptyStates()
        layoutSubviews()
    }

    @objc func inviteFriendsTap() {
        Mixpanel.mainInstance().track(event: "FindFriendsInviteFriendsTap")
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "Add me on sp0t 🌎🦦"] as [Any]

        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let vc = self.viewContainingController() as? ProfileViewController {
            vc.present(activityView, animated: true)
            activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    Mixpanel.mainInstance().track(event: "ProfileInviteSent", properties: ["type": activityType?.rawValue ?? ""])
                } else {
                    Mixpanel.mainInstance().track(event: "ProfileInviteCancelled")
                }
            }
        }
    }

    @objc func avatarTap() {
        guard relation == .myself else { return }
        Mixpanel.mainInstance().track(event: "ProfileAvatarTap")
        if let vc = self.viewContainingController() as? ProfileViewController {
            let family = AvatarFamily(rawValue: UserDataModel.shared.userInfo.avatarFamily ?? "")
            vc.openEditAvatar(family: family)
        }
    }
}

extension ProfileHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = UIColor(named: "SpotBlack")
        clipsToBounds = false

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-6)
            $0.leading.equalTo(12)
            $0.height.equalTo(56.25)
            $0.width.equalTo(50)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(15)
            $0.trailing.lessThanOrEqualToSuperview().offset(-18)
            $0.bottom.equalTo(avatarImage.snp.centerY).offset(2)
        }

        // friends list button always shows in its entirety
        contentView.addSubview(friendListButton)
        friendListButton.snp.makeConstraints {
            $0.top.equalTo(usernameLabel.snp.bottom).offset(-6)
            $0.leading.equalTo(avatarImage.snp.trailing).offset(15)
            $0.trailing.lessThanOrEqualToSuperview().inset(20)
            $0.height.equalTo(38)
        }

        contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.height.equalTo(37)
            $0.bottom.equalToSuperview().offset(-10)
        }

        contentView.addSubview(inviteFriendsButton)
        inviteFriendsButton.snp.makeConstraints {
            $0.leading.equalTo(actionButton.snp.trailing).offset(8)
            $0.trailing.equalTo(-10)
            $0.height.bottom.equalTo(actionButton)
        }

        contentView.addSubview(bioLabel)
        bioLabel.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.lessThanOrEqualTo(-16)
            $0.top.equalTo(avatarImage.snp.bottom).offset(8)
            $0.bottom.lessThanOrEqualTo(actionButton.snp.top).offset(-8)
        }
    }

    private func updateConstraintsForEmptyStates() {
        avatarImage.snp.updateConstraints {
            if profile?.userBio.isEmpty ?? true {
                $0.top.equalTo(10)
            } else {
                $0.top.equalTo(0)
            }
        }

        usernameLabel.snp.updateConstraints {
            if friendListButton.isHidden {
                $0.bottom.equalTo(avatarImage.snp.centerY).offset(14)
            } else {
                $0.bottom.equalTo(avatarImage.snp.centerY).offset(2)
            }
        }
    }
}
