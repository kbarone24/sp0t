//
//  ProfileActionButton.swift
//  Spot
//
//  Created by Kenny Barone on 8/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ProfileActionButton: UIButton {
    enum ProfileButtonType {
        case green
        case gray
    }

    init(type: ProfileButtonType, text: String) {
        super.init(frame: .zero)

        switch type {
        case .green:
            backgroundColor = SpotColors.SpotGreen.color
            setTitleColor(.black, for: .normal)
        case .gray:
            backgroundColor = UIColor(red: 0.262, green: 0.262, blue: 0.262, alpha: 1)
            setTitleColor(.white, for: .normal)
        }

        setTitle(text, for: .normal)
        titleLabel?.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 16)
        layer.masksToBounds = true
        layer.cornerRadius = 9
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
