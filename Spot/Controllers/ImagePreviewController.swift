//
//  ImagePreviewController.swift
//  Spot
//
//  Created by kbarone on 2/27/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import Firebase
import Mixpanel
import CoreLocation
import IQKeyboardManagerSwift
import SnapKit

class ImagePreviewController: UIViewController {
    var currentImage: PostImagePreview!
    var nextImage: PostImagePreview!
    var previousImage: PostImagePreview!
    
    var backButton: UIButton!
    var dotView: UIView!
    var nextButton: FooterNextButton?
    var postButton: UIButton?
    
    var progressMask: UIView?
    var progressBar: ProgressBar?
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
    /// detailView
    var postDetailView: PostDetailView!
    var spotNameButton: SpotNameButton!
    var atButton: UIButton!
    var newSpotNameView: NewSpotNameView!
    var newSpotMask: NewSpotMask?
    
    var cancelOnDismiss = false
    var newMapMode = false
    var cameraObject: ImageObject!
    
    var swipeToClose: UIPanGestureRecognizer! /// swipe down to close keyboard
    var tapToClose: UITapGestureRecognizer! /// tap to close keyboard
    
    var textView: UITextView!
    let textViewPlaceholder = "Write a caption..."
    
    var shouldAnimateTextMask = false /// keyboardWillShow firing late -> this variable tells keyboardWillChange whether to reposition
    lazy var firstImageBottomConstraint: CGFloat = 0
    
    var tagFriendsView: TagFriendsView?
    var actionButton: UIButton {
        return newMapMode ? postButton ?? UIButton() : nextButton ?? UIButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        /// set hidden for smooth transition
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ImagePreviewOpen")
        enableKeyboardMethods()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = true
        disableKeyboardMethods()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.tag = 2
        
        setPostInfo()
        addPreviewView()
        addPostDetail()
    }
    
    func enableKeyboardMethods() {
        cancelOnDismiss = false
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func disableKeyboardMethods() {
        cancelOnDismiss = true
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }
        
    func setPostInfo() {
        newMapMode = UploadPostModel.shared.mapObject != nil
        var post = UploadPostModel.shared.postObject!
        
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        var imageLocations: [[String: Double]] = []
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.append(cameraObject) }
        
        /// cycle through selected imageObjects and find individual sets of images / frames
        for obj in UploadPostModel.shared.selectedObjects {
            let location = locationIsEmpty(location: obj.rawLocation) ? UserDataModel.shared.currentLocation : obj.rawLocation
            imageLocations.append(["lat" : location!.coordinate.latitude, "long": location!.coordinate.longitude])
           
            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height/selectedImages[frameCounter].size.width)

            frameCounter += images.count
        }
        
        post.frameIndexes = frameIndexes
        post.aspectRatios = aspectRatios
        post.postImage = selectedImages
        post.imageLocations = imageLocations
        
        let imageLocation = UploadPostModel.shared.selectedObjects.first?.rawLocation ?? UserDataModel.shared.currentLocation ?? CLLocation()
        if !locationIsEmpty(location: imageLocation) {
            post.setImageLocation = true
            post.postLat = imageLocation.coordinate.latitude
            post.postLong = imageLocation.coordinate.longitude
        }
        
        UploadPostModel.shared.postObject = post
        UploadPostModel.shared.setPostCity()
    }
    
    func addPreviewView() {
        view.backgroundColor = .black
        /// add initial preview view and buttons
        let post = UploadPostModel.shared.postObject!

        currentImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex!)
        view.addSubview(currentImage)
        currentImage.makeConstraints()
        currentImage.setCurrentImage()

        if post.frameIndexes!.count > 1 {
            nextImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! + 1)
            view.addSubview(nextImage)
            nextImage.makeConstraints()
            nextImage.setCurrentImage()
            
            previousImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! - 1)
            view.addSubview(previousImage)
            previousImage.makeConstraints()
            previousImage.setCurrentImage()
            
            let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            view.addGestureRecognizer(pan)
            addDotView()
        }
                                
        /// add cancel button
        backButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "BackArrow"), for: .normal)
            $0.addTarget(self, action: #selector(backTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalTo(5.5)
            $0.top.equalToSuperview().offset(60)
            $0.width.equalTo(48.6)
            $0.height.equalTo(38.6)
        }
        
        if newMapMode {
            let titleView = NewMapTitleView {
                view.addSubview($0)
            }
            titleView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(60)
                $0.top.equalTo(backButton!.snp.top).offset(2)
                $0.centerX.equalToSuperview()
            }
            
            postButton = PillButtonWithImage {
                $0.setUp(image: UIImage(named: "PostIcon")!, str: "Post")
                $0.layer.cornerRadius = 9
                $0.addTarget(self, action: #selector(postTap), for: .touchUpInside)
                view.addSubview($0)
            }
            postButton!.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(51)
                $0.bottom.equalTo(-43)
            }
            
            progressMask = UIView {
                $0.backgroundColor = .black.withAlphaComponent(0.7)
                $0.isHidden = true
                view.addSubview($0)
            }
            progressMask!.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            
            progressBar = ProgressBar {
                progressMask!.addSubview($0)
            }
            progressBar!.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(50)
                $0.bottom.equalTo(postButton!.snp.top).offset(-20)
                $0.height.equalTo(18)
            }
            
        } else {
            nextButton = FooterNextButton {
                $0.addTarget(self, action: #selector(chooseMapTap), for: .touchUpInside)
                $0.isEnabled = true
                view.addSubview($0)
            }
            nextButton!.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(15)
                $0.bottom.equalToSuperview().inset(50)
                $0.width.equalTo(94)
                $0.height.equalTo(40)
            }
        }
        
        swipeToClose = UIPanGestureRecognizer(target: self, action: #selector(swipeToClose(_:)))
        swipeToClose.isEnabled = false
        view.addGestureRecognizer(swipeToClose)
        
        tapToClose = UITapGestureRecognizer(target: self, action: #selector(tapToClose(_:)))
        tapToClose.isEnabled = false
        view.addGestureRecognizer(tapToClose)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(captionTap))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
        
    func addDotView() {
        let imageCount = UploadPostModel.shared.postObject.frameIndexes!.count
        let dotWidth = (9 * imageCount) + (5 * (imageCount - 1))
        dotView = UIView {
            $0.backgroundColor = nil
            view.addSubview($0)
        }
        dotView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(73)
            $0.height.equalTo(9)
            $0.width.equalTo(dotWidth)
            $0.centerX.equalToSuperview()
        }
        addDots()
    }
    
    func addDots() {
        if dotView != nil { for sub in dotView.subviews { sub.removeFromSuperview() } }
        for i in 0...UploadPostModel.shared.postObject.frameIndexes!.count - 1 {
            let dot = UIView {
                $0.layer.borderColor = UIColor.white.cgColor
                $0.layer.borderWidth = 1
                $0.backgroundColor = i == UploadPostModel.shared.postObject.selectedImageIndex! ? .white : .clear
                $0.layer.cornerRadius = 9/2
                dotView.addSubview($0)
            }
            let leading = i * 14
            dot.snp.makeConstraints {
                $0.leading.equalTo(leading)
                $0.top.equalToSuperview()
                $0.width.height.equalTo(9)
            }
        }
    }

    func addPostDetail() {
        postDetailView = PostDetailView {
            view.addSubview($0)
        }
        postDetailView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(160)
            $0.bottom.equalToSuperview().offset(-105) /// hard code bc done button and next button not perfectly aligned
        }
        
        textView = UITextView {
            $0.delegate = self
            $0.backgroundColor = nil
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.alpha = 0.6
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.text = textViewPlaceholder
            $0.returnKeyType = .done
            $0.textContainerInset = UIEdgeInsets(top: 10, left: 19, bottom: 14, right: 60)
            $0.isScrollEnabled = false
            $0.textContainer.maximumNumberOfLines = 6
            $0.textContainer.lineBreakMode = .byTruncatingHead
            $0.isUserInteractionEnabled = false
            postDetailView.addSubview($0)
        }
        textView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.lessThanOrEqualToSuperview().inset(36)
            $0.bottom.equalToSuperview().offset(-3)
        }
        
        atButton = UIButton {
            $0.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            $0.setTitle("@", for: .normal)
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-SemiboldItalic", size: 25)
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            $0.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 2.5, right: 0)
            $0.layer.cornerRadius = 36/2
            $0.addTarget(self, action: #selector(atTap), for: .touchUpInside)
            $0.isHidden = true
            $0.clipsToBounds = false
            postDetailView.addSubview($0)
        }
        atButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(textView.snp.top).offset(-4)
            $0.height.width.equalTo(36)
        }
        
        spotNameButton = SpotNameButton {
            $0.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
            postDetailView.addSubview($0)
        }
        spotNameButton.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.bottom.equalTo(textView.snp.top)
            $0.height.equalTo(36)
            $0.trailing.lessThanOrEqualToSuperview().inset(16)
        }
        
        newSpotNameView = NewSpotNameView {
            $0.isHidden = true
            view.addSubview($0)
        }
        
        if UserDataModel.shared.screenSize == 0 && UploadPostModel.shared.postObject.postImage.contains(where: {$0.aspectRatio() > 1.45 }) {
            addExtraMask()
        }
    }
        
    @objc func imageSwipe(_ gesture: UIPanGestureRecognizer) {
        let direction = gesture.velocity(in: view)
        let translation = gesture.translation(in: view)
        let composite = translation.x + direction.x/4
        let selectedIndex = UploadPostModel.shared.postObject.selectedImageIndex!
        let imageCount = UploadPostModel.shared.postObject.frameIndexes!.count
        
        switch gesture.state {
        case .changed:
            currentImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(translation.x)})
            nextImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width + translation.x)})
            previousImage.snp.updateConstraints({$0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width + translation.x)})
            
        case .ended:
            if (composite < -UIScreen.main.bounds.width/2) && (selectedIndex < imageCount - 1) {
                animateNext()
            } else if (composite > UIScreen.main.bounds.width/2) && (selectedIndex > 0) {
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
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self else { return }
            /// reset image indexe
            UploadPostModel.shared.postObject!.selectedImageIndex! += 1
            self.setImages()
        }
    }
    
    func animatePrevious() {
        Mixpanel.mainInstance().track(event: "ImagePreviewPreviousImageSwipe")
        currentImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        previousImage.snp.updateConstraints { $0.leading.trailing.equalToSuperview() }
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self else { return }
            /// reset image indexes
            UploadPostModel.shared.postObject!.selectedImageIndex! -= 1
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
        let selectedIndex = UploadPostModel.shared.postObject!.selectedImageIndex!
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
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.removeAll(where: {$0.fromCamera})} /// remove old captured image
        
        let controllers = navigationController?.viewControllers
        if let camera = controllers?[safe: (controllers?.count ?? 0) - 3] as? AVCameraController {
            /// set spotObject to nil if we're not posting directly to the spot from the spot page
            if camera.spotObject == nil { UploadPostModel.shared.setSpotValues(spot: nil) }
            /// reset postObject
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
        UploadPostModel.shared.postObject.caption = captionText == textViewPlaceholder ? "" : captionText
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
        animateWithKeyboard(notification: notification) { keyboardFrame in
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
        let keyboardFrameValue = notification.userInfo![frameKey] as! NSValue
        
        newSpotMask = NewSpotMask {
            view.addSubview($0)
        }
        newSpotMask!.snp.makeConstraints {
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
        let spotName = newSpotNameView.textView.text!.spacesTrimmed()
        newSpotNameView.textView.text = spotName
        if spotName != "" {
            createNewSpot(spotName: spotName)
        } else {
            cancelSpotSelection()
        }
        
        newSpotNameView.isHidden = true
        postDetailView.isHidden = false
        newSpotMask!.removeFromSuperview()
        newSpotMask = nil
    }
    
    func createNewSpot(spotName: String) {
        Mixpanel.mainInstance().track(event: "ImagePreviewCreateNewSpot")
        let post = UploadPostModel.shared.postObject!
        var newSpot = MapSpot(founderID: uid, imageURL: "", privacyLevel: "friends", spotDescription: "", spotLat: post.postLat, spotLong: post.postLong, spotName: spotName)
        newSpot.id = UUID().uuidString
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
        postButton!.isEnabled = false
        setCaptionValues()
        /// upload post
        UploadPostModel.shared.setFinalPostValues()
        if UploadPostModel.shared.mapObject != nil { UploadPostModel.shared.setFinalMapValues() }
        
        progressMask!.isHidden = false
        view.bringSubviewToFront(progressMask!)
        let fullWidth = self.progressBar!.bounds.width - 2

        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadPostImage(UploadPostModel.shared.postObject.postImage, postID: UploadPostModel.shared.postObject.id!, progressFill: self.progressBar!.progressFill, fullWidth: fullWidth) { [weak self] imageURLs, failed in
                guard let self = self else { return }
                if imageURLs.isEmpty && failed {
                    Mixpanel.mainInstance().track(event: "FailedPostUpload")
                    self.runFailedUpload()
                    return
                }
                UploadPostModel.shared.postObject.imageURLs = imageURLs
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
            switch action.style{
            case .default:
                self.popToMap()
            case .cancel:
                self.popToMap()
            case .destructive:
                self.popToMap()
            @unknown default:
                fatalError()
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

extension ImagePreviewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        /// cancel  caption tap when textView is open
        if gestureRecognizer.view?.tag == 2 && textView.isFirstResponder { return false }
        return true
    }
}

extension ImagePreviewController: ChooseSpotDelegate {
    func finishPassing(spot: MapSpot?) {
        cancelOnDismiss = false
        if spot != nil {
            UploadPostModel.shared.setSpotValues(spot: spot)
            spotNameButton.spotName = spot!.spotName
        } else {
            newSpotNameView.textView.becomeFirstResponder()
        }
        
    }
    func cancelSpotSelection() {
        UploadPostModel.shared.setSpotValues(spot: nil)
        spotNameButton.spotName = nil
    }
 }

extension ImagePreviewController: TagFriendsDelegate {
    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}

extension ImagePreviewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        HapticGenerator.shared.play(.medium)
        swipeToClose.isEnabled = true
        tapToClose.isEnabled = true
        if textView.text == textViewPlaceholder { textView.text = ""; textView.alpha = 1.0 }
        textView.isUserInteractionEnabled = true
        
       atButton.isHidden = false
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        swipeToClose.isEnabled = false
        tapToClose.isEnabled = false
        if textView.text == "" { textView.text = textViewPlaceholder; textView.alpha = 0.6 }
        textView.isUserInteractionEnabled = false
        
        atButton.isHidden = true
        removeTagTable()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        /// return on done button tap
        if text == "\n" { textView.endEditing(true); return false }
        
        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * maxLines + 30 /// lineheight * # lines  + textContainer insets
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)

        let val = getCaptionHeight(text: updatedText) <= maxHeight
        return val
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let cursor = textView.getCursorPosition()
        let tagTuple = getTagUserString(text: textView.text ?? "", cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
            textView.autocorrectionType = .default
        } else {
            addTagTable(tagString: tagString)
            textView.autocorrectionType = .no
        }
    }
    
    func removeTagTable() {
        if tagFriendsView != nil {
            tagFriendsView!.removeFromSuperview()
            tagFriendsView = nil
            spotNameButton.isHidden = false
        }
    }
    
    func addTagTable(tagString: String) {
        if tagFriendsView == nil {
            tagFriendsView = TagFriendsView {
                $0.delegate = self
                $0.textColor = .white
                $0.searchText = tagString
                postDetailView.addSubview($0)
            }
            tagFriendsView!.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(90)
                $0.bottom.equalTo(spotNameButton.snp.bottom)
            }
            spotNameButton.isHidden = true
        } else {
            tagFriendsView?.searchText = tagString
        }
    }
    
    func getCaptionHeight(text: String) -> CGFloat {
        let temp = UITextView(frame: textView.frame)
        temp.text = text
        temp.font = UIFont(name: "SFCompactText-Regular", size: 19)
        temp.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        temp.isScrollEnabled = false
        temp.textContainer.maximumNumberOfLines = 6
        
        let size = temp.sizeThatFits(CGSize(width: temp.bounds.width, height: UIScreen.main.bounds.height))
        return max(51, size.height)
    }
    
    @objc func swipeToClose(_ sender: UIPanGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        let direction = sender.velocity(in: view)
        
        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            swipeToClose.isEnabled = false
            tapToClose.isEnabled = false
        }
    }
    
    @objc func tapToClose(_ sender: UITapGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        print("frame y", sender.location(in: postDetailView).y)
        if sender.location(in: postDetailView).y > spotNameButton.frame.minY { print(">"); return }
        textView.resignFirstResponder()
        swipeToClose.isEnabled = false
        tapToClose.isEnabled = false
    }
}

class SpotNameButton: UIButton {
    var spotIcon: UIImageView!
    var nameLabel: UILabel!
    var separatorLine: UIView!
    var cancelButton: UIButton!
    
    var spotName: String? {
        didSet {
            nameLabel.text = spotName ?? "Add spot"
            if spotName != nil {
                separatorLine.isHidden = false
                separatorLine.snp.updateConstraints { $0.height.equalTo(21) }
                cancelButton.isHidden = false
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(26) }
                nameLabel.snp.updateConstraints { $0.trailing.equalTo(separatorLine.snp.leading).offset(-8) }
            } else {
                separatorLine.isHidden = true
                separatorLine.snp.updateConstraints { $0.height.equalTo(1) }
                cancelButton.isHidden = true
                cancelButton.snp.updateConstraints { $0.height.width.equalTo(5) }
                nameLabel.snp.updateConstraints { $0.trailing.equalTo(separatorLine.snp.leading).offset(-3) }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        
        spotIcon = UIImageView {
            $0.image = UIImage(named: "AddSpotIcon")
            addSubview($0)
        }
        spotIcon.snp.makeConstraints {
            $0.leading.equalTo(11)
            $0.height.equalTo(21)
            $0.width.equalTo(17.6)
            $0.centerY.equalToSuperview()
        }
                
        cancelButton = UIButton {
            $0.setImage(UIImage(named: "ChooseSpotCancel"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.isHidden = true
            addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(6)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }
                
        separatorLine = UIView {
            $0.backgroundColor = UIColor(red: 0.308, green: 0.308, blue: 0.308, alpha: 1)
            $0.isHidden = true
            addSubview($0)
        }
        separatorLine.snp.makeConstraints {
            $0.trailing.equalTo(cancelButton.snp.leading).offset(-3)
            $0.height.width.equalTo(1)
            $0.centerY.equalToSuperview()
        }
        
        nameLabel = UILabel {
            $0.text = UploadPostModel.shared.spotObject?.spotName ?? "Add spot"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            $0.lineBreakMode = .byTruncatingTail
            $0.sizeToFit()
            addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(spotIcon.snp.trailing).offset(6.5)
            $0.trailing.equalTo(separatorLine.snp.leading).offset(-3)
            $0.centerY.equalToSuperview()
        }

        /// remove tapGesture if previously added
        if let tap = gestureRecognizers?.first(where: {$0.isKind(of: UITapGestureRecognizer.self)}) { removeGestureRecognizer(tap) }
    }
    
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let margin: CGFloat = 7
        let area = self.bounds.insetBy(dx: -margin, dy: -margin)
        return area.contains(point)
    }
    /// expand toucharea -> https://stackoverflow.com/questions/808503/uibutton-making-the-hit-area-larger-than-the-default-hit-area
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        if let previewVC = viewContainingController() as? ImagePreviewController {
            previewVC.cancelSpotSelection()
        }
    }
}

class PostImagePreview: PostImageView {
    var index: Int!
    
    convenience init(frame: CGRect, index: Int) {
        self.init(frame: frame)
        self.index = index
        
        contentMode = .scaleAspectFill
        clipsToBounds = true
        isUserInteractionEnabled = true
        layer.cornerRadius = 5
        backgroundColor = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func makeConstraints() {
        snp.removeConstraints()
            
        let post = UploadPostModel.shared.postObject!
        let currentImage = post.postImage[safe: post.frameIndexes?[safe: index] ?? -1] ?? UIImage(color: .black, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        let currentAspect = (currentImage.size.height) / (currentImage.size.width)
        let layoutValues = getImageLayoutValues(imageAspect: currentAspect)
        let currentHeight = layoutValues.imageHeight
        let bottomConstraint = layoutValues.bottomConstraint
        
        snp.makeConstraints {
            $0.height.equalTo(currentHeight)
            $0.bottom.equalTo(-bottomConstraint)
            if index == post.selectedImageIndex { $0.leading.trailing.equalToSuperview() }
            else if index < post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
            else if index > post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        }
        
        for sub in subviews { sub.removeFromSuperview() } /// remove any old masks
        if currentAspect > 1.45 { addTop() }
    }
    
    func setCurrentImage() {
        let post = UploadPostModel.shared.postObject!
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        animationImages?.removeAll()
        
        let still = images[safe: frameIndexes[safe: index] ?? -1] ?? UIImage.init(color: UIColor(named: "SpotBlack")!, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        image = still
        stillImage = still
        
        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: index)
        self.animationImages = animationImages
        animationIndex = 0

        if !animationImages.isEmpty && !activeAnimation {
            animateGIF(directionUp: true, counter: animationIndex)
        }
    }
    
    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int], imageIndex: Int) -> [UIImage] {
        /// return empty set of images if there's only one image for this frame index (still image), return all images at this frame index if there's more than 1 image
        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }
        
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }
    
    func addTop() {
        let topMask = UIView {
            addSubview($0)
        }
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(100)
        }
        let _ = CAGradientLayer {
            $0.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100)
            $0.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.45).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 1.0)
            $0.endPoint = CGPoint(x: 0.5, y: 0.0)
            $0.locations = [0, 1]
            topMask.layer.addSublayer($0)
        }
    }
}

class PostDetailView: UIView {
    var bottomMask: UIView!
    override func layoutSubviews() {
        super.layoutSubviews()
        if bottomMask != nil { return }
        bottomMask = UIView {
            $0.isUserInteractionEnabled = false
            insertSubview($0, at: 0)
        }
        bottomMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let _ = CAGradientLayer {
            $0.frame = bounds
            $0.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.4).cgColor,
              UIColor(red: 0, green: 0.0, blue: 0.0, alpha: 0.65).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 0.5, 1]
            bottomMask.layer.addSublayer($0)
        }
    }
}

class PaddedNextButton: UIButton {
    var contentArea: UIView!
    var nextLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentArea = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 9
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        contentArea.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(5)
        }
                
        nextLabel = UILabel {
            $0.text = "Next"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            contentArea.addSubview($0)
        }
        nextLabel.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NewSpotNameView: UIView {
    var textView: UITextView!
    var spotIcon: UIImageView!
    var createButton: UIButton!
    
    var spotName: String {
        textView.text
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        textView = UITextView {
            $0.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 16.5)
            $0.tintColor = .white
            $0.textColor = UIColor.white
            $0.text = ""
            $0.textContainerInset = UIEdgeInsets(top: 9, left: 40, bottom: 9, right: 9)
            $0.textContainer.lineBreakMode = .byTruncatingHead
            $0.delegate = self
            $0.layer.cornerRadius = 13
            $0.returnKeyType = .done
            addSubview($0)
        }
        textView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.top.equalToSuperview()
            $0.height.equalTo(40)
        }
        
        spotIcon = UIImageView {
            $0.image = UIImage(named: "AddSpotIcon")
            textView.addSubview($0)
        }
        spotIcon.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(19.3)
            $0.height.equalTo(23)
        }
        
        createButton = UIButton {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 16
            $0.setTitle("Create spot", for: .normal)
            $0.setTitleColor(.black, for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
            $0.addTarget(self, action: #selector(createTap), for: .touchUpInside)
            addSubview($0)
        }
        createButton.snp.makeConstraints {
            $0.top.equalTo(textView.snp.bottom).offset(25)
            $0.width.equalTo(160)
            $0.height.equalTo(41)
            $0.centerX.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func createTap() {
        textView.endEditing(true)
    }
}

extension NewSpotNameView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.isUserInteractionEnabled = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.isUserInteractionEnabled = false
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" { textView.endEditing(true); return false }
        return text.count < 50
    }
}

class NewSpotMask: UIView {
    var bottomMask: UIView!
    override func layoutSubviews() {
        if bottomMask != nil { return }
        bottomMask = UIView {
            addSubview($0)
        }
        bottomMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let _ = CAGradientLayer {
            $0.frame = bounds
            $0.colors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor,
                UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.8).cgColor
            ]
            $0.startPoint = CGPoint(x: 0.5, y: 0.0)
            $0.endPoint = CGPoint(x: 0.5, y: 1.0)
            $0.locations = [0, 0.2, 1]
            bottomMask.layer.addSublayer($0)
        }
    }
}
