//
//  UIViewExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import UIKit

extension UIView {
    // MARK: - This should be removed!!!
    // It's not a good practive to initialize views this way with closures
    @available(*, deprecated, message: "This initializer will be removed in the future. It's a practice")
    convenience init(configureHandler: (Self) -> Void) {
        self.init()
        configureHandler(self)
    }
    
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
    
    func getStatusHeight() -> CGFloat {
        let window = UIApplication.shared.keyWindow
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        return statusHeight
    }
    
    func addShadow(shadowColor: CGColor, opacity: Float, radius: CGFloat, offset: CGSize) {
        layer.shadowColor = shadowColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = offset
    }
}
