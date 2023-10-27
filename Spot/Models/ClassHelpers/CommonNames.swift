//
//  CommonNames.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

enum SpotColors: String {
    case SpotGreen = "SpotGreen"
    case SpotBlack = "SpotBlack"
    case SpotPink = "SpotPink"
    case HeaderGray = "HeaderGray"
    case BlankImage = "BlankImage"
    case SublabelGray = "SublabelGray"

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
    case SFCompactRoundedHeavy = "SFCompactRounded-Heavy"
    case Gameplay = "Gameplay"

    func fontWith(size: CGFloat) -> UIFont {
        return UIFont(name: rawValue, size: size) ?? UIFont()
    }
}
