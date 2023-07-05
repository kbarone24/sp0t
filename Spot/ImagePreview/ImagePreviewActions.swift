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
import NextLevel

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
        
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.view.layoutIfNeeded()
            
        } completion: { [weak self] _ in
            // reset image index
            if UploadPostModel.shared.postObject != nil {
                var selectedIndex = UploadPostModel.shared.postObject?.selectedImageIndex ?? 0
                selectedIndex += 1
                UploadPostModel.shared.postObject?.selectedImageIndex = selectedIndex
            }
            self?.setImages()
        }
    }
    
    func animatePrevious() {
        Mixpanel.mainInstance().track(event: "ImagePreviewPreviousImageSwipe")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.view.layoutIfNeeded()
            
        } completion: { [weak self] _ in
            /// reset image indexes
            if UploadPostModel.shared.postObject != nil {
                var selectedIndex = UploadPostModel.shared.postObject?.selectedImageIndex ?? 1
                selectedIndex -= 1
                UploadPostModel.shared.postObject?.selectedImageIndex = selectedIndex
            }
            self?.setImages()
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
        guard let post = UploadPostModel.shared.postObject else {
            return
        }
        
        let selectedIndex = post.selectedImageIndex ?? 0
        currentImage.index = selectedIndex
        currentImage.configure(mode: .image(post))
        
        previousImage.index = selectedIndex - 1
        previousImage.configure(mode: .image(post))
        
        nextImage.index = selectedIndex + 1
        nextImage.configure(mode: .image(post))
        addDots()
    }

    func resetPostInfo() {
        if imageObject != nil {
            // remove old captured image
            UploadPostModel.shared.selectedObjects.removeAll(where: { $0.fromCamera })
        }
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
        if newSpotNameView.spotName != "" {
            newSpotNameView.textView.becomeFirstResponder()
            return
        }
        textView.resignFirstResponder()
        launchChooseSpot()
    }

    @objc func mapTap() {
        Mixpanel.mainInstance().track(event: "ImagePreviewMapNameTap")
        if newMapMode {
            launchNewMap()
            return
        }
        textView.resignFirstResponder()
        launchChooseMap()
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

    func launchChooseSpot() {
        cancelOnDismiss = true
        let vc = ChooseSpotController()
        vc.delegate = self
        DispatchQueue.main.async { self.present(vc, animated: true) }
    }

    func launchChooseMap() {
        cancelOnDismiss = true
        let vc = ChooseMapController()
        vc.delegate = self
        DispatchQueue.main.async { self.present(vc, animated: true) }
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
                $0.height.equalTo(200)
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
                $0.height.equalTo(200)
                $0.bottom.equalTo(self.postButton.snp.top).offset(-18)
            }
        }
    }
    
    func addNewSpotView(notification: NSNotification) {
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        guard let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue,
              newSpotMask == nil
        else {
            return
        }
        
        newSpotMask = NewSpotMask()
        if let newSpotMask {
            view.addSubview(newSpotMask)
            newSpotMask.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(newSpotNameView.snp.top).offset(-200)
                $0.bottom.equalToSuperview()
            }
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
            cancelSpot()
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
        let extraMask = UIView()
        extraMask.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        view.insertSubview(extraMask, at: 0)
        
        extraMask.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(postDetailView.snp.bottom)
        }
    }
    
    @objc func postTap() {
        // stop next level session if its still running (video camera capture)
        NextLevel.shared.stop()
        guard let imageVideoService = try? ServiceContainer.shared.service(for: \.imageVideoService) else {
            return
        }
        Mixpanel.mainInstance().track(event: "ImagePreviewPostTap")

        postButton.isEnabled = false
        view.isUserInteractionEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false

        setCaptionValues()
        // MARK: upload post
        UploadPostModel.shared.setFinalPostValues()
        if UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }
        
        progressMask.isHidden = false
        view.bringSubviewToFront(progressMask)
        let fullWidth = (self.progressBar.bounds.width) - 2

        switch mode {
        case .image:
            imageVideoService.uploadImages(
                images: UploadPostModel.shared.postObject?.postImage ?? [],
                parentView: view,
                progressFill: self.progressBar.progressFill,
                fullWidth: fullWidth
            ) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload(videoData: nil)
                    return
                }
                UploadPostModel.shared.postObject?.imageURLs = imageURLs
                self.uploadPostToDB(newMap: self.newMapMode)
                /// enable upload animation to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    HapticGenerator.shared.play(.soft)
                    self.popToMap()
                }
            }
            
        case .video(let url):
            let dispatch = DispatchGroup()
            dispatch.enter()

            //MARK: Upload video data
            guard let data = try? Data(contentsOf: url) else {
                showFailAlert()
                return
            }
            imageVideoService.uploadVideo(data: data) { [weak self] (videoURL) in
                guard videoURL != "" else {
                    self?.runFailedUpload(videoData: data)
                    return
                }
                UploadPostModel.shared.postObject?.videoURL = videoURL
                dispatch.leave()
            } failure: { [weak self] _ in
                self?.showFailAlert()
                return
            }

            //MARK: Upload thumbnail image
            dispatch.enter()
            imageVideoService.uploadImages(
                images: UploadPostModel.shared.postObject?.postImage ?? [],
                parentView: view,
                progressFill: self.progressBar.progressFill,
                fullWidth: fullWidth
            ) { [weak self] imageURLs, failed in
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUploadOnVideo")
                    self?.runFailedUpload(videoData: data)
                    return
                }
                UploadPostModel.shared.postObject?.imageURLs = imageURLs
                dispatch.leave()
            }

            //MARK: Finish upload
            dispatch.notify(queue: .global()) { [weak self] in
                self?.uploadPostToDB(newMap: self?.newMapMode ?? false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    HapticGenerator.shared.play(.soft)
                    self?.popToMap()
                }
            }
        }
    }
    
    func runFailedUpload(videoData: Data?) {
        showFailAlert()
        UploadPostModel.shared.saveToDrafts(videoData: videoData)
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { action in
                switch action.style {
                case .default:
                    self.popToMap()
                case .cancel:
                    self.popToMap()
                case .destructive:
                    self.popToMap()
                @unknown default:
                    fatalError("Fail alert error")
                }
            }
        )
        
        present(alert, animated: true, completion: nil)
    }
    
    func popToMap() {
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async {
            self.dismiss(animated: true)
        }
    }
    
    private func uploadPostToDB(newMap: Bool) {
        guard let post = UploadPostModel.shared.postObject,
              let spotService = try? ServiceContainer.shared.service(for: \.spotService),
              let postService = try? ServiceContainer.shared.service(for: \.mapPostService),
              let mapService = try? ServiceContainer.shared.service(for: \.mapsService),
              let userService = try? ServiceContainer.shared.service(for: \.userService)
        else { return }
        
        let spot = UploadPostModel.shared.spotObject
        let map = UploadPostModel.shared.mapObject

        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            if UploadPostModel.shared.imageFromCamera, let image = post.postImage.first {
                DispatchQueue.global(qos: .background).async {
                    SpotPhotoAlbum.shared.save(image: image)
                }

            } else if UploadPostModel.shared.videoFromCamera, let videoURL = videoObject?.videoPath {
                DispatchQueue.global(qos: .background).async {
                    SpotPhotoAlbum.shared.save(videoURL: videoURL)
                }
            }
        }

        DispatchQueue.global(qos: .background).async {
            if var spot = spot {
                spot.imageURL = post.imageURLs.first ?? ""
                spotService.uploadSpot(post: post, spot: spot, submitPublic: false)
            }
            
            if var map = map {
                if map.imageURL == "" {
                    map.imageURL = post.imageURLs.first ?? ""
                }
                
                map.postImageURLs.append(post.imageURLs.first ?? "")
                mapService.uploadMap(map: map, newMap: newMap, post: post, spot: spot)
            }
            
            postService.uploadPost(post: post, map: map, spot: spot, newMap: newMap)
            
            let visitorList = spot?.visitorList ?? []
            userService.setUserValues(
                poster: UserDataModel.shared.uid,
                post: post,
                spotID: spot?.id ?? "",
                visitorList: visitorList,
                mapID: map?.id ?? ""
            )
            
            Mixpanel.mainInstance().track(event: "SuccessfulPostUpload")
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

    @objc func enteredForeground() {
        DispatchQueue.main.async {
            self.player?.play()
        }
    }
}
