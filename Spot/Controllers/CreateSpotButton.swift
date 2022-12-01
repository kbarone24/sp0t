//
//  CreateSpotButton.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CreateSpotButton: UIButton {
    private lazy var createLabel: UILabel = {
        let label = UILabel()
        label.text = "Create spot"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
        return label
    }()
    private lazy var spotIcon = UIImageView(image: UIImage(named: "NewSpotIcon"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 18
        backgroundColor = UIColor(named: "SpotGreen")

        addSubview(createLabel)
        createLabel.snp.makeConstraints {
            $0.leading.equalTo(22)
            $0.centerY.equalToSuperview()
        }

        addSubview(spotIcon)
        spotIcon.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(25.5)
            $0.width.equalTo(35)
            $0.centerY.equalToSuperview().offset(-1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
