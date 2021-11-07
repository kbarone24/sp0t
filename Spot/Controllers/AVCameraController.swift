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
    var cameraController: AVSpotCamera!
    var spotObject: MapSpot!
    var volumeHandler: JPSVolumeButtonHandler!
    
    var cameraButton: UIButton!
    var galleryButton: UIButton!
    var draftsButton: UIButton!
    var draftsNotification: UIImageView!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var aliveToggle: UIButton!
    var gifText: UIButton!
    var stillText: UIButton!
    var cameraMask: UIView!
    
    var gifMode = false
        
    lazy var animationImages: [UIImage] = []
    var dotView: UIView!
    
    var lastZoomFactor: CGFloat = 1.0
    
    var beginPan: CGPoint!
    var pan: UIPanGestureRecognizer!
    var tapIndicator: UIImageView!
    
    var start: CFAbsoluteTime!
    var cameraHeight: CGFloat!
    
    let db: Firestore! = Firestore.firestore()
    
    var draftsActive = false
    var cancelOnDismiss = false
    
    var accessMask: CameraAccessView!
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
                
        ///set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            if UploadImageModel.shared.allAuths() { configureCameraController() } else { addAccessMask() }
            /// else show preview
            
        } else {
            cameraController.previewLayer?.connection?.isEnabled = true
            cameraController.captureSession?.startRunning()
            draftsNotification.isHidden = true
            checkForDrafts()
            enableButtons()
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
        disableButtons()
        /// disable for deinit
        
        if isMovingFromParent {

            self.navigationController?.setNavigationBarHidden(false, animated: false)

           /* DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.cameraController.captureSession?.stopRunning()
            } */
        }
    }
    
    deinit {
        volumeHandler.stop()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
        
    override func viewDidLoad() {
                
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        /// camera height will be 667 for iphone 6-10, 736.4 for XR + 11
        let cameraAspect: CGFloat = 1.5
        cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        var cameraY: CGFloat = minY + cameraHeight + 3
        if minY == 82 { cameraY += 7 }
                                
        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 47, y: cameraY, width: 94, height: 94))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill
        
        view.addSubview(cameraButton)
                
        let dotY: CGFloat = cameraButton.frame.minY - 21
        dotView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 30, y: dotY, width: 60, height: 10))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        
        
        galleryButton = UIButton(frame: CGRect(x: 37, y: cameraY + 35.5, width: 34, height: 29))
        galleryButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        galleryButton.setImage(UIImage(named: "PhotoGalleryButton"), for: .normal)
        galleryButton.imageView?.contentMode = .scaleAspectFill
        galleryButton.clipsToBounds = true
        galleryButton.layer.cornerRadius = 8
        galleryButton.layer.masksToBounds = true
        galleryButton.clipsToBounds = true
        galleryButton.addTarget(self, action: #selector(openCamRoll(_:)), for: .touchUpInside)
        view.addSubview(galleryButton)
        
        let galleryText = UILabel(frame: CGRect(x: galleryButton.frame.minX - 10, y: galleryButton.frame.maxY + 1, width: 54, height: 18))
        galleryText.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        galleryText.font = UIFont(name: "SFCamera-Semibold", size: 11)
        galleryText.textAlignment = .center
        galleryText.text = "Gallery"
        view.addSubview(galleryText)
        
        draftsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 67, y: cameraY + 32, width: 32, height: 33))
        draftsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        draftsButton.setImage(UIImage(named: "DraftsButton"), for: .normal)
        draftsButton.imageView?.alpha = 0.89
        draftsButton.imageView?.contentMode = .scaleAspectFit
        draftsButton.addTarget(self, action: #selector(draftsTap(_:)), for: .touchUpInside)
        view.addSubview(draftsButton)
        
        draftsNotification = UIImageView(frame: CGRect(x: draftsButton.frame.maxX - 12, y: draftsButton.frame.minY - 12, width: 24, height: 24))
        draftsNotification.image = UIImage(named: "DraftAlert")
        draftsNotification.contentMode = .scaleAspectFit
        draftsNotification.isHidden = true
        view.addSubview(draftsNotification)
        
        /// unhide drafts notification if there are failed uploads
        checkForDrafts()
        
        let draftsText = UILabel(frame: CGRect(x: draftsButton.frame.minX - 10, y: draftsButton.frame.maxY + 1, width: 52, height: 18))
        draftsText.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        draftsText.font = UIFont(name: "SFCamera-Semibold", size: 11)
        draftsText.textAlignment = .center
        draftsText.text = "Drafts"
        view.addSubview(draftsText)
        
        flashButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 50, y: minY + 27, width: 38.28, height: 38.28))
        flashButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flashButton.contentHorizontalAlignment = .fill
        flashButton.contentVerticalAlignment = .fill
        flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
        flashButton.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        view.addSubview(flashButton)
        
        cameraRotateButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 49, y: flashButton.frame.maxY + 20, width: 33.62, height: 37.82))
        cameraRotateButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cameraRotateButton.contentHorizontalAlignment = .fill
        cameraRotateButton.contentVerticalAlignment = .fill
        cameraRotateButton.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        cameraRotateButton.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
        view.addSubview(cameraRotateButton)
        
        cancelButton = UIButton(frame: CGRect(x: 4, y: minY + 17, width: 50, height: 50))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cancelButton.contentHorizontalAlignment = .fill
        cancelButton.contentVerticalAlignment = .fill
        cancelButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        aliveToggle = UIButton(frame: CGRect(x: 5.7, y: minY + cameraHeight - 56, width: 94, height: 53))
        /// 74 x 33
        let image = gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
        aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
        view.addSubview(aliveToggle)

        /// pan gesture will allow camera dismissal on swipe down
        pan = UIPanGestureRecognizer.init(target: self, action: #selector(panGesture))
        view.addGestureRecognizer(pan)
        
        let zoom = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        view.addGestureRecognizer(zoom)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        view.addGestureRecognizer(tap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        view.addGestureRecognizer(doubleTap)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.setAutoExposure(_:)),
                                               name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                               object: nil)
        
        tapIndicator = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        tapIndicator.image = UIImage(named: "TapFocusIndicator")
        tapIndicator.isHidden = true
        view.addSubview(tapIndicator)
                
        volumeHandler = JPSVolumeButtonHandler(up: {self.capture()}, downBlock: {self.capture()})
        volumeHandler.start(true)
    }
    
    func addAccessMask() {
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        accessMask = CameraAccessView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - minY))
        accessMask.setUp()
        view.addSubview(accessMask)
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
    
    @objc func toggleAlive(_ sender: UIButton) {
        gifMode = !gifMode
        Mixpanel.mainInstance().track(event: "CameraToggleAlive", properties: ["on": gifMode])
        let image = gifMode ? UIImage(named: "AliveOn") : UIImage(named: "AliveOff")
        aliveToggle.setImage(image, for: .normal)
    }
    
    func switchCameras() {
        do {
            try cameraController.switchCameras()
            self.resetZoom()
            self.setFocus(position: view.center)
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
        draftsButton.isUserInteractionEnabled = false
        volumeHandler.stop()
    }
    
    func enableButtons() {
        pan.isEnabled = true
        cameraButton.isEnabled = true
        cancelButton.isUserInteractionEnabled = true
        galleryButton.isUserInteractionEnabled = true
        draftsButton.isUserInteractionEnabled = true
        volumeHandler.start(true)
    }
    
    @objc func captureImage(_ sender: UIButton) {
        //if the gif camera is enabled, capture 5 images in rapid succession
        capture()
    }
    
    func capture() {
        
        disableButtons()
        
        let flash = flashButton.image(for: .normal) == UIImage(named: "FlashOn")
        let selfie = cameraController.currentCameraPosition == .front
        
        Mixpanel.mainInstance().track(event: "CameraAliveCapture", properties: ["flash": flash, "selfie": selfie])
        
        DispatchQueue.main.async {
            if self.gifMode { self.addDots(count: 0) }
            self.captureImage()
        }
    }
        
    func addDots(count: Int) {
        
        //dots show progress with each successive gif image capture
        if count < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.addDot(count: count)
                self.addDots(count: count + 1)
            }
            
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                for sub in self.dotView.subviews {
                    sub.removeFromSuperview()
                }
            }
        }
    }
    
    func checkForDrafts() {
        
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        ///fetch request checks for any failed post uploads
        let postFetch =
            NSFetchRequest<NSNumber>(entityName: "PostDraft")
        ///check to make sure uid on post = current uid because coredata stuff saves to the device not the database
        postFetch.predicate = NSPredicate(format: "uid == %@", self.uid)
        postFetch.resultType = .countResultType
        
        do {
            let draftsCount: [NSNumber] = try managedContext.fetch(postFetch)
            for count in draftsCount {
                if count.intValue > 0 {
                    self.addExclamationPoint()
                }
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
        ///fetch request checks for any failed spot uploads
        let spotFetch = NSFetchRequest<NSNumber>(entityName: "SpotDraft")
        ///check to make sure uid on post = current uid because coredata stuff saves to the device not the database
        spotFetch.predicate = NSPredicate(format: "uid == %@", self.uid)
        spotFetch.resultType = .countResultType
        
        do {
            let draftsCount: [NSNumber] = try managedContext.fetch(spotFetch)
            for count in draftsCount {
                if count.intValue > 0 {
                    self.addExclamationPoint()
                }
            }
            
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
        checkAlives()
        //check for alives to see if drafts button is active
    }
    func checkAlives() {
        
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let alivesFetch = NSFetchRequest<NSNumber>(entityName: "ImagesArray")
        alivesFetch.predicate = NSPredicate(format: "uid == %@", self.uid)
        alivesFetch.resultType = .countResultType
        do {
            let alivesCount: [NSNumber] = try managedContext.fetch(alivesFetch)
            for count in alivesCount {
                if count.intValue > 0 {
                    self.draftsActive = true
                }
            }
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    func addExclamationPoint() {
        draftsActive = true
        draftsNotification.isHidden = false
        view.bringSubviewToFront(draftsNotification)
    }
    
    func captureImage() {
        
        cameraController.captureImage(gifMode: gifMode, completion: { [weak self] image, err, gifMode, data, outputURL in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { return }
            
            if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                
                var rotatedImage = (image ?? UIImage()).fixOrientation() ?? UIImage()
                let frontFacing = self.cameraController.currentCameraPosition == .front
                if frontFacing { rotatedImage = UIImage(cgImage: rotatedImage.cgImage!, scale: rotatedImage.scale, orientation: UIImage.Orientation.upMirrored) }
                
                vc.unfilteredStill = rotatedImage
                vc.gifMode = gifMode ?? false
                vc.imageData = data
                vc.outputURL = outputURL
                vc.frontFacing = frontFacing
                
                if let uploadVC = self.navigationController!.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController { vc.delegate = uploadVC }
                
                if let navController = self.navigationController {
                    DispatchQueue.main.async { navController.pushViewController(vc, animated: true) }
                }
            }
        })
    }
    
    func addDot(count: Int) {
        let offset = CGFloat(count * 11) + 4.5
        let view = UIImageView(frame: CGRect(x: offset, y: 1, width: 7, height: 7))
        view.layer.cornerRadius = 3.5
        view.backgroundColor = .white
        dotView.addSubview(view)
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        cancelTap()
    }
    
    func cancelTap() {
        self.navigationController?.popViewController(animated: true)
    }
        
    // set up camera preview on screen if we have user permission
    func configureCameraController() {

        cameraController.prepare(position: .rear) { [weak self] (error) in
            guard let self = self else { return }
            DispatchQueue.main.async { try? self.cameraController.displayPreview(on: self.view) }
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
    
    @objc func draftsTap(_ sender: UIButton) {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "Drafts") as? DraftsViewController {
            
            vc.emptyState = !self.draftsActive
            vc.spotObject = self.spotObject
            
            if let uploadVC = self.navigationController!.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController { vc.delegate = uploadVC }

            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @objc func openCamRoll(_ sender: UIButton) {
        self.openCamRoll()
    }
    
    func openCamRoll() {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "PhotosContainer") as? PhotosContainerController {
            
            vc.spotObject = self.spotObject
            
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited { vc.limited = true }
            
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        /// swipe between camera types
        let direction = gesture.velocity(in: view)
        
        if gesture.state == .began {
            beginPan = gesture.location(in: view)
        
        } else if gesture.state == .ended {
        
            if abs(direction.x) > abs(direction.y) && direction.x > 200 && beginPan.x < 100 {
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func swipeToExit() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        
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
    
    @objc func tap(_ tapGesture: UITapGestureRecognizer){
        let position = tapGesture.location(in: view)
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
