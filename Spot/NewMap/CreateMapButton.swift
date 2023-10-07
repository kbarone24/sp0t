//
//  CreateMapButton.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CreateMapButton: UIButton {
    private lazy var chooseLabel: UILabel = {
        let label = UILabel()
        label.text = "Create Map"
        label.textColor = .black
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 16)
        return label
    }()

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.4
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "SpotGreen")
        layer.cornerRadius = 9

        addSubview(chooseLabel)
        chooseLabel.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
