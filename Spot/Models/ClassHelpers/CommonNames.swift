//
//  CommonNames.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

enum SpotColors: String {
    case SpotGreen = "SpotGreen"
    case SpotBlack = "SpotBlack"

    var color: UIColor {
        return UIColor(named: rawValue) ?? .clear
    }
}

enum SpotFonts: String {
    case UniversCE = "UniversCE-Black"
    case SFCompactRoundedMedium = "SFCompactRounded-Medium"
    case SFCompactRoundedSemibold = "SFCompactRounded-Semibold"
    case SFCompactRoundedBold = "SFCompactRounded-Bold"
    case Gameplay = "Gameplay"
    case SFCompactRegular = "SFCompactText-Regular"
    case SFCompactMedium = "SFCompactText-Medium"
    case SFCompactSemibold = "SFCompactText-Semibold"
    case SFCompactHeavy = "SFCompactText-Heavy"
    case SFCompactBold = "SFCompactText-Bold"
    case SFCompactBlack = "SFCompactText-Black"

    func fontWith(size: CGFloat) -> UIFont {
        return UIFont(name: rawValue, size: size) ?? UIFont()
    }
}
