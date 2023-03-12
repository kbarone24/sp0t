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
        print("back tap")
        DispatchQueue.main.async { self.navigationController?.dismiss(animated: true) }
    }

    @objc func profilePicSelectionAction() {
        Mixpanel.mainInstance().track(event: "ProfilePicSelection")
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.overrideUserInterfaceStyle = .light
        let takePicAction = UIAlertAction(title: "Take picture", style: .default) { _ in
            Mixpanel.mainInstance().track(event: "ProfilePicSelectCamera")
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            picker.delegate = self
            picker.sourceType = .camera
            self.present(picker, animated: true)
        }
        takePicAction.titleTextColor = .black
        let choosePicAction = UIAlertAction(title: "Choose from gallery", style: .default) { _ in
            Mixpanel.mainInstance().track(event: "ProfilePicSelectGallery")
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            picker.delegate = self
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true)
        }
        choosePicAction.titleTextColor = .black
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        cancelAction.titleTextColor = .black
        alertController.addAction(takePicAction)
        alertController.addAction(choosePicAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
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
        self.activityIndicator.startAnimating()
        userProfile?.currentLocation = locationTextfield.text ?? ""

        let userRef = db.collection("users").document(userProfile?.id ?? "")
        userRef.updateData([
            "currentLocation": userProfile?.currentLocation ?? "",
            "avatarURL": userProfile?.avatarURL ?? ""] as [String: Any])

        if profileChanged {
            updateProfileImage()
        } else {
            guard let userProfile else { return }
            delegate?.finishPassing(userInfo: userProfile)
            self.activityIndicator.stopAnimating()
            DispatchQueue.main.async { self.navigationController?.dismiss(animated: true) }
        }
    }

    private func updateProfileImage() {
        let imageId = UUID().uuidString
        let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")
        guard let image = profileImage.image else { return }
        guard var imageData = image.jpegData(compressionQuality: 0.5) else { return }

        if imageData.count > 1_000_000 {
            imageData = image.jpegData(compressionQuality: 0.3) ?? Data()
        }

        var urlStr: String = ""
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        storageRef.putData(imageData, metadata: metadata) {metadata, error in

            if error == nil, metadata != nil {
                // get download url
                storageRef.downloadURL(completion: { [weak self] url, error in
                    if let error = error {
                        print("\(error.localizedDescription)")
                    }
                    urlStr = (url?.absoluteString) ?? ""
                    guard let self = self else { return }

                    self.userProfile?.imageURL = urlStr
                    self.userProfile?.profilePic = image

                    let values = ["imageURL": urlStr]
                    self.db.collection("users").document(self.userProfile?.id ?? "").updateData(values)
                    self.activityIndicator.stopAnimating()

                    guard let userProfile = self.userProfile else { return }
                    DispatchQueue.main.async {
                        self.delegate?.finishPassing(userInfo: userProfile)
                        self.navigationController?.dismiss(animated: true)
                        return
                    }
                })
            } else { print("handle error")}
        }
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
        avatarChanged = true
        avatarImage.image = UIImage(named: avatar.avatarName)
        userProfile?.avatarURL = avatar.getURL()
    }
}
