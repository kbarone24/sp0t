//
//  CreatePostPickerDelegates.swift
//  Spot
//
//  Created by Kenny Barone on 7/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI
import IQKeyboardManagerSwift
import Mixpanel

extension CreatePostController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.alpha = 1.0
        if textView.text == textViewPlaceholder {
            textView.text = ""
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text == "" {
            textView.text = textViewPlaceholder
            textView.alpha = 0.6
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let cursor = textView.getCursorPosition()
        let text = textView.text ?? ""
        let tagTuple = text.getTagUserString(cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
            textView.autocorrectionType = .default
        } else {
            addTagTable(tagString: tagString)
            textView.autocorrectionType = .no
        }

        togglePostButton()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let dummyString = usernameDummyString, range.location < dummyString.count {
            // preserve reply username spacing
            return false
        }
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 140)
    }

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

    @objc func keyboardWillShow(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { keyboardFrame in
            self.cameraButton.snp.removeConstraints()
            self.cameraButton.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height - 5)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        view.animateWithKeyboard(notification: notification) { _ in
            self.cameraButton.snp.removeConstraints()
            self.cameraButton.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-100)
            }
        }
    }
}

extension CreatePostController: TagFriendsDelegate {
    func removeTagTable() {
        tagFriendsView.removeFromSuperview()
    }

    func addTagTable(tagString: String) {
        tagFriendsView.setUp(
            userList: UserDataModel.shared.userInfo.friendsList,
            textColor: .white,
            backgroundColor: SpotColors.SpotBlack.color.withAlphaComponent(0.85),
            delegate: self,
            allowSearch: true,
            tagParent: .ImagePreview,
            searchText: tagString
        )
        view.addSubview(tagFriendsView)
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(94)
            $0.top.equalTo(textView.snp.bottom)
        }
    }

    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}


extension CreatePostController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            Mixpanel.mainInstance().track(event: "CreatePostFinishedTakingPicture")
            addThumbnailView(imageObject: ImageObject(image: image, fromCamera: true), videoObject: nil)
            
        } else if let url = info[.mediaURL] as? URL {
            Mixpanel.mainInstance().track(event: "CreatePostFinishedSelectingFromGallery")
            addThumbnailView(imageObject: nil, videoObject: VideoObject(url: url, fromCamera: true))
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        if let result = results.first {
            let itemProvider = result.itemProvider
            guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
                  let utType = UTType(typeIdentifier)
            else { return }

            if utType.conforms(to: .movie) {
                let identifiers = results.compactMap(\.assetIdentifier)
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                if let asset = fetchResult.firstObject {
                    DispatchQueue.main.async {
                        self.launchVideoEditor(asset: asset)
                        picker.dismiss(animated: true)
                    }
                }

            } else {
                itemProvider.getPhoto { [weak self] image in
                    guard let self = self else { return }
                    if let image {
                        DispatchQueue.main.async {
                            self.launchStillImagePreview(imageObject: ImageObject(image: image, fromCamera: false))
                            picker.dismiss(animated: true)
                        }
                    }
                }
            }
        }
    }
}
// src: https://www.appcoda.com/phpicker/

extension CreatePostController: VideoEditorDelegate, StillImagePreviewDelegate {
    func finishPassing(imageObject: ImageObject) {
        addThumbnailView(imageObject: imageObject, videoObject: nil)
    }

    func finishPassing(videoObject: VideoObject) {
        addThumbnailView(imageObject: nil, videoObject: videoObject)
    }
}

extension CreatePostController: CreateThumbnailDelegate {
    func cancel() {
        thumbnailView?.removeFromSuperview()
        thumbnailView = nil
        imageObject = nil
        videoObject = nil
    }

    func expandThumbnail() {
        textView.resignFirstResponder()
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }

        view.layoutIfNeeded()
        guard var thumbnailFrame = thumbnailView?.frame else { return }
        let yOffset = UserDataModel.shared.statusHeight + (navigationController?.navigationBar.frame.height ?? 0)
        thumbnailFrame = CGRect(x: thumbnailFrame.minX, y: thumbnailFrame.minY + yOffset, width: thumbnailFrame.width, height: thumbnailFrame.height)

        if let videoObject {
            let fullscreenView = FullScreenVideoView(
                thumbnailImage: videoObject.thumbnailImage,
                urlString: videoObject.videoPath.absoluteString,
                initialFrame: thumbnailFrame
            )
            window.addSubview(fullscreenView)
            fullscreenView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            fullscreenView.expand()

        } else if let imageObject {
            let imageAspect = imageObject.stillImage.size.height / imageObject.stillImage.size.width
            let fullscreenView = FullScreenImageView(
                image: imageObject.stillImage,
                urlString: "",
                imageAspect: imageAspect,
                initialFrame: thumbnailFrame
            )
            window.addSubview(fullscreenView)
            fullscreenView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            fullscreenView.expand()
        }
    }
}
