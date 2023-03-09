//
//  ContactsEmptyStateCell.swift
//  Spot
//
//  Created by Kenny Barone on 3/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ContactsEmptyStateCell: UITableViewCell {
    var label: UILabel = {
        let label = UILabel()
        label.text = "x_x  No contacts yet"
        label.textColor = UIColor(red: 0.371, green: 0.371, blue: 0.371, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(24)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
