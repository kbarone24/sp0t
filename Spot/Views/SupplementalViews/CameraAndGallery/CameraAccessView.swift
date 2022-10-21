//
//  CameraAccessView.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import Photos
import UIKit

class CameraAccessView: UIView {
    var cancelButton: UIButton!
    var label: UILabel!

    var cameraAccessButton: AccessButton!
    var galleryAccessButton: AccessButton!
    var locationAccessButton: AccessButton!

    var cameraAccess = false {
        didSet {
            cameraAccessButton.access = cameraAccess
        }
    }

    var galleryAccess = false {
        didSet {
            galleryAccessButton.access = galleryAccess
        }
    }

    var locationAccess = false {
        didSet {
            if locationAccessButton != nil { locationAccessButton!.access = locationAccess }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .white
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLocationAccess), name: NSNotification.Name(("UpdateLocation")), object: nil)

        cancelButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            $0.contentHorizontalAlignment = .fill
            $0.contentVerticalAlignment = .fill
            $0.setImage(UIImage(named: "CancelButtonDark"), for: .normal)
            $0.addTarget(self, action: #selector(cancelTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        cancelButton.snp.makeConstraints {
            $0.leading.equalTo(4)
            $0.top.equalTo(44)
            $0.width.height.equalTo(50)
        }

        label = UILabel {
            $0.text = "Enable access to share on sp0t"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20)
            $0.textAlignment = .center
            addSubview($0)
        }
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-150)
        }

        cameraAccessButton = AccessButton {
            $0.setUp(type: .camera, enabled: cameraAccess)
            $0.addTarget(self, action: #selector(cameraAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        cameraAccessButton.snp.makeConstraints {
            $0.top.equalTo(label.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        galleryAccessButton = AccessButton {
            $0.setUp(type: .gallery, enabled: galleryAccess)
            $0.addTarget(self, action: #selector(galleryAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        galleryAccessButton.snp.makeConstraints {
            $0.top.equalTo(cameraAccessButton.snp.bottom).offset(25)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        locationAccessButton = AccessButton {
            $0.setUp(type: .location, enabled: locationAccess)
            $0.addTarget(self, action: #selector(locationAccessTap), for: .touchUpInside)
            addSubview($0)
        }
        locationAccessButton.snp.makeConstraints {
            $0.top.equalTo(galleryAccessButton.snp.bottom).offset(25)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setUp(cameraAccess: Bool, galleryAccess: Bool, locationAccess: Bool) {
        self.cameraAccess = cameraAccess
        self.galleryAccess = galleryAccess
        self.locationAccess = locationAccess
        locationAccessButton.isHidden = locationAccess
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
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { // 4
                    self.askForCameraAccess(first: false)
                }
            }
        case .denied, .restricted:
            /// open settings immediately if user had already rejected
            if first { DispatchQueue.main.async { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return } }
        case .authorized:
            cameraAccess = true
            checkForRemove()
        default: return
        }
    }

    @objc func galleryAccessTap() {
        askForGallery(first: true)
    }

    func askForGallery(first: Bool) {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { _ in self.askForGallery(first: false) }
        case .restricted, .denied:
            if first { DispatchQueue.main.async { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return } }
        case .authorized, .limited:
            galleryAccess = true
            NotificationCenter.default.post(name: Notification.Name(rawValue: "GalleryAuthorized"), object: nil, userInfo: nil)
            checkForRemove()
        default: return
        }
    }

    @objc func locationAccessTap() {
        DispatchQueue.main.async { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ) }
    }

    @objc func notifyLocationAccess() {
        locationAccess = true
        checkForRemove()
    }
}

class AccessButton: UIButton {
    var icon: UIImageView!
    var label: UILabel!
    var checkBox: UIImageView!

    var access = false {
        didSet {
            DispatchQueue.main.async {
                self.checkBox.image = self.access ? UIImage(named: "MapToggleOn")!.alpha(0.5) : UIImage(named: "MapToggleOff")
                self.icon.alpha = self.access ? 0.22 : 1.0
                self.label.alpha = self.access ? 0.22 : 1.0
            }
        }
    }

    enum AccessButtonType {
        case camera
        case gallery
        case location
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon = UIImageView {
            addSubview($0)
        }

        label = UILabel {
            $0.textColor = UIColor(red: 0.504, green: 0.504, blue: 0.504, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 20)
            addSubview($0)
        }
        label.snp.makeConstraints {
            $0.leading.equalTo(69)
            $0.centerY.equalToSuperview()
        }

        checkBox = UIImageView {
            addSubview($0)
        }
        checkBox.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-26)
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(33)
        }
    }

    func setUp(type: AccessButtonType, enabled: Bool) {
        switch type {
        case .camera:
            label.text = "Camera"
            icon.image = UIImage(named: "CameraAccess") /// placeholder
            icon.snp.makeConstraints {
                $0.leading.equalTo(18)
                $0.centerY.equalToSuperview()
                $0.width.equalTo(38.35)
                $0.height.equalTo(30.4)
            }
        case .gallery:
            label.text = "Photo gallery"
            icon.image = UIImage(named: "GalleryAccess") /// placeholder
            icon.snp.makeConstraints {
                $0.leading.equalTo(18)
                $0.centerY.equalToSuperview()
                $0.width.equalTo(37.2)
                $0.height.equalTo(31)
            }
        case .location:
            label.text = "Location"
            icon.image = UIImage(named: "LocationAccess") /// placeholder
            icon.snp.makeConstraints {
                $0.leading.equalTo(20)
                $0.centerY.equalToSuperview()
                $0.width.equalTo(28)
                $0.height.equalTo(32.8)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
