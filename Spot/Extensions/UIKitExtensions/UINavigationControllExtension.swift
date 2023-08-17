//
//  UINavigationControllExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UINavigationController {
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }

    func setUpOpaqueNav(backgroundColor: UIColor) {
        setNavigationBarHidden(false, animated: true)

        navigationBar.isTranslucent = true
        navigationBar.tintColor = .white
        navigationBar.shadowImage = UIImage()

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowImage = UIImage()
        appearance.backgroundImage = UIImage()

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: SpotFonts.UniversCE.fontWith(size: 20)
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }

    func setUpTranslucentNav() {
        setNavigationBarHidden(false, animated: true) 

        navigationBar.isTranslucent = true
        navigationBar.tintColor = .black

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowImage = UIImage()
        appearance.backgroundImage = UIImage()

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: SpotFonts.UniversCE.fontWith(size: 20)
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }
}
