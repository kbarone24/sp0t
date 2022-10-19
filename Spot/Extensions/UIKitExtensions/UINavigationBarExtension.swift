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
        if let sub = layer.sublayers?.first(where: {$0.name == "bottomLine"}) { sub.removeFromSuperlayer() }
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 0)
    }
    
    func addGradientBackground(alpha: CGFloat) {
        /// gradient nav bar background
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight + bounds.height
        
        let gradient = CAGradientLayer()
        let sizeLength: CGFloat = UIScreen.main.bounds.size.height * 2
        let defaultNavigationBarFrame = CGRect(x: 0, y: 0, width: sizeLength, height: navBarHeight)
        
        gradient.frame = defaultNavigationBarFrame
        gradient.colors = [UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: alpha).cgColor, UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: alpha).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = self.image(fromLayer: gradient)
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(self.image(fromLayer: gradient), for: .default)
        }
    }
    
    func addBlackBackground() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .black
            appearance.titleTextAttributes[.foregroundColor] = UIColor.white
            appearance.titleTextAttributes[.font] = UIFont(name: "SFCompactText-Heavy", size: 19)!
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(color: UIColor.black), for: .default)
        }
    }
    
    func addWhiteBackground() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .white
            appearance.titleTextAttributes[.foregroundColor] = UIColor.black
            appearance.titleTextAttributes[.font] = UIFont(name: "SFCompactText-Heavy", size: 19)!
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(color: UIColor.white), for: .default)
        }
    }
    
    func removeBackgroundImage() {
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = UIImage()
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(), for: .default)
        }
    }
    
    func image(fromLayer layer: CALayer) -> UIImage {
        UIGraphicsBeginImageContext(layer.frame.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return outputImage!
    }
}

