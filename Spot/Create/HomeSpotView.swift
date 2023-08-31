//
//  HomeSpotView.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeSpotView: UIView {
    private lazy var locationPin = UIImageView(image: UIImage(named: "HomeSpotLocationPin"))
    private(set) lazy var spotLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.542, green: 0.542, blue: 0.542, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 16)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(locationPin)
        locationPin.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        addSubview(spotLabel)
        spotLabel.snp.makeConstraints {
            $0.leading.equalTo(locationPin.snp.trailing).offset(8)
            $0.centerY.trailing.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
