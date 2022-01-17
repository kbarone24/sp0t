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
    
    var cameraView: UIView!
    var cameraButton: UIButton!
    var galleryButton: UIButton!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var aliveToggle: UIButton!
    var gifText: UIButton!
    var stillText: UIButton!
    var cameraMask: UIView!
    
    var gifMode = false
        
    lazy var animationImages: [UIImage] = []
    
    var gifView: UIView!
    var holdStillLabel: UILabel!
    var aliveBar: UIView!
    var aliveFill: UIView!
    
    var lastZoomFactor: CGFloat = 1.0
    var initialBrightness: CGFloat = 0.0
    
    var beginPan: CGPoint!
    var pan: UIPanGestureRecognizer!
    var tapIndicator: UIImageView!
    var frontFlashView: UIView!
    
    var start: CFAbsoluteTime!
    var cameraHeight: CGFloat!
    
    let db: Firestore! = Firestore.firestore()
    
    var cancelOnDismiss = false
    
    var accessMask: CameraAccessView!
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
                
        ///set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            /// else show preview
            if UploadImageModel.shared.allAuths() { configureCameraController() } else { addAccessMask() }
            
        } else {
            cameraController.previewLayer?.connection?.isEnabled = true
            cameraController.captureSession?.startRunning()
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
        let textY: CGFloat = minY == 2 ? minY + cameraHeight - 30 : minY + cameraHeight + 10
        let cameraY: CGFloat = textY + 27
        let gifY: CGFloat = cameraY - 80
        
        cameraView = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight))
        cameraView.backgroundColor = .black
        view.addSubview(cameraView)
                        
        gifView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 45, y: gifY, width: 90, height: 32))
        gifView.backgroundColor = nil
        gifView.isHidden = true
        view.addSubview(gifView)
        
        holdStillLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 90, height: 16))
        holdStillLabel.text = "HOLD STILL!"
        holdStillLabel.textColor = UIColor(named: "SpotGreen")
        holdStillLabel.font = UIFont(name: "SFCompactText-Semibold", size: 11.5)
        holdStillLabel.textAlignment = .center
        gifView.addSubview(holdStillLabel)
        
        aliveBar = UIView(frame: CGRect(x: 0, y: holdStillLabel.frame.maxY + 3, width: 90, height: 13))
        aliveBar.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        aliveBar.layer.cornerRadius = 4
        aliveBar.layer.borderWidth = 2
        aliveBar.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        gifView.addSubview(aliveBar)
        
        aliveFill = UIView(frame: CGRect(x: 1, y: aliveBar.frame.minY + 1, width: 0, height: 11))
        aliveFill.backgroundColor = UIColor(named: "SpotGreen")
        aliveFill.layer.cornerRadius = 4
        gifView.addSubview(aliveFill)
                    
        cancelButton = UIButton(frame: CGRect(x: 4, y: 13, width: 50, height: 50))
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
                                                
        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 47, y: cameraY, width: 94, height: 94))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill
        view.addSubview(cameraButton)
        
        stillText = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: textY, width: 55, height: 25))
        stillText.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        stillText.setTitle("PHOTO", for: .normal)
        stillText.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        stillText.setTitleColor(UIColor.white, for: .normal)
        stillText.titleLabel!.layer.shadowColor = UIColor.black.cgColor
        stillText.titleLabel!.layer.shadowRadius = 2.5
        stillText.titleLabel!.layer.shadowOpacity = 0.6
        stillText.titleLabel!.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        stillText.titleLabel!.layer.masksToBounds = false
        stillText.titleLabel?.textAlignment = .center
        stillText.addTarget(self, action: #selector(transitionToStill(_:)), for: .touchUpInside)
        view.addSubview(stillText)
        
        gifText = UIButton(frame: CGRect(x: stillText.frame.maxX + 10, y: textY, width: 55, height: 25))
        gifText.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        gifText.setTitle("ALIVE", for: .normal)
        gifText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
        gifText.titleLabel?.textAlignment = .center
        gifText.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
        gifText.titleLabel!.layer.shadowColor = UIColor.black.cgColor
        gifText.titleLabel!.layer.shadowRadius = 2.5
        gifText.titleLabel!.layer.shadowOpacity = 0.6
        gifText.titleLabel!.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        gifText.titleLabel!.layer.masksToBounds = false
        gifText.addTarget(self, action: #selector(transitionToGIF(_:)), for: .touchUpInside)
        view.addSubview(gifText)
        
        galleryButton = UIButton(frame: CGRect(x: 37, y: cameraY + 29, width: 34, height: 29))
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
        galleryText.font = UIFont(name: "SFCompactText-Semibold", size: 11)
        galleryText.textAlignment = .center
        galleryText.text = "GALLERY"
        view.addSubview(galleryText)
        
        cameraRotateButton = UIButton(frame: CGRect(x: cameraButton.frame.maxX + 30, y: cameraY + 32, width: 33.62, height: 37.82))
        cameraRotateButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        cameraRotateButton.contentHorizontalAlignment = .fill
        cameraRotateButton.contentVerticalAlignment = .fill
        cameraRotateButton.setImage(UIImage(named: "CameraRotateAlt"), for: .normal)
        cameraRotateButton.addTarget(self, action: #selector(cameraRotateTap(_:)), for: .touchUpInside)
        view.addSubview(cameraRotateButton)

        flashButton = UIButton(frame: CGRect(x: cameraRotateButton.frame.maxX + 25, y: cameraY + 32, width: 38.28, height: 38.28))
        flashButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        flashButton.contentHorizontalAlignment = .fill
        flashButton.contentVerticalAlignment = .fill
        flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
        flashButton.addTarget(self, action: #selector(switchFlash(_:)), for: .touchUpInside)
        view.addSubview(flashButton)
        
        /// pan gesture will allow camera dismissal on swipe down
        pan = UIPanGestureRecognizer.init(target: self, action: #selector(panGesture))
        cameraView.addGestureRecognizer(pan)
        
        let zoom = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        cameraView.addGestureRecognizer(zoom)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        cameraView.addGestureRecognizer(tap)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        cameraView.addGestureRecognizer(doubleTap)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.setAutoExposure(_:)),
                                               name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,
                                               object: nil)
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
        
        if gifMode {
            
            let flash = flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = cameraController.currentCameraPosition == .front
            
            Mixpanel.mainInstance().track(event: "CameraAliveCapture", properties: ["flash": flash, "selfie": selfie])
            
            fillInBar()
            
            if flash {
                if selfie {
                    self.initialBrightness = UIScreen.main.brightness
                    self.frontFlashView.isHidden = false
                    view.bringSubviewToFront(frontFlashView)
                    UIScreen.main.brightness = 1.0
                    //account for flash turn on delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        self.captureGIF()
                    }
                    
                } else {
                    let device = cameraController.rearCamera
                    device?.toggleFlashlight()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        self.captureGIF()
                    }
                }
                
            } else {
                DispatchQueue.main.async {
                    self.captureGIF()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.captureImage()
            }
        }
    }
    
    func captureImage() {
        
        self.cameraController.captureImage {(image, error) in
            
            guard var image = image else { return }
            
            let flash = self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = self.cameraController.currentCameraPosition == .front
            
            Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])
            
            if selfie {
                /// flip image orientation on selfie
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }
            
            let resizedImage = self.ResizeImage(with: image, scaledToFill:  CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!
                        
            if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                
                vc.selectedImages = [resizedImage]
                vc.gifMode = false
                vc.spotObject = self.spotObject
                
                if let uploadVC = self.navigationController!.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController { vc.delegate = uploadVC }
                
                if let navController = self.navigationController {
                    navController.pushViewController(vc, animated: true)
                }
            }
        }
        
    }
    
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
                    
                    vc.selectedImages = self.animationImages
                    vc.gifMode = true 
                    vc.spotObject = self.spotObject
                    
                    if let uploadVC = self.navigationController!.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController { vc.delegate = uploadVC }
                    
                    if let navController = self.navigationController {
                        navController.pushViewController(vc, animated: true)
                    }
                }
            }
        }
    }

    func fillInBar() {
        
        UIView.animate(withDuration: 1.0) {
            self.aliveFill.frame = CGRect(x: self.aliveFill.frame.minX, y: self.aliveFill.frame.minY, width: 88, height: self.aliveFill.frame.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            guard let self = self else { return }
            self.aliveFill.frame = CGRect(x: self.aliveFill.frame.minX, y: self.aliveFill.frame.minY, width: 0, height: self.aliveFill.frame.height)
        }
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
            DispatchQueue.main.async { try? self.cameraController.displayPreview(on: self.cameraView) }
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
        
    @objc func openCamRoll(_ sender: UIButton) {
        self.openCamRoll()
    }
    
    func openCamRoll() {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "PhotosContainer") as? PhotosContainerController {
            
            vc.spotObject = self.spotObject
            
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        /// swipe between camera types
        let direction = gesture.velocity(in: cameraView)
        
        if gesture.state == .began {
            beginPan = gesture.location(in: cameraView)
        
        } else if gesture.state == .ended {
        
            if !gifMode && abs(direction.x) > abs(direction.y) && direction.x > 200 && beginPan.x < 100 {
                navigationController?.popViewController(animated: true)
                
            } else if abs(direction.x) > abs(direction.y) && direction.x > 200 {
                if self.gifMode {
                    self.transitionToStill()
                }
                
            } else if abs(direction.x) > abs(direction.y) && direction.x < 200 {
                if !self.gifMode {
                    self.transitionToGIF()
                }
            }
        }
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
    
    @objc func transitionToStill(_ sender: UIButton) {
        transitionToStill()
    }
    
    func transitionToStill() {
        
        if self.gifMode {
            
            self.gifMode = false
            
            /// aniimate gifView remove
            UIView.animate(withDuration: 0.15) {
                self.gifView.alpha = 0.0
                
            } completion: { [weak self] _ in
                guard let self = self else { return }
                self.gifView.isHidden = true
                self.gifView.alpha = 1.0
            }
            
            /// animate switch between labels
            UIView.animate(withDuration: 0.3, animations: {
                
                self.stillText.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
                self.stillText.frame = CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.gifText.frame = CGRect(x: self.stillText.frame.maxX + 10, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.gifText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
                self.stillText.setTitleColor(UIColor.white, for: .normal)
                self.gifView.alpha = 0.0
            })
            
            setStillFlash()
        }
    }
    
    @objc func transitionToGIF(_ sender: UIButton) {
        transitionToGIF()
    }
    
    func transitionToGIF() {
        
        if !self.gifMode {
            
            self.gifMode = true
            self.gifView.alpha = 0.0
            self.gifView.isHidden = false
            UIView.animate(withDuration: 0.15) { self.gifView.alpha = 1.0 }
            
            UIView.animate(withDuration: 0.3) {
                
                self.stillText.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
                self.gifText.frame = CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.stillText.frame = CGRect(x: self.gifText.frame.minX - 65, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.stillText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
                self.gifText.setTitleColor(UIColor.white, for: .normal)
            }
            
            setGifFlash()
        }
    }
}


extension AVCameraController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? false) /// cancel touche
    }
}
