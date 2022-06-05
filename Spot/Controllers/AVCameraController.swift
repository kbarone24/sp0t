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
        
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let db: Firestore! = Firestore.firestore()

    var cameraController: AVSpotCamera!
    unowned var mapVC: MapViewController!

    var spotObject: MapSpot!
    var volumeHandler: JPSVolumeButtonHandler! /// capture image on volume button tap
    
    var cameraView: UIView!
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
    var pan: UIPanGestureRecognizer!
    var tapIndicator: UIImageView! /// show focus circle when user taps screen
    var frontFlashView: UIView! /// white screen for use with front flash
    
    var cameraHeight: CGFloat!
    
    var gifMode = false
    var cancelOnDismiss = false
    
    var accessMask: CameraAccessView!
        
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
        Mixpanel.mainInstance().track(event: "CameraOpen")
        super.viewDidAppear(animated)
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
            self.navigationController?.setNavigationBarHidden(false, animated: false)
        }
    }
    
    deinit {
        volumeHandler.stop()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
        
    override func viewDidLoad() {
                
        addCameraView() /// add main camera
        setUpPost() /// set up main mapPost object
        fetchAssets() /// fetch gallery assets
    }
    
    func addCameraView() {
        
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        view.backgroundColor = UIColor(named: "SpotBlack")
                
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
                
        /// start camera area below notch on iPhone X+
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let cameraY: CGFloat = minY == 2 ? minY + cameraHeight - 30 : minY + cameraHeight - 108
        let galleryY: CGFloat = minY == 2 ? cameraY : minY + cameraHeight + 13
        
        cameraView = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight))
        cameraView.layer.cornerRadius = 15
        cameraView.backgroundColor = .black
        view.addSubview(cameraView)
                                                    
        cancelButton = UIButton(frame: CGRect(x: 4, y: 37, width: 50, height: 50))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cancelButton.contentHorizontalAlignment = .fill
        cancelButton.contentVerticalAlignment = .fill
        cancelButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        cameraView.addSubview(cancelButton)
                
        tapIndicator = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        tapIndicator.image = UIImage(named: "TapFocusIndicator")
        tapIndicator.isHidden = true
        cameraView.addSubview(tapIndicator)
        
        frontFlashView = UIView(frame: view.frame)
        frontFlashView.backgroundColor = .white
        frontFlashView.isHidden = true
        cameraView.addSubview(frontFlashView)
                
        volumeHandler = JPSVolumeButtonHandler(up: {self.capture()}, downBlock: {self.capture()})
        volumeHandler.start(true)
                                                
        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 52, y: cameraY, width: 104, height: 104))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill
        view.addSubview(cameraButton)
                
        galleryButton = UIButton(frame: CGRect(x: 37, y: galleryY, width: 34, height: 29))
        galleryButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        galleryButton.setImage(UIImage(named: "PhotoGalleryButton"), for: .normal)
        galleryButton.imageView?.contentMode = .scaleAspectFill
        galleryButton.clipsToBounds = true
        galleryButton.layer.cornerRadius = 8
        galleryButton.layer.masksToBounds = true
        galleryButton.clipsToBounds = true
        galleryButton.addTarget(self, action: #selector(openGallery(_:)), for: .touchUpInside)
        view.addSubview(galleryButton)
        
        let galleryText = UILabel(frame: CGRect(x: galleryButton.frame.minX - 10, y: galleryButton.frame.maxY + 1, width: 54, height: 18))
        galleryText.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        galleryText.font = UIFont(name: "SFCompactText-Semibold", size: 11)
        galleryText.textAlignment = .center
        galleryText.text = "GALLERY"
        view.addSubview(galleryText)
        
        flashButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 50, y: 49, width: 38.28, height: 38.28))
        flashButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flashButton.contentHorizontalAlignment = .fill
        flashButton.contentVerticalAlignment = .fill
        flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
        flashButton.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        cameraView.addSubview(flashButton)
        
        cameraRotateButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 50, y: flashButton.frame.maxY + 20, width: 33.62, height: 37.82))
        cameraRotateButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cameraRotateButton.contentHorizontalAlignment = .fill
        cameraRotateButton.contentVerticalAlignment = .fill
        cameraRotateButton.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        cameraRotateButton.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
        cameraView.addSubview(cameraRotateButton)

        /// pan gesture will allow camera dismissal on swipe down
        pan = UIPanGestureRecognizer.init(target: self, action: #selector(panGesture))
        cameraView.addGestureRecognizer(pan)
        
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
        /// 
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        accessMask = CameraAccessView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - minY))
        accessMask.setUp()
        view.addSubview(accessMask)
    }
    
    func setUpPost() {
        /// spotObject is nil unless posting directly to a spot page
        let spotObject = UploadPostModel.shared.spotObject
        /// use spot coordinate or user's current location for starting location
        let coordinate = spotObject == nil ? UserDataModel.shared.currentLocation.coordinate : CLLocationCoordinate2D(latitude: spotObject!.spotLat, longitude: spotObject!.spotLong)
        UploadPostModel.shared.postObject = MapPost(id: UUID().uuidString, caption: "", postLat: coordinate.latitude, postLong: coordinate.longitude, posterID: uid, timestamp: Timestamp(date: Date()), actualTimestamp: Timestamp(date: Date()), userInfo: UserDataModel.shared.userInfo, spotID: spotObject == nil ? UUID().uuidString : spotObject!.id, city: "", frameIndexes: [], aspectRatios: [], imageURLs: [], postImage: [], seconds: 0, selectedImageIndex: 0, postScore: 0, commentList: [], likers: [], taggedUsers: [], imageHeight: 0, captionHeight: 0, cellHeight: 0, spotName: spotObject == nil ? "" : spotObject!.spotName, spotLat: spotObject == nil ? 0 : spotObject!.spotLat, spotLong: spotObject == nil ? 0 : spotObject!.spotLong, privacyLevel: spotObject == nil ? "friends" : spotObject!.privacyLevel, spotPrivacy: spotObject == nil ? "" : spotObject!.privacyLevel, createdBy: spotObject == nil ? uid : spotObject!.founderID, inviteList: [], friendsList: [], hideFromFeed: false, gif: false, addedUsers: [], addedUserProfiles: [], tag: "")
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
        pan.isEnabled = false
        cameraButton.isEnabled = false
        cancelButton.isUserInteractionEnabled = false
        galleryButton.isUserInteractionEnabled = false
        volumeHandler.stop()
    }
    
    func enableButtons() {
        pan.isEnabled = true
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
    /// alive photo capture from camera
  /*
    func captureGIF() {

        cameraController.captureGIF { (images) in

            self.animationImages.removeAll()
            
            for i in 0...images.count - 1 {
                let im2 = self.ResizeImage(with: images[i], scaledToFill:  CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
                self.animationImages.append(im2)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                
                /// reset front flash brightness after blasting it for fron flash
                if self.frontFlashView.isHidden == false {
                    UIScreen.main.brightness = self.initialBrightness
                    self.frontFlashView.isHidden = true
                    
                } else if self.cameraController.currentCameraPosition == .rear && self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")! && self.gifMode {
                    ///special rear flash used for gif mode so reset this on the final image
                    let device = self.cameraController.rearCamera
                    device?.toggleFlashlight()
                }
                
                if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                    
                    vc.spotObject = self.spotObject
                    
                    if let uploadVC = self.navigationController!.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController { vc.delegate = uploadVC }
                    
                    if let navController = self.navigationController {
                        navController.pushViewController(vc, animated: true)
                    }
                }
            }
        }
    }
*/
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
                self.mapVC.uploadMapReset()
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
           // self.setAutoExposure()
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
            
            vc.spotObject = self.spotObject
            
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
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        /// swipe between camera types
    /*    let direction = gesture.velocity(in: cameraView)
        
        if gesture.state == .began {
            beginPan = gesture.location(in: cameraView)
        
        } else if gesture.state == .ended {
        
            /*
            if !gifMode && abs(direction.x) > abs(direction.y) && direction.x > 200 && beginPan.x < 100 {
                navigationController?.popViewController(animated: true)
            } */
        } */
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
            tapIndicator.frame = CGRect(x: position.x - 25, y: position.y - 25, width: 50, height: 50)
            tapIndicator.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                UIView.animate(withDuration: 0.6, animations: { [weak self] in
                    guard let self = self else { return }
                    self.tapIndicator.isHidden = true
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
