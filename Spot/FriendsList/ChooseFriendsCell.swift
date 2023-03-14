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

    private(set) lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        return view
    }()

    private(set) lazy var username: UILabel = {
        let username = UILabel()
        username.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        username.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return username
    }()

    private lazy var selectedBubble = UIImageView()
    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        return view
    }()

    private lazy var addFriendButton = AddFriendButton(frame: .zero, title: "Add")

    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")
        contentView.alpha = 1.0
        selectionStyle = .none

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(36)
            $0.height.equalTo(40.5)
        }

        contentView.addSubview(username)
        username.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.centerY.equalTo(avatarImage).offset(2)
            $0.trailing.equalToSuperview().inset(85)
        }

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

        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
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
        } else if showAddFriend {
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
        avatarImage.sd_cancelCurrentImageLoad()
    }
}
