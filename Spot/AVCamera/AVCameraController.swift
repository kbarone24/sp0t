//
//  AVCameraController.swift
//  Spot
//
//  Created by kbarone on 3/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import AVFoundation
import CoreData
import Firebase
import Foundation
import JPSVolumeButtonHandler
import Mixpanel
import Photos
import UIKit
import MetalKit

final class AVCameraController: UIViewController {
    var cameraController: AVSpotCamera?
    var mapObject: CustomMap?
    var postDraft: PostDraft?

    private lazy var askedForCamera: Bool = false

    lazy var volumeHandler: JPSVolumeButtonHandler? = {
        let handler = JPSVolumeButtonHandler(
            up: { [weak self] in
                self?.capture()
            },
            downBlock: { [weak self] in
                self?.capture()
            }
        )

        return handler
    }()

    private(set) lazy var cameraView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 5
        view.backgroundColor = UIColor(named: "SpotBlack")
        return view
    }()

    private(set) lazy var cameraButton: CameraButton = {
        let button = CameraButton()
        button.isEnabled = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(recordVideo(_:)))
        button.addGestureRecognizer(longPressGesture)
        
        return button
    }()

    private(set) lazy var galleryButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.setImage(UIImage(named: "PhotoGalleryButton"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFill
        button.clipsToBounds = true
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(galleryTap(_:)), for: .touchUpInside)
        return button
    }()

    private(set) lazy var flashButton: UIButton = {
        let button = UIButton()
        button.isEnabled = false
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "FlashOff"), for: .normal)
        button.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        return button
    }()

    private(set) lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "CancelButton"), for: .normal)
        button.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        return button
    }()

    private(set) lazy var backButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "BackArrow"), for: .normal)
        button.addTarget(self, action: #selector(backTap), for: .touchUpInside)
        return button
    }()

    private(set) lazy var cameraRotateButton: UIButton = {
        let button = UIButton()
        button.isEnabled = false
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        button.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var instructionsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(hexString: "35E0EC")
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        label.text = "Press & hold to shoot video"
        return label
    }()

    private(set) lazy var failedPostView = FailedPostView(frame: .zero)

    /// show focus circle when user taps screen
    private(set) lazy var tapIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "TapFocusIndicator")
        imageView.alpha = 0.0
        return imageView
    }()

    /// white screen for use with front flash
    private(set) lazy var frontFlashView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        return view
    }()

    private(set) lazy var animationImages: [UIImage] = []

    var lastZoomFactor: CGFloat = 1.0 /// use with pinch-to-zoom
    var initialBrightness: CGFloat = 0.0 /// use with front-facing flash

    var gifMode = false
    var cancelOnDismiss = false
    var newMapMode = false

    var cameraHeight: CGFloat {
        UserDataModel.shared.maxAspect * UIScreen.main.bounds.width
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)

        // set up camera view if not already loaded
        if self.cameraController == nil {
            setUpInitialCaptureSession()
        } else {
            restartCaptureSession()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CameraOpen")
        UploadPostModel.shared.imageFromCamera = false // reset when camera reappears
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        cameraController?.captureSession?.stopRunning()
        disableButtons() /// disable for deinit

        /// show nav bar when returning to map
        if isMovingFromParent {
            /// destroy if returning to map
            if UploadPostModel.shared.mapObject == nil { UploadPostModel.shared.destroy()
            }

            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func setUpView() {
        setUpPost() /// set up main mapPost object
        addCameraView() /// add main camera
        fetchAssets() /// fetch gallery assets
        getFailedUploads()
    }

    func setUpInitialCaptureSession() {
        galleryButton.isEnabled = true
        backButton.isEnabled = true
        cancelButton.isEnabled = true
        DispatchQueue.main.async {
            if UploadPostModel.shared.cameraEnabled {
                self.cameraController = AVSpotCamera()
                self.configureCameraController()
            } else {
                if !UploadPostModel.shared.locationAccess {
                    self.askForLocationAccess()
                } else {
                    self.askForCameraAccess()
                }
            }
        }
    }

    private func addCameraView() {
        view.backgroundColor = UIColor.black
        let window = UIApplication.shared.keyWindow
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0

        /// start camera area below notch on iPhone X+
        let smallScreen = UserDataModel.shared.screenSize == 0
        let minY = statusHeight
        let galleryOffset: CGFloat = !smallScreen ? 50 : 35

        view.addSubview(cameraView)
        cameraView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(minY)
            $0.height.equalTo(cameraHeight)
        }

        if newMapMode {
            view.addSubview(backButton)
            backButton.snp.makeConstraints {
                $0.leading.equalTo(5.5)
                $0.top.equalTo(60)
                $0.width.equalTo(48.6)
                $0.height.equalTo(38.6)
            }

            let titleView = NewMapTitleView {
                cameraView.addSubview($0)
            }

            titleView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview().inset(60)
                $0.top.equalTo(backButton.snp.top).offset(2)
                $0.centerX.equalToSuperview()
            }

        } else {
            cameraView.addSubview(cancelButton)
            cancelButton.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(4)
                $0.top.equalToSuperview().offset(10)
                $0.width.height.equalTo(50)
            }
        }

        cameraView.addSubview(tapIndicator)
        tapIndicator.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.height.width.equalTo(50)
        }

        cameraView.addSubview(frontFlashView)
        frontFlashView.isHidden = true
        frontFlashView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }

        volumeHandler?.start(true)
        
        view.addSubview(instructionsLabel)
        view.addSubview(cameraButton)
        
        instructionsLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(cameraButton.snp.top).offset(-15.0)
        }
        
        cameraButton.snp.makeConstraints {
            $0.bottom.equalTo(cameraView.snp.bottom).offset(-28)
            $0.width.height.equalTo(76)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(galleryButton)
        galleryButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(37)
            $0.bottom.equalToSuperview().offset(-galleryOffset)
            $0.width.equalTo(34)
            $0.height.equalTo(29)
        }

        let galleryText = UILabel {
            $0.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 11)
            $0.textAlignment = .center
            $0.text = "GALLERY"
            view.addSubview($0)
        }
        galleryText.snp.makeConstraints {
            $0.leading.equalTo(galleryButton.snp.leading).offset(-10)
            $0.top.equalTo(galleryButton.snp.bottom).offset(1)
            $0.width.equalTo(54)
            $0.height.equalTo(18)
        }

        cameraView.addSubview(flashButton)
        flashButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalToSuperview().offset(22)
            $0.width.height.equalTo(38.28)
        }

        cameraView.addSubview(cameraRotateButton)
        cameraRotateButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalTo(flashButton.snp.bottom).offset(20)
            $0.width.equalTo(33.62)
            $0.height.equalTo(37.82)
        }

        let zoom = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        cameraView.addGestureRecognizer(zoom)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        cameraView.addGestureRecognizer(tap)

        /// double tap flips the camera
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        cameraView.addGestureRecognizer(doubleTap)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.setAutoExposure(_:)),
            name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
            object: nil
        )
        addTop()
    }

    func addTop() {
        let topMask = UIView {
            cameraView.insertSubview($0, at: 0)
        }

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
        if !newMapMode { UploadPostModel.shared.createSharedInstance() }
    }

    func fetchAssets() {
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
