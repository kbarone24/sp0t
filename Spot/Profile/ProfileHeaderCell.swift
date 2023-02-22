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

    private lazy var profileImage: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var profileAvatar: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.text = ""
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var locationButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "ProfileLocation"), for: .normal)
        button.setTitle("", for: .normal)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        button.addTarget(self, action: #selector(locationButtonAction), for: .touchUpInside)
        button.snp.contentCompressionResistanceHorizontalPriority = 700
        return button
    }()

    public lazy var friendListButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "FriendsIcon"), for: .normal)
        button.setTitle("", for: .normal)
        button.setTitleColor(UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1), for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13)
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        return button
    }()

    public lazy var actionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Edit profile", for: .normal)
        button.setTitleColor(UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        button.layer.cornerRadius = 37 / 2
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func cellSetup(userProfile: UserProfile, relation: ProfileRelation) {
        self.profile = userProfile

        let transformer = SDImageResizingTransformer(size: CGSize(width: 150, height: 150), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: userProfile.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        profileAvatar.sd_setImage(with: URL(string: userProfile.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        usernameLabel.text = userProfile.username
        locationButton.setTitle(userProfile.currentLocation, for: .normal)
        if userProfile.currentLocation == "" {
            locationButton.setImage(UIImage(), for: .normal)
            friendListButton.snp.updateConstraints {
                $0.leading.equalTo(locationButton.snp.trailing)
            }
        }
        friendListButton.setTitle("\(userProfile.friendIDs.count) friends", for: .normal)

        self.relation = relation
        switch relation {
        case .myself:
            actionButton.setTitle("Edit profile", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), for: .normal)
        case .friend:
            actionButton.setImage(UIImage(named: "FriendsIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Friends", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), for: .normal)
        case .pending:
            actionButton.setImage(UIImage(named: "FriendsPendingIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle("Pending", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.196, green: 0.196, blue: 0.196, alpha: 1)
            actionButton.setTitleColor(UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), for: .normal)
        case .stranger, .received:
            actionButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            actionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -5, bottom: 0, right: 5)
            actionButton.setTitle(relation == .stranger ? "Add friend" : "Accept friend request", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            actionButton.setTitleColor(.black, for: .normal)
        case .blocked:
            actionButton.setTitle("Blocked", for: .normal)
            actionButton.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
            actionButton.setTitleColor(.black, for: .normal)
        }
    }
}

extension ProfileHeaderCell {
    private func viewSetup() {
        contentView.backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(28)
            $0.width.height.equalTo(84)
        }
        profileImage.layer.cornerRadius = 84 / 2

        contentView.addSubview(profileAvatar)
        profileAvatar.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-14)
            $0.bottom.equalTo(profileImage).inset(-8.24)
            $0.height.equalTo(47.25)
            $0.width.equalTo(36)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
            $0.bottom.equalTo(profileImage.snp.centerY).offset(-2)
         //   $0.height.lessThanOrEqualTo(22)
            $0.width.equalTo(113)
        }

        // location button will truncate if overflow
        contentView.addSubview(locationButton)
        locationButton.snp.makeConstraints {
            $0.top.equalTo(usernameLabel.snp.bottom).offset(-4)
            $0.height.equalTo(38)
            $0.leading.equalTo(profileImage.snp.trailing).offset(15)
        }

        // friends list button always shows in its entirety
        contentView.addSubview(friendListButton)
        friendListButton.snp.makeConstraints {
            $0.top.equalTo(locationButton)
            $0.leading.equalTo(locationButton.snp.trailing).offset(15)
            $0.trailing.lessThanOrEqualToSuperview().inset(20)
            $0.height.equalTo(38)
        }

        contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.equalTo(37)
            $0.top.equalTo(profileImage.snp.bottom).offset(16)
        }
    }

    @objc func locationButtonAction() {
        Mixpanel.mainInstance().track(event: "ProfileHeaderLocationTap")
    }
}
