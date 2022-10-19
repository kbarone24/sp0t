//
//  UINavigationItemExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UINavigationItem {
    func addBlackBackground() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundImage = UIImage()
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
    
    func removeBackgroundImage() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = UIImage()
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        }
    }
}
