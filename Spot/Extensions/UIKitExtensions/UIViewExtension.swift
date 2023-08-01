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

    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
    func animateWithKeyboard(
        notification: NSNotification,
        animations: ((_ keyboardFrame: CGRect) -> Void)?
    ) {
        // Extract the duration of the keyboard animation
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        let duration = notification.userInfo?[durationKey] as? Double ?? 0

        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue

        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo?[curveKey] as? Int ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveValue) ?? .easeIn

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue?.cgRectValue ?? .zero)

            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }

}
