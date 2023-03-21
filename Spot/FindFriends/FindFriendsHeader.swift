//
//  SuggestedFriendsHeader.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

class FindFriendsHeader: UITableViewHeaderFooterView {
    private lazy var label: UILabel = {
        //TODO: replace with actual font
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "UniversCE-Black", size: 14.5)
        return label
    }()

    private lazy var subLabel: UILabel = {
        let label = UILabel()
        label.textColor =  UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        return label
    }()

    var type: Int = 0 {
        didSet {
            if type == 0 {
                label.text = "Contacts"
                subLabel.text = "Send a request to see who they are on sp0t 👀"
            } else {
                label.text = "Suggested friends"
                subLabel.text = ""
            }
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        contentView.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(24)
            $0.bottom.equalToSuperview().offset(-18)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(subLabel.snp.leading)
            $0.bottom.equalTo(subLabel.snp.top).offset(-2.5)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
