//
//  NextButton.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class NextButton: UIButton {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Next"
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
        backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
        layer.cornerRadius = 9

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
