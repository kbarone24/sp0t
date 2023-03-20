//
//  PostLoadingCell.swift
//  Spot
//
//  Created by Kenny Barone on 3/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PostLoadingCell: UICollectionViewCell {
    lazy var activityIndicator = UIActivityIndicatorView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotBlack")

        contentView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
            $0.height.width.equalTo(30)
        }
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
