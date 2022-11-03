//
//  CreateMapButton.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CreateMapButton: UIButton {
    var chooseLabel: UILabel!

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.4
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 9

        chooseLabel = UILabel {
            $0.text = "Create Map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Bold", size: 16)
            addSubview($0)
        }
        chooseLabel.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

