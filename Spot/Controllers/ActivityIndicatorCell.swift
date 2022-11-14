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
    lazy var activityIndicator: CustomActivityIndicator = CustomActivityIndicator(frame: CGRect.zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp() {
        activityIndicator.removeFromSuperview()
        activityIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30) / 2), y: 35, width: 30, height: 30)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = true
        contentView.addSubview(activityIndicator)
    }
}
