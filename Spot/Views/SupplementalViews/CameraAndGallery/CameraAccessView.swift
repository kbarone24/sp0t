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
    
    var cameraAccessButton: UIButton!
    var galleryAccessButton: UIButton!
    var locationAccessButton: UIButton!
    
    var cameraAccess = false {
        didSet {
            cameraAccessButton.alpha = cameraAccess ? 0.3 : 1.0
            cameraAccessButton.isEnabled = !cameraAccess
        }
    }
    
    var galleryAccess = false {
        didSet {
            galleryAccessButton.alpha = galleryAccess ? 0.3 : 1.0
            galleryAccessButton.isEnabled = !galleryAccess
        }
    }
    
    var locationAccess = false {
        didSet {
            locationAccessButton.alpha = locationAccess ? 0.3 : 1.0
            locationAccessButton.isEnabled = !locationAccess
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .black
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLocationAccess), name: NSNotification.Name(("UpdateLocation")), object: nil)

        cancelButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "CancelButton"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.leading.equalTo(4)
            $0.top.equalTo(17)
            $0.width.height.equalTo(50)
        }
        
        label0 = UILabel {
            $0.text = "Share on sp0t"
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 24)
            $0.textAlignment = .center
            addSubview($0)
        }
        label0.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-200)
        }
        
        label1 = UILabel {
            $0.text = "Enable access to post!"
            $0.textColor = UIColor(red: 0.704, green: 0.704, blue: 0.704, alpha: 1.0)
            $0.font = UIFont(name: "SFCompactText-Regular", size: 15)
            $0.textAlignment = .center
            addSubview($0)
        }
        label1.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.top.equalTo(label0.snp.bottom).offset(10)
        }
        
        locationAccessButton = UIButton {
            $0.setTitle("Enable location access", for: .normal)
            $0.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(locationAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        locationAccessButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label1.snp.bottom).offset(55)
        }
        
        cameraAccessButton = UIButton {
            $0.setTitle("Enable camera access", for: .normal)
            $0.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(cameraAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        cameraAccessButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(locationAccessButton.snp.bottom).offset(15)
        }
        
        galleryAccessButton = UIButton {
            $0.setTitle("Enable gallery access", for: .normal)
            $0.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
            $0.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
            $0.contentHorizontalAlignment = .center
            $0.addTarget(self, action: #selector(galleryAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        galleryAccessButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(cameraAccessButton.snp.bottom).offset(15)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
 
    func setUp(cameraAccess: Bool, galleryAccess: Bool, locationAccess: Bool) {
        self.cameraAccess = cameraAccess
        self.galleryAccess = galleryAccess
        self.locationAccess = locationAccess
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        guard let camera = viewContainingController() as? AVCameraController else { return }
        camera.cancelTap()
    }
    
    @objc func cameraAccessTap() {
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
            cameraAccess = true
            checkForRemove()
            
        default: return
        }
    }
        
    @objc func galleryAccessTap() {
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
            galleryAccess = true
            NotificationCenter.default.post(name: Notification.Name(rawValue: "GalleryAuthorized"), object: nil, userInfo: nil)
            checkForRemove()
            
        default: return
            
        }
    }
    
    @objc func locationAccessTap() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil )
    }
    
    @objc func notifyLocationAccess() {
        locationAccess = true
        checkForRemove()
    }
}
