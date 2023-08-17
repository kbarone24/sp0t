//
//  UINavigationBarExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

extension UINavigationBar {

    func addShadow() {
        /// gray line at bottom of nav bar
        guard layer.sublayers?.first(where: { $0.name == "bottomLine" }) == nil else {
            return
        }

        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0.0, y: bounds.height - 1, width: bounds.width, height: 1.0)
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1).cgColor
        bottomLine.shouldRasterize = true
        bottomLine.name = "bottomLine"
        layer.addSublayer(bottomLine)

        /// mask to show under nav bar
        layer.masksToBounds = false
        layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.37).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 6
        layer.position = center
        layer.shouldRasterize = true
    }

    func removeShadow() {
        if let sub = layer.sublayers?.first(where: { $0.name == "bottomLine" }) { sub.removeFromSuperlayer() }
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 0)
    }

    func removeBackgroundImage() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundImage = UIImage()
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }

    func image(fromLayer layer: CALayer) -> UIImage? {
        UIGraphicsBeginImageContext(layer.frame.size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        layer.render(in: context)
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return outputImage
    }
}
