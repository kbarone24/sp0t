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
        Mixpanel.mainInstance().track(event: "EditProfileAvatarSelect")

        let vc = AvatarSelectionController(sentFrom: .edit, family: nil)
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen // or .overFullScreen for transparency

        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func doneTap() {
        Mixpanel.mainInstance().track(event: "EditProfileSave")

        guard var userProfile else { return }
        let oldUsername = userProfile.username
        userProfile.username = usernameText
        let keywords = usernameText.getKeywordArray()

        userProfile.userBio = userBioView.text == bioEmptyState ? "" : userBioView.text
        userService?.updateProfile(userProfile: userProfile, keywords: keywords, oldUsername: oldUsername)

        delegate?.finishPassing(userInfo: userProfile, passedAvatarProfile: passedAvatarProfile)
        DispatchQueue.main.async { self.navigationController?.dismiss(animated: true) }
    }

    func returnToLandingPage() {
        navigationController?.dismiss(animated: false, completion: {
            Mixpanel.mainInstance().track(event: "EditProfileLogoutTap")
            
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
        userProfile?.avatarFamily = avatar.family.rawValue
        userProfile?.avatarItem = avatar.item?.rawValue
        passedAvatarProfile = avatar
    }
}
