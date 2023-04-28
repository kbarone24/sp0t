//
//  TagFreindsLoadingCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/27/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class TagFriendsLoadingCell: UICollectionViewCell {
    lazy var activityIndicator = UIActivityIndicatorView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(activityIndicator)
        activityIndicator.color = .lightGray
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.snp.makeConstraints {
            $0.width.height.equalTo(30)
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
