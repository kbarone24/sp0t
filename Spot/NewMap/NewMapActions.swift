//
//  NewMapActions.swift
//  Spot
//
//  Created by Kenny Barone on 2/21/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import IQKeyboardManagerSwift

extension NewMapController {
    func enableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = true
        IQKeyboardManager.shared.enable = true
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
        mapObject?.coverImage = UploadPostModel.shared.postObject?.postImage.first ?? UIImage()
        if newMapMode {
            UploadPostModel.shared.postObject?.hideFromFeed = mapObject?.secret ?? false
            UploadPostModel.shared.setMapValues(map: mapObject)
        }
    }

    @objc func nextTapped() {
        Mixpanel.mainInstance().track(event: "NewMapNextTap")
        setFinalMapValues()

        let vc = CameraViewController()
        DispatchQueue.main.async {
            vc.newMapMode = true
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func createTapped() {
        Mixpanel.mainInstance().track(event: "NewMapCreateTap")
        setFinalMapValues()
        guard let mapObject else { return }
        delegate?.finishPassing(map: mapObject)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func cancelTapped() {
        Mixpanel.mainInstance().track(event: "NewMapCancelTap")
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }

    @objc func keyboardPan(_ sender: UIPanGestureRecognizer) {
        if abs(sender.translation(in: view).y) > abs(sender.translation(in: view).x) {
            nameField.resignFirstResponder()
        }
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.actionButton.snp.removeConstraints()
            let tabBarOffset = self.newMapMode ? (self.tabBarController?.tabBar.frame.height ?? 0) : 0
            self.actionButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 10 + tabBarOffset)
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
