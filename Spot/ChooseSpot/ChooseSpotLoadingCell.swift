//
//  ChooseSpotLoadingCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ChooseSpotLoadingCell: UITableViewCell {
    lazy var activityIndicator = CustomActivityIndicator()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(10)
            $0.width.height.equalTo(30)
        }
    }
}
