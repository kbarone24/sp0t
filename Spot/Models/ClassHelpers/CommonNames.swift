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
    case BlankImage = "BlankImage"

    var color: UIColor {
        return UIColor(named: rawValue) ?? .clear
    }
}

enum SpotFonts: String {
    case UniversCE = "UniversCE-Black"
    case SFCompactRoundedMedium = "SFCompactRounded-Medium"
    case SFCompactRoundedSemibold = "SFCompactRounded-Semibold"
    case SFCompactRoundedBold = "SFCompactRounded-Bold"
    case SFCompactRoundedRegular = "SFCompactRounded-Regular"
    case Gameplay = "Gameplay"

    func fontWith(size: CGFloat) -> UIFont {
        return UIFont(name: rawValue, size: size) ?? UIFont()
    }
}
