//
//  CameraViewController.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import NextLevel
import AVFoundation
import UIKit
import JPSVolumeButtonHandler
import Mixpanel
import Photos

final class CameraViewController: UIViewController {
    // called when it shouldnt be
    /*
    private(set) lazy var volumeHandler: JPSVolumeButtonHandler? = {
        let handler = JPSVolumeButtonHandler(
            up: { [weak self] in
                print("volume button capture")
                self?.capturePhoto()
            },
            downBlock: { [weak self] in
                print("volume button capture")
                self?.capturePhoto()
            }
        )
        return handler
    }()
    */
    private(set) lazy var cameraView: UIView = {
        let bottomInset: CGFloat = UserDataModel.shared.screenSize == 0 ? 0 : 105
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - bottomInset))
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = UIColor.black
        NextLevel.shared.previewLayer.frame = view.bounds
        view.layer.cornerRadius = 5
        view.backgroundColor = UIColor(named: "SpotBlack")
        view.layer.addSublayer(NextLevel.shared.previewLayer)
        return view
    }()

    private(set) lazy var cameraButton: CameraButton = {
        let button = CameraButton()

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGestureRecognizer(_:)))
        longPressGesture.delegate = self
        longPressGesture.numberOfTouchesRequired = 1
        longPressGesture.minimumPressDuration = 0.0
        longPressGesture.allowableMovement = 50.0

        button.addGestureRecognizer(longPressGesture)
        return button
    }()
    
    private(set) lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        
        progress.progressTintColor = UIColor(hexString: "39F3FF")
        progress.trackTintColor = UIColor(hexString: "39F3FF").withAlphaComponent(0.2)
        progress.setProgress(0.0, animated: false)
        progress.layer.cornerRadius = 4
        progress.layer.masksToBounds = true
        return progress
    }()
    
    private(set) lazy var galleryButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "PhotoGalleryButton"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(galleryTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var flashButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "FlashOff"), for: .normal)
        button.addTarget(self, action: #selector(switchFlash), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var cancelButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CameraCancelButton"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var backButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "BackArrow"), for: .normal)
        button.addTarget(self, action: #selector(backTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var cameraRotateButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CameraRotate"), for: .normal)
        button.addTarget(self, action: #selector(cameraRotateTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var instructionsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hexString: "35E0EC")
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.text = "Press & hold to shoot video"
        return label
    }()

    lazy var nextButton: UIButton = {
        let button = UIButton()
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.backgroundColor = UIColor(named: "SpotGreen")
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(nextTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var failedPostView = FailedPostView(frame: .zero)
    
    var cameraHeight: CGFloat {
        UserDataModel.shared.maxAspect * UIScreen.main.bounds.width
    }
    
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    /// white screen for use with front flash
    private(set) lazy var frontFlashView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        return view
    }()
    
    private var askedForCamera = false
    internal var gifMode = false
    internal var cancelOnDismiss = false
    internal var newMapMode = false
    
    internal var _panStartPoint: CGPoint = .zero
    internal var _panStartZoom: CGFloat = 0.0
    
    internal var mapObject: CustomMap?
    internal var postDraft: PostDraft?
    let maxVideoDuration = CMTimeMake(value: 7, timescale: 1)

    var videoPressStartTime: TimeInterval?
    var progressViewCachedPosition: Float?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        view.addSubview(cameraView)
        setUpView()
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        NextLevel.shared.delegate = self
        NextLevel.shared.deviceDelegate = self
        NextLevel.shared.videoDelegate = self
        NextLevel.shared.photoDelegate = self
        NextLevel.shared.flashDelegate = self

        NextLevel.shared.videoConfiguration.maximumCaptureDuration = maxVideoDuration
        NextLevel.shared.audioConfiguration.bitRate = 44_000

        NotificationCenter.default.addObserver(self, selector: #selector(photoGalleryRemove), name: Notification.Name(rawValue: "PhotoGalleryRemove"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(imagePreviewRemove), name: Notification.Name(rawValue: "ImagePreviewRemove"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)

        if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
            NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
            do {
                try NextLevel.shared.start()
            } catch {
                DispatchQueue.main.async {
                    if self.newMapMode {
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        self.popToMap()
                    }
                }
            }
            
        } else {
            NextLevel.requestAuthorization(forMediaType: AVMediaType.video) { [weak self] _, status in
                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
                    NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
                    do {
                        let nextLevel = NextLevel.shared
                        try nextLevel.start()
                    } catch {
                        DispatchQueue.main.async {
                            if self?.newMapMode ?? false {
                                self?.navigationController?.popViewController(animated: true)
                            } else {
                                self?.popToMap()
                            }
                        }
                    }
                } else if status == .notAuthorized {
                    self?.showSettingsAlert(title: "Allow camera access in Settings to post on sp0t", message: nil, location: false)
                }
            }
            
            NextLevel.requestAuthorization(forMediaType: AVMediaType.audio) { [weak self] _, status in
                
                if NextLevel.authorizationStatus(forMediaType: AVMediaType.video) == .authorized &&
                    NextLevel.authorizationStatus(forMediaType: AVMediaType.audio) == .authorized {
                    do {
                        let nextLevel = NextLevel.shared
                        try nextLevel.start()
                    } catch {
                        DispatchQueue.main.async {
                            if self?.newMapMode ?? false {
                                self?.navigationController?.popViewController(animated: true)
                            } else {
                                self?.popToMap()
                            }
                        }
                    }
                    
                } else if status == .notAuthorized {
                    self?.showSettingsAlert(title: "Allow camera access in Settings to post on sp0t", message: nil, location: false)
                }
            }
        }
        askForLocationAccess()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { self.view.isUserInteractionEnabled = true }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NextLevel.shared.stop()
        newMapMode = false
        
        if isMovingFromParent {
            if UploadPostModel.shared.postObject == nil {
                UploadPostModel.shared.destroy()
            }
        }
    }
    
    private func setUpView() {
        setUpPost() /// set up main mapPost object
        addCameraView() /// add main camera
        fetchAssets() /// fetch gallery assets
        getFailedUploads()
    }
    
    private func addCameraView() {
        /// start camera area below notch on iPhone X+
        let smallScreen = UserDataModel.shared.screenSize == 0
        let galleryOffset: CGFloat = !smallScreen ? 50 : 35

        let window = UIApplication.shared.keyWindow
        let minStatusHeight: CGFloat = UserDataModel.shared.screenSize == 2 ? 54 : UserDataModel.shared.screenSize == 1 ? 47 : 20
        let statusHeight = max(window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 20.0, minStatusHeight)
        
        if newMapMode {
            cameraView.addSubview(backButton)
            backButton.snp.makeConstraints {
                $0.leading.equalTo(5.5)
                $0.top.equalTo(statusHeight + 10)
                $0.width.equalTo(48.6)
                $0.height.equalTo(38.6)
            }
            
            let titleView = NewMapTitleView()
            cameraView.addSubview(titleView)
            titleView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(60)
                $0.top.equalTo(backButton.snp.top).offset(2)
                $0.centerX.equalToSuperview()
            }
            
        } else {
            cameraView.addSubview(cancelButton)
            cancelButton.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(6)
                $0.top.equalToSuperview().offset(statusHeight + 10)
                $0.width.height.equalTo(45)
            }
        }
        
        cameraView.addSubview(frontFlashView)
        frontFlashView.isHidden = true
        frontFlashView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }
        
        view.addSubview(cameraButton)
        cameraButton.snp.makeConstraints {
            $0.bottom.equalTo(cameraView.snp.bottom).offset(-28)
            $0.width.height.equalTo(76)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(instructionsLabel)
        instructionsLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(cameraButton.snp.top).offset(-20.0)
        }

        view.addSubview(progressView)
        progressView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.width.equalTo(114)
            $0.height.equalTo(12)
            $0.bottom.equalTo(cameraButton.snp.top).offset(-20.0)
        }
        progressView.isHidden = true
        
        view.addSubview(galleryButton)
        galleryButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(37)
            $0.bottom.equalToSuperview().offset(-galleryOffset)
            $0.width.equalTo(34)
            $0.height.equalTo(29)
        }
        
        let galleryText = UILabel()
        galleryText.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        galleryText.font = UIFont(name: "SFCompactText-Semibold", size: 11)
        galleryText.textAlignment = .center
        galleryText.text = "GALLERY"
        
        view.addSubview(galleryText)
        galleryText.snp.makeConstraints {
            $0.leading.equalTo(galleryButton.snp.leading).offset(-10)
            $0.top.equalTo(galleryButton.snp.bottom).offset(1)
            $0.width.equalTo(54)
            $0.height.equalTo(18)
        }

        view.addSubview(nextButton)
        nextButton.isHidden = true
        nextButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.top.equalTo(galleryButton)
            $0.width.equalTo(94)
            $0.height.equalTo(40)
        }

        cameraView.addSubview(flashButton)
        flashButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(14)
            $0.top.equalTo(statusHeight + 22)
            $0.width.equalTo(31)
            $0.height.equalTo(39)
        }
        
        cameraView.addSubview(cameraRotateButton)
        cameraRotateButton.snp.makeConstraints {
            $0.centerX.equalTo(flashButton)
            $0.top.equalTo(flashButton.snp.bottom).offset(20)
            $0.width.equalTo(41.2)
            $0.height.equalTo(35)
        }
        
        /// double tap flips the camera
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delaysTouchesBegan = true
        doubleTap.delegate = self
        cameraView.addGestureRecognizer(doubleTap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTapGestureRecognizer(_:)))
        singleTap.delegate = self
        singleTap.numberOfTapsRequired = 1
        cameraView.addGestureRecognizer(singleTap)
        
        addTop()
    }
    
    private func addTop() {
        let topMask = UIView()
        cameraView.insertSubview(topMask, at: 0)
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(150)
        }
        
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100)
        layer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.45).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer.endPoint = CGPoint(x: 0.5, y: 0.0)
        layer.locations = [0, 1]
        topMask.layer.addSublayer(layer)
    }
    
    func setUpPost() {
        /// new post object already created for new map mode
        if !newMapMode {
            UploadPostModel.shared.createSharedInstance()
        }
    }

    func resetProgressView() {
        progressView.setProgress(0, animated: false)
        progressViewCachedPosition = nil
        videoPressStartTime = nil
    }
    
    private func fetchAssets() {
        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            UploadPostModel.shared.fetchAssets { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let galleryVC = self.navigationController?.viewControllers.first(where: { $0 is PhotoGalleryController }) as? PhotoGalleryController {
                        galleryVC.collectionView.reloadData()
                    }
                }
            }
        }
    }
}

extension CameraViewController {
    @objc func nextTap() {
        // end capture before recording for max duration
        endCapture()
    }

    @objc func switchFlash() {
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff") {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            NextLevel.shared.flashMode = .on
        } else {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            NextLevel.shared.flashMode = .off
        }
    }
    
    @objc func cameraRotateTap() {
        switchCameras()
    }
    
    @objc func switchCameras() {
        NextLevel.shared.flipCaptureDevicePosition()
    }
    
    @objc func backTap() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func cancelTap() {
        popToMap()
    }
    
    @objc func doubleTap() {
        switchCameras()
    }
    
    func showSettingsAlert(title: String, message: String?, location: Bool) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let settingsAction = UIAlertAction(
            title: "Open settings",
            style: .default) { _ in
                guard let settingsString = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsString, options: [:], completionHandler: nil)
        }
        
        alert.addAction(settingsAction)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel) { [weak self] _ in
                if location {
                    DispatchQueue.main.async {
                        if self?.newMapMode ?? false {
                            self?.navigationController?.popViewController(animated: true)
                        } else {
                            self?.popToMap()
                        }
                    }
                }
        }
        
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }
}
