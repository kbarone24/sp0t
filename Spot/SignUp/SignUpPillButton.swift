//
//  SignUpPillButton.swift
//  Spot
//
//  Created by Kenny Barone on 3/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SignUpPillButton: UIButton {
    init(text: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 9
        layer.masksToBounds = true
        backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)

        setTitle(text, for: .normal)
        setTitleColor(.black, for: .normal)
        titleLabel?.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 16)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func toggle(enabled: Bool) {
        alpha = enabled ? 1.0 : 0.4
        isEnabled = enabled
    }
}
