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

class ImagePreviewController: UIViewController {
    
    var spotObject: MapSpot!
                
    var currentImage: PostImagePreview!
    var nextImage: PostImagePreview!
    var previousImage: PostImagePreview!
    var previewBackground: UIView! /// tracks where detail view will be added
    var previewButton: UIButton! /// covers entire area where caption tap will open keyboard
    
    var backButton: UIButton!
    var dotView: UIView!
    var shareToButton: UIButton!
    var draftsButton: UIButton!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
    /// detailView
    var postDetailView: UIView!
    var spotNameView: SpotNameView!
    var addedUsersView: AddedUsersView!
    
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
   //     NotificationCenter.default.addObserver(self, selector: #selector(postInfoUpdate(_:)), name: NSNotification.Name("PostInfoUpdate"), object: nil)
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
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.9
        post.imageHeight = getImageHeight(aspectRatios: post.aspectRatios ?? [], maxAspect: cameraAspect)
        
        let imageLocation = UploadPostModel.shared.selectedObjects.first?.rawLocation ?? UserDataModel.shared.currentLocation ?? CLLocation()
        if !locationIsEmpty(location: imageLocation) {
            post.postLat = imageLocation.coordinate.latitude
            post.postLong = imageLocation.coordinate.longitude
            UploadPostModel.shared.setPostCity()
        }
        
        UploadPostModel.shared.postObject = post
    }
    
    func addPreviewView() {
        /// add initial preview view and buttons

        let post = UploadPostModel.shared.postObject!
        
        /// camera aspect is also the max aspect for any image'
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + cameraHeight
                
        previewBackground = UIView {
            $0.backgroundColor = UIColor(named: "SpotBlack")
            $0.layer.cornerRadius = 15
            view.addSubview($0)
        }
        previewBackground.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }
                
        currentImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex!)
        view.addSubview(currentImage)
        currentImage.makeConstraints()
        currentImage.setCurrentImage()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
        view.addGestureRecognizer(pan)
     //   previewBackground.addGestureRecognizer(pan)
        
        if post.frameIndexes!.count > 1 {
            nextImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! + 1)
            view.addSubview(nextImage)
            nextImage.makeConstraints()
            nextImage.setCurrentImage()
            
            previousImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex! - 1)
            view.addSubview(previousImage)
            previousImage.makeConstraints()
            previousImage.setCurrentImage()
            
            addDotView()
        }
          /*
        previewButton = UIButton {
            $0.addTarget(self, action: #selector(captionTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        previewButton.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        } */
                                
        /// add cancel button
        backButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "BackArrow"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        backButton.snp.makeConstraints {
            $0.leading.equalTo(5.5)
            $0.top.equalTo(previewBackground.snp.top).offset(56)
            $0.width.equalTo(48.6)
            $0.height.equalTo(38.6)
        }
                
        /// add share to and drafts
        shareToButton = UIButton {
            $0.setImage(UIImage(named: "CameraShareButton"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(shareTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        shareToButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(8)
            $0.top.equalTo(maxY + 6)
            $0.width.equalTo(140)
            $0.height.equalTo(54)
        }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.isEnabled = false
        view.addGestureRecognizer(panGesture)
        
         addCaption()
       // addPostDetail()
    }
        
    func addDotView() {
        let imageCount = UploadPostModel.shared.postObject.frameIndexes!.count
        let dotWidth = (14 * imageCount) + (10 * (imageCount - 1))
        dotView = UIView {
            $0.backgroundColor = nil
            view.addSubview($0)
        }
        dotView.snp.makeConstraints {
            $0.top.equalTo(previewBackground.snp.top).offset(72)
            $0.height.equalTo(14)
            $0.width.equalTo(dotWidth)
            $0.centerX.equalToSuperview()
        }
        addDots()
    }
    
    func addDots() {
        if dotView != nil { for sub in dotView.subviews { sub.removeFromSuperview() } }
        for i in 0...UploadPostModel.shared.postObject.frameIndexes!.count - 1 {
            let dot = UIView {
                $0.backgroundColor = .white
                $0.alpha = i == UploadPostModel.shared.postObject.selectedImageIndex! ? 1.0 : 0.35
                $0.layer.cornerRadius = 7
                dotView.addSubview($0)
            }
            let leading = i * 24
            dot.snp.makeConstraints {
                $0.leading.equalTo(leading)
                $0.top.equalToSuperview()
                $0.width.height.equalTo(14)
            }
        }
    }
    /*
    func addPostDetail() {
        
        if postDetailView == nil {
            postDetailView = UIView()
            previewButton.addSubview(postDetailView)
            postDetailView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(previewBackground.snp.bottom)
                $0.height.equalTo(65)
            }
        }
        
        if !(UploadPostModel.shared.postObject.addedUsers?.isEmpty ?? true) { addAddedUsersView() } /// add added users first to determine available space for spotNameView
        if UploadPostModel.shared.spotObject != nil { addSpotNameView() }
        
        /// move caption up if added users or spot buttons are present
        var minY: CGFloat = previewBackground.frame.maxY - 75
        if !(UploadPostModel.shared.postObject.addedUsers?.isEmpty ?? true) || UploadPostModel.shared.spotObject != nil {
            minY -= 55
        }
    }
    
    func addAddedUsersView() {
        addedUsersView = AddedUsersView(frame: CGRect(x: 14, y: 0, width: 63, height: 41))
        postDetailView.addSubview(addedUsersView)
        
        let usersTap = UITapGestureRecognizer(target: self, action: #selector(addedUsersTap(_:)))
        addedUsersView.addGestureRecognizer(usersTap)
    }
    
    func addSpotNameView() {
        let post = UploadPostModel.shared.postObject!
        
        spotNameView = SpotNameView(frame: CGRect(x: 14, y: 0, width: 300, height: 41), tag: post.tag ?? "")
        postDetailView.addSubview(spotNameView)
                
        let spotTap = UITapGestureRecognizer(target: self, action: #selector(spotNameTap(_:)))
        spotNameView.addGestureRecognizer(spotTap)
        
        /// make sure long spotName fits + resize view
        var maxWidth = UIScreen.main.bounds.width - 28 - 47.5 /// screen width - margins - rest of space occupying spotNameView
        if addedUsersView != nil { maxWidth -= (14 + addedUsersView.bounds.width) }
        
        spotNameView.nameLabel.sizeToFit()
        if spotNameView.nameLabel.bounds.width > maxWidth { spotNameView.nameLabel.frame = CGRect(x: spotNameView.nameLabel.frame.minX, y: spotNameView.nameLabel.frame.minY, width: maxWidth, height: spotNameView.nameLabel.frame.height) }
        spotNameView.frame = CGRect(x: spotNameView.frame.minX, y: spotNameView.frame.minY, width: spotNameView.nameLabel.bounds.width + 47.5, height: spotNameView.frame.height)
        if addedUsersView != nil { addedUsersView.frame = CGRect(x: spotNameView.frame.maxX + 14, y: addedUsersView.frame.minY, width: addedUsersView.frame.width, height: addedUsersView.frame.height) }
    }
    
     @objc func postInfoUpdate(_ sender: NSNotification) {
         /// passback from PostInfoController
         DispatchQueue.main.async { self.addPostDetail() }
     }
*/
    func addCaption() {
        /// textview frame set on addPostDetail
        textView = UITextView {
            $0.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 51)
            $0.delegate = self
            $0.font = UIFont(name: "SFCompactText-Regular", size: 19)
            $0.backgroundColor = .clear
            $0.textColor = .white
            $0.tintColor = UIColor(named: "SpotGreen")
            $0.text = ""
            $0.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
            $0.isScrollEnabled = false
            $0.textContainer.maximumNumberOfLines = 6
            $0.textContainer.lineBreakMode = .byTruncatingHead
            $0.isUserInteractionEnabled = false
           // textView.keyboardDistanceFromTextField = 20
            view.addSubview($0)
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
        
    @objc func captionTap(_ sender: UIButton) {
        shouldRepositionTextView = true
        textView.becomeFirstResponder()
    }
    
    @objc func shareTap(_ sender: UIButton) {
        launchPicker()
        /*
        UploadPostModel.shared.postObject.caption = textView.text ?? ""
        
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ShareTo") as? ShareToController {
            navigationController?.pushViewController(vc, animated: true)
        } */
    }
    
    func launchPicker() {
        if let vc = storyboard?.instantiateViewController(withIdentifier: "ChooseSpot") as? ChooseSpotController {
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

class AddedUsersView: UIView {
    
    var userIcon: UIImageView!
    var countLabel: UILabel!
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        
        /// remove tapGesture if previously added
        if let tap = gestureRecognizers?.first(where: {$0.isKind(of: UITapGestureRecognizer.self)}) { removeGestureRecognizer(tap) }
        
        if userIcon != nil { userIcon.image = UIImage() }
        userIcon = UIImageView {
            $0.frame = CGRect(x: 13, y: 11, width: 20.4, height: 19.35)
            $0.image = UIImage(named: "SingleUserIcon")
            addSubview($0)
        }
        
        if countLabel != nil { countLabel.text = "" }
        countLabel = UILabel {
            $0.frame = CGRect(x: userIcon.frame.maxX + 5, y: userIcon.frame.minY + 2, width: 30, height: 16)
            $0.text = "\(UploadPostModel.shared.postObject.addedUsers!.count)"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
            addSubview($0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpotNameView: UIView {
    
    var tagIcon: UIImageView!
    var nameLabel: UILabel!

    init(frame: CGRect, tag: String) {
        
        super.init(frame: frame)
        
        backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
            
        let tagImage = tag == "" ? UIImage(named: "LocationIcon") : Tag(name: tag).image
        
        tagIcon = UIImageView {
            $0.frame = CGRect(x: 11.5, y: 9.5, width: 17.6, height: 21.5)
            $0.image = tagImage
            addSubview($0)
        }
        
        nameLabel = UILabel {
            $0.frame = CGRect(x: tagIcon.frame.maxX + 7, y: tagIcon.frame.minY + 2, width: UIScreen.main.bounds.width, height: 16)
            $0.text = UploadPostModel.shared.spotObject?.spotName ?? ""
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Bold", size: 17)
            $0.lineBreakMode = .byTruncatingTail
            addSubview($0)
        }
        
        /// remove tapGesture if previously added
        if let tap = gestureRecognizers?.first(where: {$0.isKind(of: UITapGestureRecognizer.self)}) { removeGestureRecognizer(tap) }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        layer.cornerRadius = 15
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
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let post = UploadPostModel.shared.postObject!
        let currentImage = post.postImage[safe: post.frameIndexes?[safe: index] ?? -1] ?? UIImage(color: .black, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        let currentAspect = (currentImage.size.height) / (currentImage.size.width)
        let currentHeight = getImageHeight(aspectRatio: currentAspect, maxAspect: cameraAspect)
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + cameraHeight
        
        let imageY: CGFloat = currentAspect + 0.02 >= cameraAspect ? minY : (minY + maxY - currentHeight)/2 + 15
        
        snp.makeConstraints {
            $0.height.equalTo(currentHeight)
            $0.top.equalTo(imageY)
            if index == post.selectedImageIndex { $0.leading.trailing.equalToSuperview() }
            else if index < post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width) }
            else if index > post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        }
        
        for sub in subviews { sub.removeFromSuperview() } /// remove any old masks
       // if currentAspect > 1.1 { addImageMasks() }
    }
    
    func setCurrentImage() {
        let post = UploadPostModel.shared.postObject!
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        let still = images[safe: frameIndexes[safe: index] ?? -1] ?? UIImage.init(color: UIColor(named: "SpotBlack")!, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width))!
        image = still
        stillImage = still
        
        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex!)
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

    func addImageMasks() {
        let topMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 200))
        
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
        addSubview(topMask)
        
        let bottomMask = UIView(frame: CGRect(x: 0, y: bounds.height - 200, width: UIScreen.main.bounds.width, height: 200))
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
        addSubview(bottomMask)
    }
    
    func getImageHeight(aspectRatio: CGFloat, maxAspect: CGFloat) -> CGFloat {
      
        var imageAspect =  min(aspectRatio, maxAspect)
        if imageAspect > 1.1 && imageAspect < 1.6 { imageAspect = 1.6 } /// stretch iPhone vertical
        if imageAspect > 1.6 { imageAspect = maxAspect } /// round to max aspect
        
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }
}
