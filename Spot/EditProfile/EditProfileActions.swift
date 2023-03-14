//
//  EditProfileActions.swift
//  Spot
//
//  Created by Kenny Barone on 11/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import Firebase

extension EditProfileViewController {
    @objc func cancelTap() {
        DispatchQueue.main.async { self.navigationController?.dismiss(animated: true) }
    }

    @objc func avatarEditAction() {
        let vc = AvatarSelectionController(sentFrom: .edit, family: nil)
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen // or .overFullScreen for transparency

        navigationController?.pushViewController(vc, animated: true)
        Mixpanel.mainInstance().track(event: "EditProfileAvatarSelect")
    }

    @objc func doneTap() {
        Mixpanel.mainInstance().track(event: "EditProfileSave")
        guard var userProfile else { return }

        let oldUsername = userProfile.username
        let usernameChanged = oldUsername != usernameText
        userProfile.username = usernameText
        let keywords = usernameText.getKeywordArray()


        let userRef = db.collection("users").document(userProfile.id ?? "")
        // Update username
        userRef.updateData([
            "avatarURL": userProfile.avatarURL ?? "",
            "username": userProfile.username,
            "usernameKeywords": keywords
        ] as [String: Any])

        if usernameChanged {
            Task {
                await userService?.updateUsername(newUsername: userProfile.username, oldUsername: oldUsername)
                print("changed username")
            }
        }
        delegate?.finishPassing(userInfo: userProfile)
        DispatchQueue.main.async { self.navigationController?.dismiss(animated: true) }

    }

    func returnToLandingPage() {
        navigationController?.dismiss(animated: false, completion: {
            NotificationCenter.default.post(Notification(name: Notification.Name("Logout"), object: nil, userInfo: nil))
            UserDataModel.shared.destroy()
            let vc = LandingPageController()
            let window = UIApplication.shared.keyWindow
            window?.rootViewController = vc
        })
    }
}

extension EditProfileViewController: AvatarSelectionDelegate {
    func finishPassing(avatar: AvatarProfile) {
        avatarImage.image = UIImage(named: avatar.avatarName)
        userProfile?.avatarURL = avatar.getURL()
    }
}
