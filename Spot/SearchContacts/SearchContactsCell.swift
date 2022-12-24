//
//  SearchContactsCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

final class SearchContactsCell: UITableViewCell {
    private lazy var avatarImage = UIImageView()

    private lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.layer.cornerRadius = 54 / 2
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        return image
    }()

    private lazy var username: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var selectedBubble: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .white

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.height.width.equalTo(54)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profileImage).offset(-11)
            $0.bottom.equalTo(profileImage).offset(3)
            $0.width.equalTo(30)
            $0.height.equalTo(33.87)
        }

        contentView.addSubview(username)
        username.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(11)
            $0.centerY.equalTo(profileImage)
        }

        contentView.addSubview(selectedBubble)
        selectedBubble.snp.makeConstraints {
            $0.trailing.equalTo(-21)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(user: UserProfile) {
        username.text = user.username
        setBubbleImage(selected: user.selected)

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: user.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
    }

    func setBubbleImage(selected: Bool) {
        selectedBubble.image = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
    }
}
