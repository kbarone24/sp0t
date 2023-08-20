//
//  NotificationsTableHeader.swift
//  Spot
//
//  Created by Kenny Barone on 8/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit


class NotificationsTableHeader: UITableViewHeaderFooterView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 14)
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(title: String) {
        titleLabel.text = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
