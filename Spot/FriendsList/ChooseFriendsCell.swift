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
    private lazy var profileImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.layer.cornerRadius = 21
        view.clipsToBounds = true
        return view
    }()

    private lazy var avatarImage = UIImageView()

    private lazy var username: UILabel = {
        let username = UILabel()
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return username
    }()

    private lazy var selectedBubble = UIImageView()
    private lazy var bottomLine = UIView()

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
            $0.trailing.equalToSuperview().inset(60)
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

    func setUp(user: UserProfile, allowsSelection: Bool, editable: Bool) {
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
        }

        contentView.alpha = editable ? 1.0 : 0.5
        if !editable {
            contentView.alpha = 0.5
        }
    }

    func resetCell() {
        profileImage.image = UIImage()
        avatarImage.image = UIImage()
        selectedBubble.removeFromSuperview()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profileImage.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}
