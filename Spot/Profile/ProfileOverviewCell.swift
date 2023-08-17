//
//  ProfileOverviewCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import SDWebImage
import Mixpanel

protocol ProfileOverviewDelegate: AnyObject {
    func addFriend()
    func showPendingActionSheet()
    func showRemoveActionSheet()
    func showUnblockActionSheet()
    func openEditProfile()
    func inviteFriends()
    func acceptFriendRequest()
    func avatarTap()
}

class ProfileOverviewCell: UITableViewCell {
    var userInfo: UserProfile?
    weak var delegate: ProfileOverviewDelegate?

    private lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = true
        return image
    }()

    private lazy var spotscoreBackground: UIImageView = {
        let image = UIImageView(image: UIImage(named: "SpotscoreBackground"))
        image.isUserInteractionEnabled = true
        return image
    }()

    private lazy var spotscoreLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.Gameplay.fontWith(size: 8.5)
        return label
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        label.font = SpotFonts.UniversCE.fontWith(size: 24)
        return label
    }()

    private lazy var friendsCount: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17.5)
        return label
    }()

    private lazy var friendsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17.5)
        return label
    }()

    private lazy var spotsCount: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17.5)
        return label
    }()

    private lazy var spotsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 17.5)
        return label
    }()

    private lazy var bioLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedRegular.fontWith(size: 20.5)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var editProfileButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .gray, text: "edit profile")
        button.isHidden = true
        button.addTarget(self, action: #selector(editProfileTap), for: .touchUpInside)
        return button
    }()

    private lazy var inviteFriendsButton: UIButton = {
        let button = ProfileActionButton(type: .green, text: "invite friends")
        button.isHidden = true
        button.addTarget(self, action: #selector(inviteFriendsTap), for: .touchUpInside)
        return button
    }()

    private lazy var addFriendButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .green, text: "add friend")
        button.isHidden = true
        button.addTarget(self, action: #selector(addFriendTap), for: .touchUpInside)
        return button
    }()

    private lazy var pendingButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .gray, text: "pending")
        button.isHidden = true
        button.addTarget(self, action: #selector(pendingTap), for: .touchUpInside)
        return button
    }()

    private lazy var friendsButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .gray, text: "friends")
        button.isHidden = true
        button.addTarget(self, action: #selector(friendsTap), for: .touchUpInside)
        return button
    }()

    private lazy var blockedButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .gray, text: "blocked")
        button.isHidden = true
        button.alpha = 0.4
        button.addTarget(self, action: #selector(blockedTap), for: .touchUpInside)
        return button
    }()

    private lazy var acceptFriendRequestButton: ProfileActionButton = {
        let button = ProfileActionButton(type: .green, text: "accept friend request")
        button.isHidden = true
        button.addTarget(self, action: #selector(acceptFriendRequest), for: .touchUpInside)
        return button
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1)
        setUpView()
    }

    private func setUpView() {
        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalTo(14)
            $0.height.equalTo(67.5)
            $0.width.equalTo(60)
        }

        avatarImage.addSubview(spotscoreBackground)
        spotscoreBackground.clipsToBounds = false
        spotscoreBackground.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(10)
        }

        spotscoreBackground.addSubview(spotscoreLabel)
        spotscoreLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(0.5)
            $0.bottom.equalToSuperview().offset(-4.5)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(10)
            $0.top.equalTo(avatarImage.snp.top).offset(20)
        }

        contentView.addSubview(friendsCount)
        friendsCount.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(8)
        }

        contentView.addSubview(friendsLabel)
        friendsLabel.snp.makeConstraints {
            $0.leading.equalTo(friendsCount.snp.trailing).offset(4)
            $0.top.equalTo(friendsCount)
        }

        contentView.addSubview(spotsCount)
        spotsCount.snp.makeConstraints {
            $0.leading.equalTo(friendsLabel.snp.trailing).offset(12)
            $0.top.equalTo(friendsLabel)
        }

        contentView.addSubview(spotsLabel)
        spotsLabel.snp.makeConstraints {
            $0.leading.equalTo(spotsCount.snp.trailing).offset(4)
            $0.top.equalTo(spotsCount)
        }

        //MARK: layout from bottom
        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }

        contentView.addSubview(editProfileButton)
        editProfileButton.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.width.equalTo(UIScreen.main.bounds.width * 0.45)
            $0.height.equalTo(42)
            $0.bottom.equalTo(bottomLine.snp.top).offset(-20)
        }

        contentView.addSubview(inviteFriendsButton)
        inviteFriendsButton.snp.makeConstraints {
            $0.leading.equalTo(editProfileButton.snp.trailing).offset(10)
            $0.trailing.equalTo(-14)
            $0.height.bottom.equalTo(editProfileButton)
        }

        contentView.addSubview(addFriendButton)
        addFriendButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(14)
            $0.height.bottom.equalTo(inviteFriendsButton)
        }

        contentView.addSubview(pendingButton)
        pendingButton.snp.makeConstraints {
            $0.edges.equalTo(addFriendButton)
        }

        contentView.addSubview(friendsButton)
        friendsButton.snp.makeConstraints {
            $0.edges.equalTo(pendingButton)
        }

        contentView.addSubview(blockedButton)
        blockedButton.snp.makeConstraints {
            $0.edges.equalTo(friendsButton)
        }

        contentView.addSubview(acceptFriendRequestButton)
        acceptFriendRequestButton.snp.makeConstraints {
            $0.edges.equalTo(blockedButton)
        }

        contentView.addSubview(bioLabel)
        bioLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.top.equalTo(friendsCount.snp.bottom).offset(24)
            $0.bottom.equalTo(friendsButton.snp.top).offset(-20)
        }
    }

    func configure(userInfo: UserProfile) {
        self.userInfo = userInfo

        let image = userInfo.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else {
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 89.5), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: userInfo.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        }

        if userInfo.friendStatus == .activeUser {
            avatarImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
            spotscoreBackground.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTap)))
        }
        
        spotscoreBackground.image = userInfo.newAvatarNoti ?? false && userInfo.friendStatus == .activeUser ? UIImage(named: "SpotscoreNoti") : UIImage(named: "SpotscoreBackground")
        spotscoreLabel.text = String(max(userInfo.spotScore ?? 0, 0))

        usernameLabel.text = userInfo.username

        let friends = userInfo.friendIDs.count
        friendsCount.attributedText = NSAttributedString.getKernString(string: String(friends), kern: 0.26)
        let friendString = friends == 1 ? "friend" : "friends"
        friendsLabel.attributedText = NSAttributedString.getKernString(string: String(friendString), kern: 0.26)

        let spots = userInfo.postCount ?? 0
        spotsCount.attributedText = NSAttributedString.getKernString(string: String(spots), kern: 0.26)
        let spotString = spots == 1 ? "spot" : "spots"
        spotsLabel.attributedText = NSAttributedString.getKernString(string: String(spotString), kern: 0.26)

        bioLabel.text = userInfo.userBio

        editProfileButton.isHidden = true
        inviteFriendsButton.isHidden = true
        addFriendButton.isHidden = true
        pendingButton.isHidden = true
        friendsButton.isHidden = true
        blockedButton.isHidden = true
        acceptFriendRequestButton.isHidden = true

        switch userInfo.friendStatus {
        case .activeUser?:
            editProfileButton.isHidden = false
            inviteFriendsButton.isHidden = false
        case .none?:
            addFriendButton.isHidden = false
        case .pending?:
            pendingButton.isHidden = false
        case .friends?:
            friendsButton.isHidden = false
        case .blocked?:
            blockedButton.isHidden = false
        case .acceptable?:
            acceptFriendRequestButton.isHidden = false
        default:
            return
        }
    }

    @objc func editProfileTap() {
        Mixpanel.mainInstance().track(event: "ProfileEditProfileTap")
        delegate?.openEditProfile()
    }

    @objc func inviteFriendsTap() {
        Mixpanel.mainInstance().track(event: "ProfileInviteFriendsTap")
        delegate?.inviteFriends()
    }

    @objc func addFriendTap() {
        Mixpanel.mainInstance().track(event: "ProfileAddFriendTap")
        delegate?.addFriend()
    }

    @objc func pendingTap() {
        Mixpanel.mainInstance().track(event: "ProfilePendingTap")
        delegate?.showPendingActionSheet()
    }

    @objc func friendsTap() {
        Mixpanel.mainInstance().track(event: "ProfileFriendsTap")
        delegate?.showRemoveActionSheet()
    }

    @objc func blockedTap() {
        Mixpanel.mainInstance().track(event: "ProfileBlockedTap")
        delegate?.showUnblockActionSheet()
    }

    @objc func acceptFriendRequest() {
        Mixpanel.mainInstance().track(event: "ProfileAcceptFriendRequestTap")
        delegate?.acceptFriendRequest()
    }

    @objc func avatarTap() {
        Mixpanel.mainInstance().track(event: "ProfileAvatarTap")
        delegate?.avatarTap()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
