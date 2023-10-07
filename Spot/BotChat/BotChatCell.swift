//
//  BotChatCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI

class BotChatCell: UITableViewCell {
    private lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = true
        return image
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.308, green: 0.308, blue: 0.308, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        label.isUserInteractionEnabled = true
        return label
    }()

    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        return label
    }()

    private lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SpotBlack.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 18.5)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.979, green: 0.979, blue: 0.979, alpha: 1)

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(11)
            $0.top.equalTo(5)
            $0.width.equalTo(33)
            $0.height.equalTo(37.12)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.top.equalTo(6)
        }

        contentView.addSubview(timestampLabel)
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel.snp.trailing).offset(4)
            $0.bottom.equalTo(usernameLabel)
        }

        contentView.addSubview(captionLabel)
        captionLabel.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(2)
            $0.trailing.equalToSuperview().inset(19)
            $0.bottom.equalToSuperview().offset(-11).priority(.high)
        }
    }

    func configure(chat: BotChatMessage) {
        if let image = chat.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: chat.userInfo?.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        usernameLabel.text = chat.userInfo?.username ?? ""

        timestampLabel.text = chat.timestamp.toString(allowDate: false)

        captionLabel.text = chat.text
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
