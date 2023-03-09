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
    private lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.layer.cornerRadius = 54 / 2
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        return image
    }()

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(named: "SpotWhite")
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    private lazy var numberLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Medium", size: 13.5)
        return label
    }()

    private lazy var selectedBubble: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.height.width.equalTo(54)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(11)
            $0.bottom.equalTo(contentView.snp.centerY).offset(-1)
        }

        contentView.addSubview(numberLabel)
        numberLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(contentView.snp.centerY).offset(1)
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
        var user = user
        nameLabel.text = user.contactInfo?.fullName ?? ""
        numberLabel.text = user.contactInfo?.realNumber ?? ""
        setBubbleImage(selected: user.selected)

        if let data = user.contactInfo?.thumbnailData {
            profileImage.image = UIImage(data: data)
        } else {
            profileImage.image = UIImage(named: "BlankContact")?.withRenderingMode(.alwaysTemplate)
            profileImage.tintColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        }
    }

    func setBubbleImage(selected: Bool) {
        selectedBubble.image = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
    }
}
