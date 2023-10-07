//
//  NewMapActions.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension NewMapController {
    func enableKeyboardMethods() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func togglePrivacy(tag: Int) {
        switch tag {
        case 0:
            Mixpanel.mainInstance().track(event: "NewMapCommunityMapOn")
            mapObject?.secret = false
            mapObject?.communityMap = true
        case 1:
            Mixpanel.mainInstance().track(event: "NewMapPublicMapOn")
            mapObject?.secret = false
            mapObject?.communityMap = false
        case 2:
            Mixpanel.mainInstance().track(event: "NewMapPrivateMapOn")
            mapObject?.secret = true
            mapObject?.communityMap = false
        default: return
        }
    }

    func setFinalMapValues() {
        var text = nameField.text ?? ""
        while text.last?.isWhitespace ?? false { text = String(text.dropLast()) }
        mapObject?.mapName = text
        let lowercaseName = text.lowercased()
        mapObject?.lowercaseName = lowercaseName
        mapObject?.searchKeywords = lowercaseName.getKeywordArray()
    }

    @objc func createTapped() {
        Mixpanel.mainInstance().track(event: "NewMapCreateTap")
        setFinalMapValues()
        guard let mapObject else { return }
        DispatchQueue.main.async {
            self.delegate?.finishPassing(map: mapObject)
            let animated = self.passedMap
            self.dismiss(animated: animated)
        }
    }

    @objc func keyboardPan(_ sender: UIPanGestureRecognizer) {
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            nameField.resignFirstResponder()
        }
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.actionButton.snp.removeConstraints()
            self.actionButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 10)
                $0.leading.trailing.equalToSuperview().inset(self.margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        animateWithKeyboard(notification: notification) { _ in
            self.actionButton.snp.removeConstraints()
            self.actionButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-60)
                $0.leading.trailing.equalToSuperview().inset(self.margin)
                $0.height.equalTo(51)
                $0.centerX.equalToSuperview()
            }
        }
    }

    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
    private func animateWithKeyboard(
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
            self.view?.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }
}
