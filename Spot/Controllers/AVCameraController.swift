//
//  AVCameraController.swift
//  Spot
//
//  Created by kbarone on 3/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Photos
import CoreData
import Firebase
import Mixpanel
import JPSVolumeButtonHandler

class AVCameraController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db: Firestore! = Firestore.firestore()
    
    var cameraController: AVSpotCamera!
    unowned var mapVC: MapController!
    
    var spotObject: MapSpot!
    var volumeHandler: JPSVolumeButtonHandler! /// capture image on volume button tap
    
    lazy var cameraView = UIView()
    var cameraButton: UIButton!
    var galleryButton: UIButton!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var cameraMask: UIView!
    
    lazy var animationImages: [UIImage] = []
    
    var lastZoomFactor: CGFloat = 1.0 /// use with pinch-to-zoom
    var initialBrightness: CGFloat = 0.0 /// use with front-facing flash
    
    var beginPan: CGPoint!
    var tapIndicator: UIImageView! /// show focus circle when user taps screen
    var frontFlashView: UIView! /// white screen for use with front flash
    
    var cameraHeight: CGFloat!
    
    var gifMode = false
    var cancelOnDismiss = false
    
    var accessMask: CameraAccessView!
    var postDraft: PostDraft?
    var failedPostView: FailedPostView?
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        
        ///set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            /// else show preview
            DispatchQueue.main.async {
                if UploadPostModel.shared.allAuths() { self.configureCameraController() } else { self.addAccessMask() } /// ask user for camera/gallery access if not granted
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        cameraController.previewLayer?.connection?.isEnabled = false
        cameraController.captureSession?.stopRunning()
        disableButtons() /// disable for deinit
     
        /// show nav bar when returning to map
        if isMovingFromParent {
            UploadPostModel.shared.destroy()
            volumeHandler = nil
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
    
    override func viewDidLoad() {
        
        addCameraView() /// add main camera
        setUpPost() /// set up main mapPost object
        fetchAssets() /// fetch gallery assets
        getFailedUploads()
    }
    
    func addCameraView() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        view.isUserInteractionEnabled = false
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        
        /// start camera area below notch on iPhone X+
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let cameraY: CGFloat = minY == 2 ? minY + cameraHeight - 30 : minY + cameraHeight - 108
        let galleryY: CGFloat = minY == 2 ? cameraY : minY + cameraHeight + 13
        
        cameraView = UIView {
            $0.layer.cornerRadius = 15
            $0.backgroundColor = .black
            view.addSubview($0)
        }
        
        cameraView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(minY)
            $0.height.equalTo(cameraHeight)
        }
        
        cancelButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "CancelButton"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            cameraView.addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(4)
            $0.top.equalToSuperview().offset(37)
            $0.width.height.equalTo(50)
        }
        
        tapIndicator = UIImageView {
            $0.image = UIImage(named: "TapFocusIndicator")
            $0.alpha = 0.0
            cameraView.addSubview($0)
        }
        tapIndicator.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.height.width.equalTo(50)
        }
        
        frontFlashView = UIView {
            $0.backgroundColor = .white
            $0.isHidden = true
            cameraView.addSubview($0)
        }
        frontFlashView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }
        
        volumeHandler = JPSVolumeButtonHandler(up: {self.capture()}, downBlock: {self.capture()})
        volumeHandler.start(true)
        
        cameraButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.setImage(UIImage(named: "CameraButton"), for: .normal)
            $0.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
            $0.imageView?.contentMode = .scaleAspectFill
            view.addSubview($0)
        }
        cameraButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(cameraY)
            $0.width.height.equalTo(104)
            $0.centerX.equalToSuperview()
        }
        
        galleryButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.setImage(UIImage(named: "PhotoGalleryButton"), for: .normal)
            $0.imageView?.contentMode = .scaleAspectFill
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 8
            $0.layer.masksToBounds = true
            $0.clipsToBounds = true
            $0.addTarget(self, action: #selector(openGallery(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        galleryButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(37)
            $0.top.equalTo(galleryY)
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
        
        flashButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "FlashOff"), for: .normal)
            $0.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
            cameraView.addSubview($0)
        }
        flashButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.top.equalToSuperview().offset(49)
            $0.width.height.equalTo(38.28)
        }
        
        cameraRotateButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
            $0.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
            cameraView.addSubview($0)
        }
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
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.setAutoExposure(_:)),
                                               name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(galleryAuthorized(_:)),
                                               name: NSNotification.Name(rawValue: "GalleryAuthorized"),
                                               object: nil)
    }
    
    func addAccessMask() {
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        accessMask = CameraAccessView {
            $0.setUp()
            view.addSubview($0)
        }
        accessMask.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(minY)
            $0.height.equalToSuperview().inset(minY/2)
        }
    }
    
    func setUpPost() {
        /// spotObject is nil unless posting directly to a spot page
        let spotObject = UploadPostModel.shared.spotObject
        /// use spot coordinate or user's current location for starting location
        let coordinate = spotObject == nil ? UserDataModel.shared.currentLocation.coordinate : CLLocationCoordinate2D(latitude: spotObject!.spotLat, longitude: spotObject!.spotLong)
        
        UploadPostModel.shared.postObject = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: coordinate.latitude, postLong: coordinate.longitude, posterID: uid, timestamp: Timestamp(date: Date()))
        UploadPostModel.shared.postObject.id = UUID().uuidString
        UploadPostModel.shared.postObject.privacyLevel = "friends"
        UploadPostModel.shared.setPostCity() /// set with every location change to avoid async lag on upload
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
        fetchOptions.fetchLimit = 10000
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        let indexSet = assetsFull.count > 10000 ? IndexSet(0...9999) : IndexSet(0...assetsFull.count - 1)
        UploadPostModel.shared.assetsFull = assetsFull
        
        DispatchQueue.global(qos: .default).async { assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { stop.pointee = true } /// cancel on dismiss = true when view is popped
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            let imageObj = (ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], animationIndex: 0, directionUp: true, gifMode: false, creationDate: creationDate, fromCamera: false), false)
            UploadPostModel.shared.imageObjects.append(imageObj)
            
            /// sort on final load
            let finalLoad = UploadPostModel.shared.imageObjects.count == assetsFull.count
            
            if finalLoad {
                if !(self.navigationController?.viewControllers.contains(where: {$0 is PhotoGalleryController}) ?? false) { UploadPostModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected}) }
            }
        }}
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
    
    
    func switchCameras() {
        do {
            try cameraController.switchCameras()
            self.resetZoom()
            self.setFocus(position: cameraView.center)
        }
        
        catch {
            print(error)
        }
    }
    
    func setStillFlash() {
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
            cameraController.flashMode = .off
        } else {
            cameraController.flashMode = .on
        }
    }
    
    func setGifFlash() {
        cameraController.flashMode = .off
    }
    
    func disableButtons() {
        /// disable buttons while camera is capturing
        cameraButton.isEnabled = false
        cancelButton.isUserInteractionEnabled = false
        galleryButton.isUserInteractionEnabled = false
        volumeHandler.stop()
    }
    
    func enableButtons() {
        cameraButton.isEnabled = true
        cancelButton.isUserInteractionEnabled = true
        galleryButton.isUserInteractionEnabled = true
        volumeHandler.start(true)
    }
    
    @objc func captureImage(_ sender: UIButton) {
        //if the gif camera is enabled, capture 5 images in rapid succession
        capture()
    }
    
    func capture() {
        disableButtons()
        DispatchQueue.main.async { self.captureImage() }
    }
    
    func captureImage() {
        
        /// completion from AVSpotCamera
        self.cameraController.captureImage { [weak self] (image, error) in
            
            guard var image = image else { return }
            guard let self = self else { return }
            
            let flash = self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = self.cameraController.currentCameraPosition == .front
            
            Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])
            
            if selfie {
                /// flip image orientation on selfie
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }
            
            let resizedImage = self.ResizeImage(with: image, scaledToFill:  CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
            
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {
                
                let object = ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: UserDataModel.shared.currentLocation, stillImage: resizedImage, animationImages: [], animationIndex: 0, directionUp: true, gifMode: self.gifMode, creationDate: Date(), fromCamera: true)
                
                vc.spotObject = self.spotObject
                vc.cameraObject = object
                
                if let navController = self.navigationController {
                    navController.pushViewController(vc, animated: false)
                }
            }
        }
        
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        cancelTap()
    }
    
    func cancelTap() {
        
        /// show view controller sliding down as transtition
        DispatchQueue.main.async {
            
            /// set to title view for smoother transition
            self.navigationItem.leftBarButtonItem = UIBarButtonItem()
            self.navigationItem.rightBarButtonItem = UIBarButtonItem()
            self.navigationItem.titleView = self.mapVC.getTitleView()
            
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromBottom
            
            DispatchQueue.main.async {
                if let _ = self.navigationController?.viewControllers[(self.navigationController?.viewControllers.count ?? 2) - 2] as? MapController {
                    self.mapVC.uploadMapReset()
                }
                self.navigationController?.view.layer.add(transition, forKey:kCATransition)
                self.navigationController?.popViewController(animated: false)
            }
        }
    }
    
    // set up camera preview on screen if we have user permission
    func configureCameraController() {
        
        cameraController.prepare(position: .rear) { [weak self] (error) in
            guard let self = self else { return }
            try? self.cameraController.displayPreview(on: self.cameraView)
            self.view.isUserInteractionEnabled = true
            self.setAutoExposure()
        }
    }
    
    @objc func setAutoExposure(_ sender: NSNotification) {
        self.setAutoExposure()
    }
    
    func setAutoExposure() {
        
        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        
        try? device.lockForConfiguration()
        device.isSubjectAreaChangeMonitoringEnabled = true
        if device.isFocusModeSupported(AVCaptureDevice.FocusMode.continuousAutoFocus) {
            device.focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
        }
        if device.isExposureModeSupported(AVCaptureDevice.ExposureMode.continuousAutoExposure) {
            device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
        }
        device.unlockForConfiguration()
    }
    
    @objc func openGallery(_ sender: UIButton) {
        self.openGallery()
    }
    
    func openGallery() {
        if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "PhotoGallery") as? PhotoGalleryController {
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func cancelFromGallery() {
        
        Mixpanel.mainInstance().track(event: "UploadCancelFromGallery", properties: nil)
        
        /// reset selectedImages and imageObjects
        UploadPostModel.shared.selectedObjects.removeAll()
        while let i = UploadPostModel.shared.imageObjects.firstIndex(where: {$0.selected}) {
            UploadPostModel.shared.imageObjects[i].selected = false
        }
    }
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        
        /// pinch to adjust zoomLevel
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 5.0
        
        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended, .cancelled:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    @objc func tap(_ tapGesture: UITapGestureRecognizer) {
        /// set focus and show cirlcle indicator at that location
        let position = tapGesture.location(in: cameraView)
        setFocus(position: position)
    }
    
    func setFocus(position: CGPoint) {
        
        
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized { return }
        
        let bounds = UIScreen.main.bounds
        let screenSize = bounds.size
        let focusPoint = CGPoint(x: position.y / screenSize.height, y: 1.0 - position.x / screenSize.width)
        
        /// add disappearing tap circle indicator and set focus on the tap area
        let minY: CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        let maxY: CGFloat = minY + cameraHeight
        
        if position.y < maxY && position.y > minY {
            tapIndicator.snp.updateConstraints {
                $0.top.equalTo(position.y - 25)
                $0.leading.equalTo(position.x - 25)
            }
            tapIndicator.alpha = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIView.animate(withDuration: 0.3, animations: { [weak self] in
                    guard let self = self else { return }
                    self.tapIndicator.alpha = 0.0
                })
            }
            
            var device: AVCaptureDevice!
            
            if cameraController.currentCameraPosition == .rear {
                device = cameraController.rearCamera
            } else {
                device = cameraController.frontCamera
            }
            
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                }
                device.unlockForConfiguration()
                
            } catch {
                // Handle errors here
                print("There was an error focusing the device's camera")
            }
        }
    }
    
    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        switchCameras()
    }
    
    func resetZoom() {
        // resets the zoom level when switching between rear and front cameras
        
        var device: AVCaptureDevice!
        if cameraController.currentCameraPosition == .rear {
            device = cameraController.rearCamera
        } else {
            device = cameraController.frontCamera
        }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = 1.0
            self.lastZoomFactor = 1.0
        } catch {
            print("\(error.localizedDescription)")
        }
    }
}

extension AVCameraController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? false) /// cancel touche
    }
}
