//
//  ChooseFriendsCell.swift
//  Spot
//
//  Created by Kenny Barone on 5/4/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage

class ChooseFriendsCell: UITableViewCell {
    private lazy var userID = ""
    private(set) lazy var profileImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 21
        view.clipsToBounds = true
        return view
    }()

    private lazy var avatarImage = UIImageView()

    private(set) lazy var username: UILabel = {
        let username = UILabel()
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return username
    }()

    private lazy var selectedBubble = UIImageView()
    private lazy var bottomLine = UIView()

    private lazy var addFriendButton = AddFriendButton(frame: .zero, title: "Add")

    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        contentView.alpha = 1.0
        selectionStyle = .none

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(42)
        }

        avatarImage.contentMode = .scaleAspectFill
        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profileImage).inset(-10)
            $0.bottom.equalTo(profileImage).inset(-2)
            $0.height.equalTo(25)
            $0.width.equalTo(17.33)
        }

        contentView.addSubview(username)
        username.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(8)
            $0.top.equalTo(21)
            $0.trailing.equalToSuperview().inset(85)
        }

        bottomLine.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(user: UserProfile, allowsSelection: Bool, editable: Bool, showAddFriend: Bool) {
        resetCell()
        userID = user.id ?? ""

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: user.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])

        username.text = user.username
        if allowsSelection {
            selectedBubble.image = user.selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
            contentView.addSubview(selectedBubble)
            selectedBubble.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(25)
                $0.width.height.equalTo(24)
                $0.centerY.equalToSuperview()
            }
        } else if showAddFriend ?? true {
            contentView.addSubview(addFriendButton)
            if UserDataModel.shared.userInfo.friendsContains(id: user.id ?? "") {
                setAddFriendFriends()
            } else if UserDataModel.shared.userInfo.pendingFriendRequests.contains(user.id ?? "") {
                setAddFriendPending()
            } else {
                setAddFriendAdd()
            }
            addFriendButton.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(10)
                $0.centerY.equalToSuperview()
                $0.height.equalTo(39)
                $0.width.equalTo(88)
            }
        }

        contentView.alpha = editable ? 1.0 : 0.5
        if !editable {
            contentView.alpha = 0.5
        }
    }

    private func resetCell() {
        profileImage.image = UIImage()
        avatarImage.image = UIImage()
        selectedBubble.removeFromSuperview()
        addFriendButton.removeFromSuperview()
    }

    private func setAddFriendAdd() {
        addFriendButton.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
        addFriendButton.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
        addFriendButton.setAttTitle(title: "Add", color: .black)
        addFriendButton.addTarget(self, action: #selector(addFriendTap), for: .touchUpInside)
    }

    private func setAddFriendPending() {
        addFriendButton.setImage(UIImage(), for: .normal)
        addFriendButton.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
        addFriendButton.setAttTitle(title: "Pending", color: .black)
        addFriendButton.removeTarget(self, action: #selector(addFriendTap), for: .touchUpInside)
    }

    private func setAddFriendFriends() {
        addFriendButton.setImage(UIImage(), for: .normal)
        addFriendButton.backgroundColor = nil
        addFriendButton.setAttTitle(title: "Friends", color: UIColor(red: 0.683, green: 0.683, blue: 0.683, alpha: 1))
        addFriendButton.layer.borderWidth = 0
        addFriendButton.removeTarget(self, action: #selector(addFriendTap), for: .touchUpInside)
    }

    @objc func addFriendTap() {
        friendService?.addFriend(receiverID: userID, completion: nil)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImage.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}
