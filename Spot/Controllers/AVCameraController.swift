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

protocol AVCameraDelegate {
    func finishPassing(image: UIImage)
}

class AVCameraController: UIViewController {
    
    unowned var mapVC: MapViewController!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var cameraController: AVSpotCamera!
    var spotObject: MapSpot!
    
    var cameraButton: UIButton!
    var galleryButton: UIButton!
    var draftsButton: UIButton!
    var draftsNotification: UIImageView!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var gifText: UIButton!
    var stillText: UIButton!
    var cameraMask: UIView!
    
    var gifMode = false
    
    var delegate: AVCameraDelegate?
    
    lazy var animationImages: [UIImage] = []
    var dotView: UIView!
    
    var lastZoomFactor: CGFloat = 1.0
    var initialBrightness: CGFloat = 0.0
    
    var pan: UIPanGestureRecognizer!
    var tapIndicator: UIImageView!
    var frontFlashView: UIView!
    
    var start: CFAbsoluteTime!
    var cameraHeight: CGFloat!
    
    let db: Firestore! = Firestore.firestore()
    
    var draftsActive = false
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.draftsNotification.isHidden = true
                
        ///set up camera view if not already loaded
        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            configureCameraController()
            
        } else {
            cameraController.previewLayer?.connection?.isEnabled = true
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
        
        /// disable for deinit
        
        if isMovingFromParent {

            self.navigationController?.setNavigationBarHidden(false, animated: false)
            mapVC.navigationController?.navigationBar.isTranslucent = true
            mapVC.navigationController?.navigationBar.removeShadow()
            mapVC.navigationController?.navigationBar.removeBackgroundImage()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.cameraController.captureSession?.stopRunning()
            }
        }
    }
        
    
    override func viewDidLoad() {
        
        for vc in self.navigationController!.children {
            if let mapVC = vc as? MapViewController { self.mapVC = mapVC }
        }
        
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        /// camera height will be 667 for iphone 6-10, 736.4 for XR + 11
        let cameraAspect: CGFloat = 1.72267
        cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 44 : 2
        let cameraY: CGFloat = minY + cameraHeight - 5 - 94
                
        /// text above camera button for small screen, below camera button for iphoneX+
        let textY: CGFloat = minY == 2 ? cameraY - 24 : minY + cameraHeight + 10
                
        if minY == 2 {
            /// add bottom mask that covers entire capture section
            cameraMask = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 145, width: UIScreen.main.bounds.width, height: 145))
            cameraMask.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        } else {
            /// add mask that just covers alive // still text
            cameraMask = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 98.5, y: textY - 1, width: 197, height: 23))
            cameraMask.backgroundColor = .clear
            cameraMask.isUserInteractionEnabled = false
            let layer0 = CAGradientLayer()
            layer0.frame = cameraMask.bounds
            layer0.colors = [
                UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1).cgColor,
                UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0).cgColor,
                UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 0).cgColor,
                UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1).cgColor
            ]
            
            layer0.locations = [0, 0.23, 0.77, 1]
            layer0.startPoint = CGPoint(x: 0, y: 0.5)
            layer0.endPoint = CGPoint(x: 1, y: 0.5)
            cameraMask.layer.insertSublayer(layer0, at: 0)
        }
        view.addSubview(cameraMask)
        
        /// camera button will always be 15 pts above the bottom of camera preview. size of button is 94 pts
        
        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 47, y: cameraY, width: 94, height: 94))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill
        
        view.addSubview(cameraButton)

        stillText = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: textY, width: 55, height: 25))
        stillText.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        stillText.setTitle("Photo", for: .normal)
        stillText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
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
        gifText.setTitle("Alive", for: .normal)
        gifText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
        gifText.titleLabel?.textAlignment = .center
        gifText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        gifText.titleLabel!.layer.shadowColor = UIColor.black.cgColor
        gifText.titleLabel!.layer.shadowRadius = 2.5
        gifText.titleLabel!.layer.shadowOpacity = 0.6
        gifText.titleLabel!.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        gifText.titleLabel!.layer.masksToBounds = false
        gifText.addTarget(self, action: #selector(transitionToGIF(_:)), for: .touchUpInside)
        view.addSubview(gifText)
        
        if minY != 2 { view.bringSubviewToFront(cameraMask) } /// camera mask is on top of text for large screen
        
        let dotY: CGFloat = minY == 2 ? cameraMask.frame.minY - 21 : cameraButton.frame.minY - 21
        dotView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 30, y: dotY, width: 60, height: 10))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        
        let buttonY = UIScreen.main.bounds.height - 82.5
        
        galleryButton = UIButton(frame: CGRect(x: 37, y: buttonY, width: 34, height: 29))
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
        
        draftsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 67, y: buttonY - 3.5, width: 32, height: 33))
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
        
        frontFlashView = UIView(frame: view.frame)
        frontFlashView.backgroundColor = .white
        frontFlashView.isHidden = true
        view.addSubview(frontFlashView)
        
        if spotObject != nil {
            let spotTitle = UILabel(frame: CGRect(x: 75, y: minY + 28, width: UIScreen.main.bounds.width - 150, height: 20))
            spotTitle.text = spotObject.spotName
            spotTitle.textColor = .white
            spotTitle.font = UIFont(name: "SFCamera-Regular", size: 14)
            spotTitle.sizeToFit()
            
            let maxWidth = flashButton.frame.minX - cancelButton.frame.maxX - 20
            let width = min(spotTitle.frame.width, maxWidth)
            let minX = (UIScreen.main.bounds.width - width)/2 + 11
            
            spotTitle.frame = CGRect(x: minX, y: minY + 28, width: width, height: 20)
            view.addSubview(spotTitle)
            
            let spotIcon = UIImageView(frame: CGRect(x: spotTitle.frame.minX - 22, y: minY + 30, width: 17, height: 17))
            spotIcon.image = UIImage(named: "PlainSpotIcon")
            view.addSubview(spotIcon)
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
    }
    
    func enableButtons() {
        pan.isEnabled = true
        cameraButton.isEnabled = true
        cancelButton.isUserInteractionEnabled = true
        galleryButton.isUserInteractionEnabled = true
        draftsButton.isUserInteractionEnabled = true
    }
    
    @objc func captureImage(_ sender: UIButton) {
        //if the gif camera is enabled, capture 5 images in rapid succession
        disableButtons()
        
        if gifMode {
            
            let flash = flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = cameraController.currentCameraPosition == .front
            
            Mixpanel.mainInstance().track(event: "CameraAliveCapture", properties: ["flash": flash, "selfie": selfie])
            
            self.addDots(count: 0)
            
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
            
            self.enableButtons()
            
            if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                
                vc.unfilteredImages = [resizedImage]
                vc.mapVC = self.mapVC
                vc.spotObject = self.spotObject
                
                if let navController = self.navigationController {
                    navController.pushViewController(vc, animated: true)
                }
            }
        }
        
    }
    
    func addDots(count: Int) {
        
        //dots show progress with each successive gif image capture
        if count < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
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
        self.draftsActive = true
        self.draftsNotification.isHidden = false
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
                
                self.enableButtons()

                if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "GIFPreview") as? GIFPreviewController {
                    vc.unfilteredImages = self.animationImages
                    vc.spotObject = self.spotObject
                    vc.gif = true
                    vc.mapVC = self.mapVC
                    
                    if let navController = self.navigationController {
                        navController.pushViewController(vc, animated: true)
                    }
                }
            }
        }
    }
    
    func addDot(count: Int) {
        let offset = CGFloat(count * 11) + 4.5
        let view = UIImageView(frame: CGRect(x: offset, y: 1, width: 7, height: 7))
        view.layer.cornerRadius = 3.5
        view.backgroundColor = .white
        dotView.addSubview(view)
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        
        let controllers = self.navigationController?.viewControllers
        if controllers?.count == 2 {
            self.popCamera()
        } else {
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    func popCamera() {
        
        mapVC.customTabBar.tabBar.isHidden = false
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromBottom
        
        DispatchQueue.main.async {
            self.navigationController?.view.layer.add(transition, forKey:kCATransition)
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    // set up camera preview on screen if we have user permission
    func configureCameraController() {
        
        cameraController.prepare(position: .rear) {(error) in
            if let error = error {
                print(error)
            }
            
            if (AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined) {
                AVCaptureDevice.requestAccess(for: .video) { response in
                    DispatchQueue.main.async { // 4
                        self.configureCameraController()
                    }
                }
            }
            
            else if AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                let alert = UIAlertController(title: "Allow camera access to take a picture", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                                                switch action.style{
                                                case .default:
                                                    
                                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                                                    
                                                case .cancel:
                                                    print("cancel")
                                                case .destructive:
                                                    print("destruct")
                                                @unknown default:
                                                    fatalError()
                                                }}))
                alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                                                switch action.style{
                                                case .default:
                                                    break
                                                case .cancel:
                                                    print("cancel")
                                                case .destructive:
                                                    print("destruct")
                                                @unknown default:
                                                    fatalError()
                                                }}))
                
                self.present(alert, animated: false, completion: nil)
                
            } else {
                if !self.cameraController.previewShown {
                    try? self.cameraController.displayPreview(on: self.view)
                    self.setAutoExposure()
                }
            }
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
            
            vc.mapVC = self.mapVC
            vc.emptyState = !self.draftsActive
            vc.spotObject = self.spotObject
            
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    @objc func openCamRoll(_ sender: UIButton) {
        self.openCamRoll()
    }
    
    func openCamRoll() {
        
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        
        case .notDetermined:
            DispatchQueue.main.async {
                PHPhotoLibrary.requestAuthorization { _ in
                    DispatchQueue.main.async {
                        self.openCamRoll()
                    }
                }
            }
            
        case .restricted, .denied:
            let alert = UIAlertController(title: "Allow photo access to add a picture", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                                            switch action.style{
                                            case .default:
                                                
                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                                                
                                            case .cancel:
                                                print("cancel")
                                            case .destructive:
                                                print("destruct")
                                            @unknown default:
                                                fatalError()
                                            }}))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                                            switch action.style{
                                            case .default:
                                                break
                                            case .cancel:
                                                print("cancel")
                                            case .destructive:
                                                print("destruct")
                                            @unknown default:
                                                fatalError()
                                            }}))
            
            self.present(alert, animated: true, completion: nil)
            

        case .authorized, .limited:
            if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "PhotosContainer") as? PhotosContainerController {
                
                vc.mapVC = self.mapVC
                vc.spotObject = self.spotObject
                if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited { vc.limited = true }
                                
                DispatchQueue.main.async {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            
        default: return
            
        }
    }
    
    func ResizeImage(with image: UIImage?, scaledToFill size: CGSize) -> UIImage? {
        
        let scale: CGFloat = max(size.width / (image?.size.width ?? 0.0), size.height / (image?.size.height ?? 0.0))
        let width: CGFloat = (image?.size.width ?? 0.0) * scale
        let height: CGFloat = (image?.size.height ?? 0.0) * scale
        let imageRect = CGRect(x: (size.width - width) / 2.0, y: (size.height - height) / 2.0 - 0.5, width: width, height: height)
        
        let clipSize = CGSize(width: size.width, height: size.height - 1) /// fix rounding error for images taken from camera
        UIGraphicsBeginImageContextWithOptions(clipSize, false, 0.0)
        image?.draw(in: imageRect)
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        /// swipe between camera types or remove camera on swipe down
        let direction = gesture.velocity(in: view)
        if gesture.state == .ended {
            if abs(direction.x) > abs(direction.y) && direction.x > 200 {
                if self.gifMode {
                    self.transitionToStill()
                }
            } else if abs(direction.x) > abs(direction.y) && direction.x < 200 {
                if !self.gifMode {
                    self.transitionToGIF()
                }
            } else if abs(direction.y) > abs(direction.x) && direction.y > 200 {
                self.popCamera()
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
        let position = tapGesture.location(in: view)
        setFocus(position: position)
    }
    
    func setFocus(position: CGPoint) {
        
        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized { return }
        
        let bounds = UIScreen.main.bounds
        let screenSize = bounds.size
        let focusPoint = CGPoint(x: position.y / screenSize.height, y: 1.0 - position.x / screenSize.width)
        
        /// add disappearing tap circle indicator and set focus on the tap area
        if position.y < UIScreen.main.bounds.height - 100  && position.y > 50 {
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
            
            let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 44 : 2
            let cameraY: CGFloat = minY + self.cameraHeight - 5 - 94
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.stillText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
                self.stillText.frame = CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.gifText.frame = CGRect(x: self.stillText.frame.maxX + 10, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.gifText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
                self.stillText.setTitleColor(UIColor.white, for: .normal)
            })
            
            cameraButton.frame = CGRect(x: UIScreen.main.bounds.width/2 - 47, y: cameraY, width: 94, height: 94)
            cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
            setStillFlash()
        }
    }
    
    @objc func transitionToGIF(_ sender: UIButton) {
        transitionToGIF()
    }
    
    func transitionToGIF() {
        
        if !self.gifMode {
            self.gifMode = true
            
            let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 44 : 2
            let cameraY: CGFloat = minY + self.cameraHeight - 5 - 95
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.stillText.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
                self.gifText.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
                self.gifText.frame = CGRect(x: UIScreen.main.bounds.width/2 - 27.5, y: self.gifText.frame.minY, width: self.gifText.frame.width, height: self.gifText.frame.height)
                self.stillText.frame = CGRect(x: self.gifText.frame.minX - 65, y: self.stillText.frame.minY, width: self.stillText.frame.width, height: self.stillText.frame.height)
                self.stillText.setTitleColor(UIColor.white.withAlphaComponent(0.65), for: .normal)
                self.gifText.setTitleColor(UIColor.white, for: .normal)
            })
            
            cameraButton.setImage(UIImage(named: "GIFCameraButton"), for: .normal)
            cameraButton.frame = CGRect(x: UIScreen.main.bounds.width/2 - 48, y: cameraY, width: 96, height: 96)
            setGifFlash()
        }
    }
}


extension AVCameraController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? false) /// cancel touche
    }
}
