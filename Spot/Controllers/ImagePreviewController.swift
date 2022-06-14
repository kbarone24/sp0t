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

protocol ImagePreviewDelegate {
    func finishPassingFromCamera(images: [UIImage])
}

class ImagePreviewController: UIViewController {
    
    var spotObject: MapSpot!
    var delegate: ImagePreviewDelegate?
                
    var previewView: PostImageView!
    var previewBackground: UIView! /// tracks where detail view will be added
    var previewButton: UIButton! /// covers entire area where caption tap will open keyboard
    
    var draftsButton: UIButton!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
    /// detailView
    var postDetailView: UIView!
    var spotNameView: UIView!
    var addedUsersView: UIView!
    
    var cancelOnDismiss = false
    var cameraObject: ImageObject!
    
    var panGesture: UIPanGestureRecognizer! /// swipe down to close keyboard
    
    var textView: UITextView!
    var shouldRepositionTextView = false /// keyboardWillShow firing late -> this variable tells keyboardWillChange whether to reposition
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cancelOnDismiss = false
        /// set hidden for smooth transition
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CameraPreviewOpen")
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(postInfoUpdate(_:)), name: NSNotification.Name("PostInfoUpdate"), object: nil)
        /// set up nav bar officially here for smooth transition when stacking
        setUpNavBar()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelOnDismiss = true
        IQKeyboardManager.shared.enable = true
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setPostInfo()
        addPreviewView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    func setUpNavBar() {
                
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
        
        navigationItem.hidesBackButton = true
    }
    
    func setPostInfo() {
        
        var post = UploadPostModel.shared.postObject!
        
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.append(cameraObject) }
        
        /// cycle through selected imageObjects and find individual sets of images / frames
        for obj in UploadPostModel.shared.selectedObjects {
            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height/selectedImages[frameCounter].size.width)
            
            frameCounter += images.count
        }
        
        post.frameIndexes = frameIndexes
        post.aspectRatios = aspectRatios
        post.postImage = selectedImages
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.9
        post.imageHeight = getImageHeight(aspectRatios: post.aspectRatios ?? [], maxAspect: cameraAspect)
        
        let imageLocation = UploadPostModel.shared.selectedObjects.first?.rawLocation ?? UserDataModel.shared.currentLocation ?? CLLocation()
        if !locationIsEmpty(location: imageLocation) {
            post.postLat = imageLocation.coordinate.latitude
            post.postLong = imageLocation.coordinate.longitude
        }
        
        UploadPostModel.shared.postObject = post
    }
    
    func addPreviewView() {
        /// add initial preview view and buttons

        let post = UploadPostModel.shared.postObject!
        
        /// camera aspect is also the max aspect for any image
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + cameraHeight
        
        let imageAspect = post.imageHeight / UIScreen.main.bounds.width
        let imageY: CGFloat = imageAspect >= cameraAspect ? minY : (minY + maxY - post.imageHeight)/2
        
        previewView = PostImageView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: post.imageHeight))
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.isUserInteractionEnabled = true
        previewView.layer.cornerRadius = 15
        previewView.backgroundColor = nil
        
        previewBackground = UIView(frame: previewView.frame)
        previewBackground.backgroundColor = UIColor(named: "SpotBlack")
        previewBackground.layer.cornerRadius = 15
        view.addSubview(previewBackground)
        
        view.addSubview(previewView)
        setCurrentImage()
        
        /// add button view
        let buttonView = UIView(frame: CGRect(x: UIScreen.main.bounds.width - 76, y: minY + 39, width: 64, height: 204))
        
        /// stretch background view for landscape image so detail view appears at bottom of screen
        if imageAspect < 1.1 {
            /// move preview view beneath edit buttons
            previewView.frame = CGRect(x: 0, y: buttonView.frame.maxY + 10, width: UIScreen.main.bounds.width, height: previewView.frame.height)
            previewBackground.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight)
            
        } else {
            addImageMasks(minY: minY, imageY: imageY)
        }
        
        previewButton = UIButton(frame: previewBackground.frame) /// previewButton receives all events on image area
        previewButton.addTarget(self, action: #selector(captionTap(_:)), for: .touchUpInside)
        view.addSubview(previewButton)
        
        view.addSubview(buttonView)
                
        /// add cancel button
        let cancelButton = UIButton(frame: CGRect(x: 4, y: minY + 37, width: 50, height: 50))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cancelButton.contentHorizontalAlignment = .fill
        cancelButton.contentVerticalAlignment = .fill
        cancelButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        view.addSubview(cancelButton)

        let spotButton = UIButton(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        spotButton.setImage(UIImage(named: "CameraSpotButton"), for: .normal)
        spotButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        spotButton.addTarget(self, action: #selector(spotTap(_:)), for: .touchUpInside)
        buttonView.addSubview(spotButton)
                
        let friendButton = UIButton(frame: CGRect(x: 0, y: spotButton.frame.maxY + 6, width: 64, height: 64))
        friendButton.setImage(UIImage(named: "CameraFriendButton"), for: .normal)
        friendButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        friendButton.addTarget(self, action: #selector(friendTap(_:)), for: .touchUpInside)
        buttonView.addSubview(friendButton)
        
        let tagButton = UIButton(frame: CGRect(x: 0, y: friendButton.frame.maxY + 6, width: 64, height: 64))
        tagButton.setImage(UIImage(named: "CameraTagButton"), for: .normal)
        tagButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        tagButton.addTarget(self, action: #selector(tagTap(_:)), for: .touchUpInside)
        buttonView.addSubview(tagButton)
                
        /// add share to and drafts
        let shareToButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 148, y: maxY + 6, width: 140, height: 54))
        shareToButton.setImage(UIImage(named: "CameraShareButton"), for: .normal)
        shareToButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        shareToButton.addTarget(self, action: #selector(shareTap(_:)), for: .touchUpInside)
        view.addSubview(shareToButton)
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.isEnabled = false
        view.addGestureRecognizer(panGesture)
        
        addCaption()
        addPostDetail()
    }
    
    func setCurrentImage() {
        
        let post = UploadPostModel.shared.postObject!
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        guard let still = images[safe: frameIndexes[post.selectedImageIndex]] else { return }
        
        /// scale aspect fit for landscape image, stretch to fill iPhone vertical + image taken from sp0t camera
        let imageAspect = still.size.height / still.size.width
        previewView.contentMode = (imageAspect + 0.01 < (post.imageHeight / UIScreen.main.bounds.width)) && imageAspect < 1.1  ? .scaleAspectFit : .scaleAspectFill
        if previewView.contentMode == .scaleAspectFit { previewView.roundCornersForAspectFit(radius: 15) }
        
        previewView.image = still
        previewView.stillImage = still
        
        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex)
        previewView.animationImages = animationImages
        previewView.animationIndex = 0

        if !animationImages.isEmpty && !previewView.activeAnimation {
            previewView.animateGIF(directionUp: true, counter: previewView.animationIndex, alive: post.gif ?? false)
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
    
    func addPostDetail() {
        
        if postDetailView == nil {
            postDetailView = UIView(frame: CGRect(x: 0, y: previewBackground.bounds.maxY - 65, width: UIScreen.main.bounds.width, height: 65))
            previewButton.addSubview(postDetailView)
        }
        
        if !(UploadPostModel.shared.postObject.addedUsers?.isEmpty ?? true) { addAddedUsersView() } /// add added users first to determine available space for spotNameView
        if UploadPostModel.shared.spotObject != nil { addSpotNameView() }
        
        /// move caption up if added users or spot buttons are present
        var minY: CGFloat = previewBackground.frame.maxY - 75
        if !(UploadPostModel.shared.postObject.addedUsers?.isEmpty ?? true) || UploadPostModel.shared.spotObject != nil {
            minY -= 55
        }
        
        textView.frame = CGRect(x: textView.frame.minX, y: minY, width: textView.frame.width, height: textView.frame.height)
    }
    
    func addAddedUsersView() {
        
        if addedUsersView != nil { addedUsersView.removeFromSuperview(); addedUsersView = nil }
        addedUsersView = UIView(frame: CGRect(x: 14, y: 0, width: 63, height: 41))
        addedUsersView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        addedUsersView.layer.cornerRadius = 16
        addedUsersView.layer.cornerCurve = .continuous
        postDetailView.addSubview(addedUsersView)
        
        let usersTap = UITapGestureRecognizer(target: self, action: #selector(addedUsersTap(_:)))
        addedUsersView.addGestureRecognizer(usersTap)
        
        let userIcon = UIImageView(frame: CGRect(x: 13, y: 11, width: 20.4, height: 19.35))
        userIcon.image = UIImage(named: "SingleUserIcon")
        addedUsersView.addSubview(userIcon)
        
        let countLabel = UILabel(frame: CGRect(x: userIcon.frame.maxX + 5, y: userIcon.frame.minY + 2, width: 30, height: 16))
        countLabel.text = "\(UploadPostModel.shared.postObject.addedUsers!.count)"
        countLabel.textColor = .white
        countLabel.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
        addedUsersView.addSubview(countLabel)
    }
    
    func addSpotNameView() {
        
        let post = UploadPostModel.shared.postObject!
        
        if spotNameView != nil { spotNameView.removeFromSuperview(); spotNameView = nil }
        spotNameView = UIView(frame: CGRect(x: 14, y: 0, width: 300, height: 41))
        spotNameView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        spotNameView.layer.cornerRadius = 16
        spotNameView.layer.cornerCurve = .continuous
        postDetailView.addSubview(spotNameView)
        
        let tagImage = post.tag ?? "" == "" ? UIImage(named: "LocationIcon") : Tag(name: post.tag!).image
        
        let tagIcon = UIImageView(frame: CGRect(x: 11.5, y: 9.5, width: 17.6, height: 21.5))
        tagIcon.image = tagImage
        spotNameView.addSubview(tagIcon)
        
        let nameLabel = UILabel(frame: CGRect(x: tagIcon.frame.maxX + 7, y: tagIcon.frame.minY + 2, width: UIScreen.main.bounds.width, height: 16))
        nameLabel.text = UploadPostModel.shared.spotObject.spotName
        nameLabel.textColor = .white
        nameLabel.font = UIFont(name: "SFCompactText-Bold", size: 17)
        nameLabel.lineBreakMode = .byTruncatingTail
        spotNameView.addSubview(nameLabel)
        
        /// make sure long spotName fits + resize view
        var maxWidth = UIScreen.main.bounds.width - 28 - 47.5 /// screen width - margins - rest of space occupying spotNameView
        if addedUsersView != nil { maxWidth -= (14 + addedUsersView.bounds.width) }
        
        nameLabel.sizeToFit()
        if nameLabel.bounds.width > maxWidth { nameLabel.frame = CGRect(x: nameLabel.frame.minX, y: nameLabel.frame.minY, width: maxWidth, height: nameLabel.frame.height) }
        spotNameView.frame = CGRect(x: spotNameView.frame.minX, y: spotNameView.frame.minY, width: nameLabel.bounds.width + 47.5, height: spotNameView.frame.height)
        if addedUsersView != nil { addedUsersView.frame = CGRect(x: spotNameView.frame.maxX + 14, y: addedUsersView.frame.minY, width: addedUsersView.frame.width, height: addedUsersView.frame.height) }
        
        let spotTap = UITapGestureRecognizer(target: self, action: #selector(spotNameTap(_:)))
        spotNameView.addGestureRecognizer(spotTap)
    }
    
    func addCaption() {
                
        /// textview frame set on addPostDetail
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 51))
        textView.delegate = self
        textView.font = UIFont(name: "SFCompactText-Regular", size: 19)
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.tintColor = UIColor(named: "SpotGreen")
        textView.text = ""
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.isUserInteractionEnabled = false
       // textView.keyboardDistanceFromTextField = 20
        view.addSubview(textView)
        
    }
        
    
    func addImageMasks(minY: CGFloat, imageY: CGFloat) {
        /// add top mask if image overlaps with buttons
        /// end of buttons at minY + 243
        let maskHeight: CGFloat = (minY + 243) - imageY
        let topMask = UIView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: maskHeight))
        
        let topLayer = CAGradientLayer()
        topLayer.frame = topMask.bounds
        topLayer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0, alpha: 0.45).cgColor
        ]
        topLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        topLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        topLayer.locations = [0, 1]
        
        topMask.layer.addSublayer(topLayer)
        view.addSubview(topMask)
        
        let bottomMask = UIView(frame: CGRect(x: 0, y: previewBackground.frame.maxY - maskHeight, width: UIScreen.main.bounds.width, height: maskHeight))
        let bottomLayer = CAGradientLayer()
        bottomLayer.frame = topMask.bounds
        bottomLayer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0, alpha: 0.45).cgColor
        ]
        bottomLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomLayer.locations = [0, 1]
        
        bottomMask.layer.addSublayer(bottomLayer)
        view.addSubview(bottomMask)
    }
    
    @objc func postInfoUpdate(_ sender: NSNotification) {
        /// passback from PostInfoController
        DispatchQueue.main.async { self.addPostDetail() }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        if cameraObject != nil { UploadPostModel.shared.selectedObjects.removeAll(where: {$0.fromCamera})} /// remove old captured image
        
        let controllers = navigationController?.viewControllers
        if let camera = controllers?[safe: (controllers?.count ?? 0) - 2] as? AVCameraController {
            
            /// reset detail view
            UploadPostModel.shared.selectedTag = ""
            
            /// set spotObject to nil if we're not posting directly to the spot from the spot page
            if camera.spotObject == nil { UploadPostModel.shared.spotObject = nil }

            /// reset postObject
            camera.setUpPost()
        }
        
        navigationController?.popViewController(animated: false)
    }
    
    @objc func tagTap(_ sender: UIButton) {
        launchPicker(index: 2)
    }
    
    @objc func friendTap(_ sender: UIButton) {
        launchPicker(index: 1)
    }
    
    @objc func spotTap(_ sender: UIButton) {
        launchPicker(index: 0)
    }
    
    @objc func spotNameTap(_ sender: UITapGestureRecognizer) {
        launchPicker(index: 0)
    }
    
    @objc func addedUsersTap(_ sender: UITapGestureRecognizer) {
        launchPicker(index: 1)
    }
    
    @objc func captionTap(_ sender: UIButton) {
        shouldRepositionTextView = true
        textView.becomeFirstResponder()
    }
    
    @objc func shareTap(_ sender: UIButton) {
        
        
        UploadPostModel.shared.postObject.caption = textView.text ?? ""
        
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ShareTo") as? ShareToController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func launchPicker(index: Int) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "PostInfo") as? PostInfoController {
            vc.selectedSegmentIndex = index
            DispatchQueue.main.async { self.present(vc, animated: true) }
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        shouldRepositionTextView = false
    }
    
    @objc func keyboardWillChange(_ notification: NSNotification) {
        
        if !shouldRepositionTextView { return }
        
        let userInfo = notification.userInfo!
        
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let keyboardY = keyboardEndFrame.minY - textView.bounds.height
        
        /// reposition caption -> adjust if spot or user buttons present
        var textViewY: CGFloat = previewBackground.frame.maxY - 24 - textView.bounds.height
        if !(UploadPostModel.shared.postObject.addedUsers?.isEmpty ?? true) || UploadPostModel.shared.spotObject != nil {
            textViewY -= 55
        }
        
        let minY = min(keyboardY, textViewY)
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: animationDuration) { () -> Void in
                self.textView.frame = CGRect(x: self.textView.frame.minX, y: minY, width: self.textView.frame.width, height: self.textView.frame.height)
            }
        }
    }
}

extension ImagePreviewController: UITextViewDelegate, UIGestureRecognizerDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        panGesture.isEnabled = true
        previewButton.isEnabled = false
        
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        panGesture.isEnabled = false
        
        /// hacky fix to make caption not jump up on resize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.previewButton.isEnabled = true
        }
        
        textView.backgroundColor = .clear
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * maxLines + 30 /// lineheight * # lines  + textContainer insets
        
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)

        let val = getCaptionHeight(text: updatedText) <= maxHeight
        return val
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
        let maxLines: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * maxLines + 28
        
        let size = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.width, height: maxHeight))
        if size.height != textView.frame.height {
            let diff = size.height - textView.frame.height
            /// expand textview and slide it up to move away from the keyboard
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY - diff, width: textView.frame.width, height: textView.frame.height + diff)
        }
        ///add tag table if @ used
        let cursor = textView.getCursorPosition()
     //   addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .comments)
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
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        
        if !self.textView.isFirstResponder { return }
        
        let direction = sender.velocity(in: view)
        
        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            panGesture.isEnabled = false
        }
    }
}
