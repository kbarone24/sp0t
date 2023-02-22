//
//  InviteFriendsOutlet.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class InviteFriendsCell: UITableViewCell {
    private lazy var pillBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        view.layer.cornerRadius = 16
        return view
    }()

    private lazy var globeFriends = UIImageView(image: UIImage(named: "FriendsMapIcon"))
    private lazy var label: UILabel = {
        let l = UILabel()
        l.text = "Invite friends to sp0t"
        l.textColor = .black
        l.font = UIFont(name: "SFCompactText-Bold", size: 18.5)
        return l
    }()

    private lazy var sublabel: UILabel = {
        let l = UILabel()
        l.text = "sp0t.app/\(UserDataModel.shared.userInfo.username)"
        l.textColor = UIColor(red: 0.675, green: 0.675, blue: 0.675, alpha: 1)
        l.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        return l
    }()

    private lazy var exportIcon = UIImageView(image: UIImage(named: "ExportIcon"))
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")
        
        addSubview(pillBackground)
        pillBackground.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.centerY.equalToSuperview().offset(-5)
            $0.height.equalTo(88)
        }

        pillBackground.addSubview(globeFriends)
        globeFriends.snp.makeConstraints {
            $0.leading.equalTo(10)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(60)
            $0.width.equalTo(58)
        }

        pillBackground.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(globeFriends.snp.trailing).offset(5)
            $0.top.equalTo(25)
        }

        pillBackground.addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.leading.equalTo(label)
            $0.top.equalTo(label.snp.bottom).offset(2)
        }

        pillBackground.addSubview(exportIcon)
        exportIcon.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(21.5)
            $0.centerY.equalToSuperview().offset(-1)
            $0.height.equalTo(27.9)
            $0.width.equalTo(22.18)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
