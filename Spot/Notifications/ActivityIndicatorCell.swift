//
//  ActivityIndicatorCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ActivityIndicatorCell: UITableViewCell {
    private lazy var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(15)
            $0.height.width.equalTo(40)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
    }

    func animate() {
        activityIndicator.startAnimating()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
