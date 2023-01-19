//
//  ImagePreviewController.swift
//  Spot
//
//  Created by kbarone on 2/27/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import IQKeyboardManagerSwift
import Mixpanel
import UIKit
import AVKit
import AVFoundation

final class ImagePreviewController: UIViewController {
    
    enum Mode: Hashable {
        case image
        case video(url: URL)
    }
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    lazy var currentImage = PostImagePreview(frame: .zero)
    lazy var nextImage = PostImagePreview(frame: .zero)
    lazy var previousImage = PostImagePreview(frame: .zero)

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "BackArrow"), for: .normal)
        button.addTarget(self, action: #selector(backTap(_:)), for: .touchUpInside)
        return button
    }()
    
    private lazy var dotView = UIView()

    private var nextButton: FooterNextButton?
    var postButton: UIButton?
    var progressMask: UIView?
    var progressBar: ProgressBar?

    private(set) lazy var postDetailView = PostDetailView()
    private(set) lazy var spotNameButton = SpotNameButton()
    
    private(set) lazy var atButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.setTitle("@", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-SemiboldItalic", size: 25)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 2.5, right: 0)
        button.layer.cornerRadius = 36 / 2
        button.addTarget(self, action: #selector(atTap), for: .touchUpInside)
        button.isHidden = true
        button.clipsToBounds = false
        return button
    }()
    
    private(set) lazy var newSpotNameView = NewSpotNameView()
    var newSpotMask: NewSpotMask?

    var cancelOnDismiss = false
    var newMapMode = false
    var cameraObject: ImageObject?

    // swipe down to close keyboard
    private(set) lazy var swipeToClose: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(swipeToClose(_:)))
        gesture.isEnabled = false
        return gesture
    }()
    
    // tap to close keyboard
    private(set) lazy var tapToClose: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(tapToClose(_:)))
        gesture.accessibilityValue = "tap_to_close"
        gesture.isEnabled = false
        return gesture
    }()
    
    private(set) lazy var tapCaption: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(captionTap))
        gesture.accessibilityValue = "caption_tap"
        return gesture
    }()

    private(set) lazy var textView: UITextView = {
        let view = UITextView()
        view.backgroundColor = nil
        view.textColor = .white
        view.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        view.alpha = 0.6
        view.tintColor = UIColor(named: "SpotGreen")
        view.text = textViewPlaceholder
        view.returnKeyType = .done
        view.textContainerInset = UIEdgeInsets(top: 10, left: 19, bottom: 14, right: 60)
        view.isScrollEnabled = false
        view.textContainer.maximumNumberOfLines = 6
        view.textContainer.lineBreakMode = .byTruncatingHead
        view.isUserInteractionEnabled = false
        return view
    }()

    private(set) lazy var tagFriendsView: TagFriendsView = {
        let view = TagFriendsView()
        view.delegate = self
        view.textColor = .white
        
        return view
    }()
    
    private var player: AVPlayer?
    
    var actionButton: UIButton {
        return newMapMode ? postButton ?? UIButton() : nextButton ?? UIButton()
    }
    
    var mode: Mode = .image // default
    let textViewPlaceholder = "Write a caption..."
    var shouldAnimateTextMask = false // tells keyboardWillChange whether to reposition
    var firstImageBottomConstraint: CGFloat = 0

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // set hidden for smooth transition
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ImagePreviewOpen")
        enableKeyboardMethods()
        
        if mode != .image {
            player?.play()
        }
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
        IQKeyboardManager.shared.enable = false // disable for textView sticking to keyboard
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
        var post = UploadPostModel.shared.postObject ?? MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        var imageLocations: [[String: Double]] = []
        if let cameraObject { UploadPostModel.shared.selectedObjects.append(cameraObject) }

        // cycle through selected imageObjects and find individual sets of images / frames
        for obj in UploadPostModel.shared.selectedObjects {
            let location = locationIsEmpty(location: obj.rawLocation) ? UserDataModel.shared.currentLocation : obj.rawLocation
            imageLocations.append(["lat": location.coordinate.latitude, "long": location.coordinate.longitude])

            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height / selectedImages[frameCounter].size.width)

            frameCounter += images.count
        }

        post.frameIndexes = frameIndexes
        post.aspectRatios = aspectRatios
        post.postImage = selectedImages
        post.imageLocations = imageLocations

        let imageLocation = UploadPostModel.shared.selectedObjects.first?.rawLocation ?? UserDataModel.shared.currentLocation
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
        guard let post = UploadPostModel.shared.postObject else { return }

        switch mode {
        case .image:
            addPreviewPhoto(post)
            
        case .video(let url):
            addPreviewVideo(path: url)
        }

        view.addSubview(backButton)
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
                $0.top.equalTo(backButton.snp.top).offset(2)
                $0.centerX.equalToSuperview()
            }

            postButton = PostButton {
                $0.addTarget(self, action: #selector(postTap), for: .touchUpInside)
                $0.backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)
                view.addSubview($0)
            }
            postButton?.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(18)
                $0.height.equalTo(51)
                $0.bottom.equalTo(-43)
            }

            progressMask = UIView {
                $0.backgroundColor = .black.withAlphaComponent(0.7)
                $0.isHidden = true
                view.addSubview($0)
            }
            progressMask?.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }

            progressBar = ProgressBar {
                progressMask?.addSubview($0)
            }
            progressBar?.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(50)
                if let postButton { $0.bottom.equalTo(postButton.snp.top).offset(-20) }
                $0.height.equalTo(18)
            }

        } else {
            nextButton = FooterNextButton {
                $0.addTarget(self, action: #selector(chooseMapTap), for: .touchUpInside)
                $0.isEnabled = true
                view.addSubview($0)
            }
            nextButton?.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(15)
                $0.bottom.equalToSuperview().inset(50)
                $0.width.equalTo(94)
                $0.height.equalTo(40)
            }
        }

        view.addGestureRecognizer(swipeToClose)
        tapToClose.delegate = self
        view.addGestureRecognizer(tapToClose)
        tapCaption.delegate = self
        view.addGestureRecognizer(tapCaption)
    }
    
    private func addPreviewPhoto(_ post: MapPost) {
        // add initial preview view and buttons
        currentImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex ?? 0)
        view.addSubview(currentImage)
        currentImage.makeConstraints()
        currentImage.setCurrentImage()

        if post.frameIndexes?.count ?? 0 > 1 {
            nextImage = PostImagePreview(frame: .zero, index: (post.selectedImageIndex ?? 0) + 1)
            view.addSubview(nextImage)
            nextImage.makeConstraints()
            nextImage.setCurrentImage()

            previousImage = PostImagePreview(frame: .zero, index: (post.selectedImageIndex ?? 0) - 1)
            view.addSubview(previousImage)
            previousImage.makeConstraints()
            previousImage.setCurrentImage()

            let pan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            view.addGestureRecognizer(pan)
            addDotView()
        }
    }
    
    private func addPreviewVideo(path: URL) {
        player = AVPlayer(url: path)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
    }

    func addDotView() {
        let imageCount = UploadPostModel.shared.postObject?.frameIndexes?.count ?? 0
        let dotWidth = (9 * imageCount) + (5 * (imageCount - 1))
        view.addSubview(dotView)
        dotView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(73)
            $0.height.equalTo(9)
            $0.width.equalTo(dotWidth)
            $0.centerX.equalToSuperview()
        }
        addDots()
    }

    func addDots() {
        for sub in dotView.subviews { sub.removeFromSuperview() }
        for i in 0..<(UploadPostModel.shared.postObject?.frameIndexes?.count ?? 0) {
            let dot = UIView {
                $0.layer.borderColor = UIColor.white.cgColor
                $0.layer.borderWidth = 1
                $0.backgroundColor = i == UploadPostModel.shared.postObject?.selectedImageIndex ?? 0 ? .white : .clear
                $0.layer.cornerRadius = 9 / 2
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
        view.addSubview(postDetailView)
        postDetailView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(160)
            $0.bottom.equalToSuperview().offset(-105) // hard code bc done button and next button not perfectly aligned
        }

        textView.delegate = self
        postDetailView.addSubview(textView)
        textView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.lessThanOrEqualToSuperview().inset(36)
            $0.bottom.equalToSuperview().offset(-3)
        }

        postDetailView.addSubview(atButton)
        atButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(textView.snp.top).offset(-4)
            $0.height.width.equalTo(36)
        }

        spotNameButton.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
        postDetailView.addSubview(spotNameButton)
        spotNameButton.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.bottom.equalTo(textView.snp.top)
            $0.height.equalTo(36)
            $0.trailing.lessThanOrEqualToSuperview().inset(16)
        }

        newSpotNameView.isHidden = true
        view.addSubview(newSpotNameView)
        newSpotNameView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(UIScreen.main.bounds.height / 2) // position around center of screen for smooth animation
            $0.height.equalTo(110)
        }

        if UserDataModel.shared.screenSize == 0 && (UploadPostModel.shared.postObject?.postImage.contains(where: { $0.aspectRatio() > 1.45 }) ?? false) {
            addExtraMask()
        }
    }
    
    private func locationIsEmpty(location: CLLocation) -> Bool {
        return location.coordinate.longitude == 0.0 && location.coordinate.latitude == 0.0
    }
}
