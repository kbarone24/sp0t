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

final class AVCameraController: UIViewController {
    var cameraController: AVSpotCamera?
    var spotObject: MapSpot?
    var mapObject: CustomMap?
    var postDraft: PostDraft?
    
    /// capture image on volume button tap
    private lazy var volumeHandler: JPSVolumeButtonHandler? = {
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
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
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
        button.addTarget(self, action: #selector(openGallery(_:)), for: .touchUpInside)
        
        return button
    }()
    
    private(set) lazy var flashButton: UIButton = {
        let button = UIButton()
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
    
    private(set) var backButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "BackArrow"), for: .normal)
        button.addTarget(self, action: #selector(backTap), for: .touchUpInside)
        
        return button
    }()
    
    private(set) var cameraRotateButton: UIButton = {
        let button = UIButton()
        button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill
        button.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        button.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
        
        return button
    }()
    
    private(set) lazy var accessMask: CameraAccessView = {
        let mask = CameraAccessView()
        mask.setUp(
            cameraAccess: UploadPostModel.shared.cameraAccess == .authorized,
            galleryAccess: UploadPostModel.shared.galleryAccess == .authorized,
            locationAccess: UploadPostModel.shared.locationAccess
        )
        
        return mask
    }()
    
    var failedPostView: FailedPostView?
    var beginPan: CGPoint!
    
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
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db: Firestore! = Firestore.firestore()
    
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
        
        /// set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            /// else show preview
            DispatchQueue.main.async { [weak self] in
                if UploadPostModel.shared.allAuths() {
                    self?.configureCameraController()
                } else {
                    /// ask user for camera/gallery access if not granted
                    self?.view.isUserInteractionEnabled = true
                    self?.addAccessMask()
                }
            }
            
        } else {
            /// delay so pop happens first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                guard let self = self else { return }
                self.cameraController.previewLayer?.connection?.isEnabled = true
                self.cameraController.captureSession?.startRunning()
                self.enableButtons()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CameraOpen")
        UploadPostModel.shared.imageFromCamera = false /// reset when camera reappears
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        cameraController?.previewLayer?.connection?.isEnabled = false
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
    
    func setUpView() {
        setUpPost() /// set up main mapPost object
        addCameraView() /// add main camera
        fetchAssets() /// fetch gallery assets
        getFailedUploads()
    }
    
    func addCameraView() {
        view.backgroundColor = UIColor.black
        view.isUserInteractionEnabled = false
        
        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
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
            backButton!.snp.makeConstraints {
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
                $0.top.equalTo(backButton!.snp.top).offset(2)
                $0.centerX.equalToSuperview()
            }
            
        } else {
            cameraView.addSubview(cancelButton)
            cancelButton!.snp.makeConstraints {
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
        
        volumeHandler.start(true)

        view.addSubview(cameraButton)
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(galleryAuthorized(_:)),
            name: NSNotification.Name(rawValue: "GalleryAuthorized"),
            object: nil
        )
        
        addTop()
    }
    
    func addAccessMask() {
        view.addSubview(accessMask)
        accessMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    func addTop() {
        let topMask = UIView {
            cameraView.insertSubview($0, at: 0)
        }
        
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(150)
        }
        _ = CAGradientLayer {
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
    
    func setUpPost() {
        /// new post object already created for new map mode
        if !newMapMode { UploadPostModel.shared.createSharedInstance() }
    }
    
    /// authorized gallery access for the first time
    @objc func galleryAuthorized(_ sender: NSNotification) {
        fetchAssets()
    }
    
    func fetchAssets() {
        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            fetchFullAssets()
        }
    }
    
    func fetchFullAssets() {
        
        /// fetch all assets for showing when user opens photo gallery
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 10_000
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        let indexSet = assetsFull.count > 10_000 ? IndexSet(0...9_999) : IndexSet(0..<assetsFull.count)
        UploadPostModel.shared.assetsFull = assetsFull
        
        DispatchQueue.global(qos: .background).async { assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { stop.pointee = true } /// cancel on dismiss = true when view is popped
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            let imageObj = (
                ImageObject(
                    id: UUID().uuidString,
                    asset: object,
                    rawLocation: location,
                    stillImage: UIImage(),
                    animationImages: [],
                    animationIndex: 0,
                    directionUp: true,
                    gifMode: false,
                    creationDate: creationDate,
                    fromCamera: false
                ),
                false
            )
            
            UploadPostModel.shared.imageObjects.append(imageObj)
            
            if UploadPostModel.shared.imageObjects.count == assetsFull.count,
               !(self.navigationController?.viewControllers.contains(where: { $0 is PhotoGalleryController }) ?? false
                 { { UploadPostModel.shared.imageObjects.sort(by: { !$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected }) }
               }
                 }
                 }
                 }
                 
                 @objc func switchFlash(_ sender: UIButton) {
                   
                   if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
                       flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
                       if !gifMode { cameraController.flashMode = .on }
                   } else {
                       flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
                       if !gifMode { cameraController.flashMode = .off }
                   }
               }
                 
                 @objc func cameraRotateTap(_ sender: UIButton) {
                   switchCameras()
               }
                 
                 func disableButtons() {
                   /// disable buttons while camera is capturing
                   cameraButton.isEnabled = false
                   backButton?.isUserInteractionEnabled = false
                   cancelButton?.isUserInteractionEnabled = false
                   galleryButton.isUserInteractionEnabled = false
                   volumeHandler.stop()
               }
                 
                 func enableButtons() {
                   cameraButton.isEnabled = true
                   backButton?.isUserInteractionEnabled = true
                   cancelButton?.isUserInteractionEnabled = true
                   galleryButton.isUserInteractionEnabled = true
                   volumeHandler.start(true)
               }
                 
                 @objc func captureImage(_ sender: UIButton) {
                   // if the gif camera is enabled, capture 5 images in rapid succession
                   capture()
               }
                 
                 func capture() {
                   
                   disableButtons()
                   self.captureImage()
               }
                 
                 func captureImage() {
                   /// completion from AVSpotCamera
                   self.cameraController.captureImage { [weak self] (image, _) in
                       
                       guard var image = image else { return }
                       guard let self = self else { return }
                       
                       let flash = self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")
                       let selfie = self.cameraController.currentCameraPosition == .front
                       
                       Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])
                       
                       if selfie {
                           /// flip image orientation on selfie
                           image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
                       }
                       
                       let resizedImage = self.ResizeImage(with: image, scaledToFill: CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
                       
                       if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {
                           
                           let object = ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: UserDataModel.shared.currentLocation, stillImage: resizedImage, animationImages: [], animationIndex: 0, directionUp: true, gifMode: self.gifMode, creationDate: Date(), fromCamera: true)
                           vc.cameraObject = object
                           UploadPostModel.shared.imageFromCamera = true
                           
                           if let navController = self.navigationController {
                               navController.pushViewController(vc, animated: false)
                           }
                       }
                   }
               }
                 
                 @objc func backTap() {
                   self.navigationController?.popViewController(animated: true)
               }
                 
                 @objc func cancelTap() {
                   /// show view controller sliding down as transtition
                   DispatchQueue.main.async { [weak self] in
                       self?.navigationItem.leftBarButtonItem = UIBarButtonItem()
                       self?.navigationItem.rightBarButtonItem = UIBarButtonItem()
                       
                       let transition = CATransition()
                       transition.duration = 0.3
                       transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                       transition.type = CATransitionType.push
                       transition.subtype = CATransitionSubtype.fromBottom
                       
                       DispatchQueue.main.async {
                           if let mapVC = self?.navigationController?.viewControllers[(self.navigationController?.viewControllers.count ?? 2) - 2] as? MapController {
                               mapVC.uploadMapReset()
                           }
                           /// add up to down transition on return to map
                           self?.navigationController?.view.layer.add(transition, forKey: kCATransition)
                           self?.navigationController?.popViewController(animated: false)
                       }
                   }
               }
                 
                 @objc func setAutoExposure(_ sender: NSNotification) {
                   self.setAutoExposure()
               }
                 
                 @objc func openGallery(_ sender: UIButton) {
                   self.openGallery()
               }
                 
                 @objc func tap(_ tapGesture: UITapGestureRecognizer) {
                   /// set focus and show cirlcle indicator at that location
                   let position = tapGesture.location(in: cameraView)
                   setFocus(position: position)
               }
                 
                 @objc func doubleTap(_ sender: UITapGestureRecognizer) {
                   switchCameras()
               }
            }
