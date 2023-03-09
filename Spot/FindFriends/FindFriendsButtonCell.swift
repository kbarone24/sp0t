//
//  FindFriendsButtonCell.swift
//  Spot
//
//  Created by Kenny Barone on 3/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

enum FindFriendsButtonType {
    case InviteFriends
    case SearchContacts
}

class FindFriendsButtonCell: UITableViewCell {
    private lazy var pillBackground: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 15
        view.layer.masksToBounds = true
        return view
    }()
    private lazy var icon = UIImageView()
    private lazy var label: UILabel = {
        let l = UILabel()
        l.textColor = .black
        l.font = UIFont(name: "SFCompactText-Heavy", size: 21)
        return l
    }()

    private lazy var sublabel: UILabel = {
        let l = UILabel()
        l.textColor = .black
        l.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(pillBackground)
        pillBackground.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(91)
            $0.centerY.equalToSuperview()
        }

        pillBackground.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(22)
            $0.bottom.equalTo(pillBackground.snp.centerY).offset(2)
        }

        pillBackground.addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.leading.equalTo(label)
            $0.top.equalTo(label.snp.bottom).offset(3)
        }

        pillBackground.addSubview(icon)
        icon.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(24)
            $0.centerY.equalToSuperview().offset(2.5)
        }
    }

    func setUp(type: FindFriendsButtonType) {
        switch type {
        case .InviteFriends:
            pillBackground.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
            label.text = "Invite friends"
            sublabel.text = "Share download link"
            icon.image = UIImage(named: "InviteFriendsIcon")
        case .SearchContacts:
            pillBackground.backgroundColor = UIColor(red: 1, green: 0.446, blue: 0.845, alpha: 1)
            label.text = "Search contacts"
            sublabel.text = "See who you know on sp0t"
            icon.image = UIImage(named: "SearchContactsIcon")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
