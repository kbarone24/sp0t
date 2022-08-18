//
//  CameraAccessView.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos

class CameraAccessView: UIView {
    var cancelButton: UIButton!
    var label0: UILabel!
    var label1: UILabel!
    
    var cameraAccess: UIButton!
    var galleryAccess: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .black
    }
    
    func setUp() {
        resetView()
        
        cancelButton = UIButton(frame: CGRect(x: 4, y: 17, width: 50, height: 50))
        cancelButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cancelButton.contentHorizontalAlignment = .fill
        cancelButton.contentVerticalAlignment = .fill
        cancelButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
        addSubview(cancelButton)

        label0 = UILabel(frame: CGRect(x: 50, y: UIScreen.main.bounds.height/4, width: UIScreen.main.bounds.width - 100, height: 20))
        label0.text = "Share on sp0t"
        label0.textColor = .white
        label0.font = UIFont(name: "SFCompactText-Semibold", size: 22)
        label0.textAlignment = .center
        addSubview(label0)
        
        label1 = UILabel(frame: CGRect(x: 30, y: label0.frame.maxY + 10, width: UIScreen.main.bounds.width - 60, height: 15))
        label1.text = "Enable access to take pictures."
        label1.textColor = UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha: 1.0)
        label1.font = UIFont(name: "SFCompactText-Regular", size: 15)
        label1.textAlignment = .center
        addSubview(label1)
        
        let cameraAuthorized = UploadPostModel.shared.cameraAccess == .authorized
        cameraAccess = UIButton(frame: CGRect(x: 30, y: label1.frame.maxY + 55, width: UIScreen.main.bounds.width - 60, height: 40))
        cameraAccess.titleEdgeInsets = UIEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
        cameraAccess.setTitle("Enable camera access", for: .normal)
        cameraAccess.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        cameraAccess.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
        cameraAccess.contentHorizontalAlignment = .center
        cameraAccess.alpha = cameraAuthorized ? 0.3 : 1.0
        if !cameraAuthorized { cameraAccess.addTarget(self, action: #selector(cameraAccessTap(_:)), for: .touchUpInside)}
        addSubview(cameraAccess)
        

        let galleryAuthorized = UploadPostModel.shared.galleryAccess == .authorized
        galleryAccess = UIButton(frame: CGRect(x: 30, y: cameraAccess.frame.maxY + 10, width: UIScreen.main.bounds.width - 60, height: 40))
        galleryAccess.titleEdgeInsets = UIEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
        galleryAccess.setTitle("Enable gallery access", for: .normal)
        galleryAccess.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        galleryAccess.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
        galleryAccess.contentHorizontalAlignment = .center
        galleryAccess.alpha = galleryAuthorized ? 0.3 : 1.0
        if !galleryAuthorized { galleryAccess.addTarget(self, action: #selector(galleryAccessTap(_:)), for: .touchUpInside)}
        addSubview(galleryAccess)
    }
    
    func resetView() {
        if cancelButton != nil { cancelButton.setImage(UIImage(), for: .normal)}
        if label0 != nil { label0.text = "" }
        if label1 != nil { label1.text = "" }
        if cameraAccess != nil { cameraAccess.setTitle("", for: .normal) }
        if galleryAccess != nil { galleryAccess.setTitle("", for: .normal)}
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        guard let camera = viewContainingController() as? AVCameraController else { return }
        camera.cancelTap()
    }
    
    @objc func cameraAccessTap(_ sender: UIButton) {
        print("camera tap")
        askForCameraAccess(first: true)
    }
    
    func checkForRemove() {
        /// remove mask and return to camera if user has authorized camera + gallery
        if UploadPostModel.shared.allAuths() {
            guard let camera = viewContainingController() as? AVCameraController else { return }
            DispatchQueue.main.async {
                self.removeFromSuperview()
                camera.accessMask = nil
                camera.configureCameraController()
            }
            
        } else {
            setUp() /// reload view
        }
    }
    
    func askForCameraAccess(first: Bool) {
        
        guard let camera = viewContainingController() as? AVCameraController else { return }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { response in
                DispatchQueue.main.async { // 4
                    self.askForCameraAccess(first: false)
                }
            }
        case .denied, .restricted:
            
            /// open settings immediately if user had already rejected
            if first {UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return }
            
            let alert = UIAlertController(title: "Allow camera access to take a picture", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil )}
            ))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            camera.present(alert, animated: false, completion: nil)
            
        case .authorized:
            UploadPostModel.shared.cameraAccess = .authorized
            checkForRemove()
            
        default: return
        }
    }
        
    @objc func galleryAccessTap(_ sender: UIButton) {
        print("gallery")
        askForGallery(first: true)
    }
    
    func askForGallery(first: Bool) {
        
        guard let camera = viewContainingController() as? AVCameraController else { return }

        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { _ in self.askForGallery(first: false) }
            
        case .restricted, .denied:
            
            if first {UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return }

            let alert = UIAlertController(title: "Allow gallery access to upload pictures from your camera roll", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil) }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            camera.present(alert, animated: true, completion: nil)
            

        case .authorized, .limited:
            UploadPostModel.shared.galleryAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            NotificationCenter.default.post(name: Notification.Name(rawValue: "GalleryAuthorized"), object: nil, userInfo: nil)
            checkForRemove()
            
        default: return
            
        }
    }
}
