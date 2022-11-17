//
//  ImagePreviewActionsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension ImagePreviewController {
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        let direction = gesture.velocity(in: view)
        let translation = gesture.translation(in: view)
        let composite = translation.x + direction.x / 4
        let selectedIndex = UploadPostModel.shared.postObject?.selectedImageIndex ?? 0
        let imageCount = UploadPostModel.shared.postObject?.frameIndexes?.count ?? 0

        switch gesture.state {
        case .changed:
            currentImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(translation.x) })
            nextImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width + translation.x) })
            previousImage.snp.updateConstraints({ $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width + translation.x) })

        case .ended:
            if (composite < -UIScreen.main.bounds.width / 2) && (selectedIndex < imageCount - 1) {
                animateNext()
            } else if (composite > UIScreen.main.bounds.width / 2) && (selectedIndex > 0) {
                animatePrevious()
            } else {
                resetFrame()
            }

        default: return
        }

    }

    func animateNext() {
        Mixpanel.mainInstance().track(event: "ImagePreviewNextImageSwipe")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
        nextImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // reset image index
            if UploadPostModel.shared.postObject != nil { UploadPostModel.shared.postObject?.selectedImageIndex! += 1 }
            self.setImages()
        }
    }

    func animatePrevious() {
        Mixpanel.mainInstance().track(event: "ImagePreviewPreviousImageSwipe")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }

        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self = self else { return }
            /// reset image indexes
            if UploadPostModel.shared.postObject != nil { UploadPostModel.shared.postObject?.selectedImageIndex! -= 1 }
            self.setImages()
        }
    }

    func resetFrame() {
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
        nextImage.snp.updateConstraints {
            $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width )
        }
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }

    func setImages() {
        let selectedIndex = UploadPostModel.shared.postObject?.selectedImageIndex ?? 0
        currentImage.index = selectedIndex
        currentImage.makeConstraints()
        currentImage.setCurrentImage()

        previousImage.index = selectedIndex - 1
        previousImage.makeConstraints()
        previousImage.setCurrentImage()

        nextImage.index = selectedIndex + 1
        nextImage.makeConstraints()
        nextImage.setCurrentImage()
        addDots()
    }

    @objc func backTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "ImagePreviewBackTap")
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.removeAll(where: { $0.fromCamera })} /// remove old captured image

        let controllers = navigationController?.viewControllers
        if let camera = controllers?[safe: (controllers?.count ?? 0) - 3] as? AVCameraController {
            // reset postObject
            camera.setUpPost()
        }

        navigationController?.popViewController(animated: false)
    }

    @objc func atTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewTagUserTap")
        HapticGenerator.shared.play(.light)
        /// remove if @ was just tapped
        if textView.text.last == "@" { return  }
        /// add extra space if in the middle of word
        let textString = textView.text.isEmpty || textView.text.last == " " ? "@" : " @"
        textView.insertText(textString)
        addTagTable(tagString: "")

    }

    @objc func spotTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewSpotNameTap")
        if newSpotNameView.spotName != "" { newSpotNameView.textView.becomeFirstResponder(); return }
        textView.resignFirstResponder()
        launchPicker()
    }

    @objc func captionTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewCaptionTap")
        if newSpotNameView.textView.isFirstResponder { return }
        shouldAnimateTextMask = true
        textView.becomeFirstResponder()
    }

    func setCaptionValues() {
        let captionText = textView.text ?? ""
        UploadPostModel.shared.postObject?.caption = captionText == textViewPlaceholder ? "" : captionText
        UploadPostModel.shared.setTaggedUsers()
    }

    @objc func chooseMapTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewChooseMapTap")
        setCaptionValues()
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ShareTo") as? ChooseMapController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func launchPicker() {
        cancelOnDismiss = true
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ChooseSpot") as? ChooseSpotController {
            vc.delegate = self
            vc.previewVC = self
            DispatchQueue.main.async { self.present(vc, animated: true) }
        }
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        if cancelOnDismiss { return }
        if !textView.isFirstResponder { addNewSpotView(notification: notification) }

        /// only animate mask on initial open
        if shouldAnimateTextMask { postDetailView.bottomMask.alpha = 0.0 }
        shouldAnimateTextMask = false
        /// new spot name view editing when textview not first responder
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.postDetailView.bottomMask.alpha = 1.0
            self.postDetailView.snp.removeConstraints()
            self.postDetailView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height)
                $0.height.equalTo(160)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        /// new spot name view editing when textview not first responder
        if cancelOnDismiss { return }
        if !textView.isFirstResponder { removeNewSpotView() }
        animateWithKeyboard(notification: notification) { _ in
            self.postDetailView.snp.removeConstraints()
            self.postDetailView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(160)
                $0.bottom.equalTo(self.actionButton.snp.top).offset(-15)
            }
        }
    }

    func addNewSpotView(notification: NSNotification) {
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        guard let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue else { return }
        if newSpotMask != nil { return }

        newSpotMask = NewSpotMask {
            view.addSubview($0)
        }
        newSpotMask?.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(newSpotNameView.snp.top).offset(-200)
            $0.bottom.equalToSuperview()
        }

        newSpotNameView.isHidden = false
        postDetailView.isHidden = true
        view.bringSubviewToFront(newSpotNameView)
        newSpotNameView.snp.removeConstraints()
        newSpotNameView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(keyboardFrameValue.cgRectValue.minY - 200) /// - height - 140
            $0.height.equalTo(110)
        }
    }

    func removeNewSpotView() {
        if newSpotMask == nil { return }
        let spotName = newSpotNameView.textView.text?.spacesTrimmed() ?? ""
        newSpotNameView.textView.text = spotName
        if spotName != "" {
            createNewSpot(spotName: spotName)
        } else {
            cancelSpotSelection()
        }

        newSpotNameView.isHidden = true
        postDetailView.isHidden = false
        newSpotMask?.removeFromSuperview()
        newSpotMask = nil
    }

    func createNewSpot(spotName: String) {
        Mixpanel.mainInstance().track(event: "ImagePreviewCreateNewSpot")

        guard let post = UploadPostModel.shared.postObject else { return }
        var newSpot = MapSpot(
            id: UUID().uuidString,
            founderID: uid,
            post: post,
            imageURL: "",
            spotName: spotName,
            privacyLevel: "friends",
            description: ""
        )
        newSpot.posterUsername = UserDataModel.shared.userInfo.username
        finishPassing(spot: newSpot)
        UploadPostModel.shared.postType = .newSpot
    }

    func addExtraMask() {
        let extraMask = UIView {
            $0.backgroundColor = UIColor.black.withAlphaComponent(0.65)
            view.insertSubview($0, belowSubview: actionButton)
        }
        extraMask.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(postDetailView.snp.bottom)
        }
    }

    @objc func postTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewPostTap")
        postButton?.isEnabled = false
        setCaptionValues()
        /// upload post
        UploadPostModel.shared.setFinalPostValues()
        if UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }

        progressMask?.isHidden = false
        view.bringSubviewToFront(progressMask ?? UIView())
        let fullWidth = (self.progressBar?.bounds.width ?? 2) - 2

        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(
                images: UploadPostModel.shared.postObject?.postImage ?? [],
                postID: UploadPostModel.shared.postObject?.id ?? "",
                progressFill: self.progressBar?.progressFill ?? UIView(),
                fullWidth: fullWidth) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload()
                    return
                }
                UploadPostModel.shared.postObject?.imageURLs = imageURLs
                self.uploadPostToDB(newMap: true)
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    HapticGenerator.shared.play(.soft)
                    self.popToMap()
                }
            }
        }
    }

    func runFailedUpload() {
        showFailAlert()
        UploadPostModel.shared.saveToDrafts()
    }

    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style {
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError("Fail alert error")
            }}))
        present(alert, animated: true, completion: nil)
    }

    func popToMap() {
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
}