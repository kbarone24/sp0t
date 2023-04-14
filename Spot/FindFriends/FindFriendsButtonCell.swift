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
    private lazy var gradientBackground = UIView()
    var buttonType: FindFriendsButtonType?

    override func layoutSubviews() {
        super.layoutSubviews()
        addGradient()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(pillBackground)
        pillBackground.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(91)
            $0.centerY.equalToSuperview()
        }

        pillBackground.addSubview(gradientBackground)
        gradientBackground.snp.makeConstraints {
            $0.edges.equalTo(pillBackground)
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
        self.buttonType = type
        switch type {
        case .InviteFriends:
            label.text = "Invite friends"
            sublabel.text = "Share download link"
            icon.image = UIImage(named: "InviteFriendsIcon")
            gradientBackground.backgroundColor = UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1)
        case .SearchContacts:
            label.text = "Search contacts"
            sublabel.text = "See who you know on sp0t"
            icon.image = UIImage(named: "SearchContactsIcon")
            gradientBackground.backgroundColor = UIColor(red: 1, green: 0.367, blue: 0.823, alpha: 1)
        }

        layoutSubviews()
    }

    private func addGradient() {
        for layer in gradientBackground.layer.sublayers ?? [] { layer.removeFromSuperlayer() }
        switch buttonType {
        case .InviteFriends:
            let layer = CAGradientLayer()
            layer.frame = gradientBackground.bounds
            layer.colors = [
                UIColor(red: 0.379, green: 0.926, blue: 1, alpha: 1).cgColor,
                UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1).cgColor,
                UIColor(red: 0.225, green: 0.767, blue: 1, alpha: 1).cgColor,
            ]
            layer.locations = [0, 0.53, 1]
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientBackground.layer.addSublayer(layer)
        case .SearchContacts:
            let layer = CAGradientLayer()
            layer.frame = gradientBackground.bounds
            layer.colors = [
                UIColor(red: 1, green: 0.492, blue: 0.858, alpha: 1).cgColor,
                UIColor(red: 1, green: 0.367, blue: 0.823, alpha: 1).cgColor,
                UIColor(red: 1, green: 0.367, blue: 0.823, alpha: 1).cgColor,
            ]
            layer.locations = [0, 0.41, 1]
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientBackground.layer.addSublayer(layer)
        case .none:
            return
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
