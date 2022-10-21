//
//  EditProfileCameraController.swift
//  Spot
//
//  Created by kbarone on 1/7/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import AVFoundation
import Foundation
import Mixpanel
import Photos
import RSKImageCropper
import UIKit

class EditProfileCameraController: UIViewController, UINavigationControllerDelegate {

    var cameraController: AVSpotCamera!

    var cameraButton: UIButton!
    var galleryButton: UIButton!
    var flashButton: UIButton!
    var cancelButton: UIButton!
    var cameraRotateButton: UIButton!
    var stillText: UIButton!

    var lastZoomFactor: CGFloat = 1.0
    var initialBrightness: CGFloat = 0.0

    var tapIndicator: UIImageView!
    var frontFlashView: UIView!
    var cameraMask: UIView!

    var cameraHeight: CGFloat!
    lazy var imagePicker = UIImagePickerController()
    unowned var editProfileVC: EditProfileController!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.cameraController == nil {
            cameraController = AVSpotCamera()
            configureCameraController()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        /// reset bar button appearance
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .selected)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)
    }

    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "EditProfileCameraOpen")
        super.viewDidAppear(animated)
    }

    override func viewDidLoad() {

        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        view.backgroundColor = UIColor(named: "SpotBlack")

        /// camera height will be 600 for iphone 6-10, 662.4 for XR + 11
        let cameraAspect: CGFloat = 1.722_67
        cameraHeight = UIScreen.main.bounds.width * cameraAspect

        let minY: CGFloat = UIScreen.main.bounds.height > 800 ? 44 : 2
        let cameraY: CGFloat = minY + cameraHeight - 5 - 94

        /// camera button will always be 15 pts above the bottom of camera preview. size of button is 94 pts

        cameraButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 47, y: cameraY, width: 94, height: 94))
        cameraButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        cameraButton.setImage(UIImage(named: "CameraButton"), for: .normal)
        cameraButton.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        cameraButton.imageView?.contentMode = .scaleAspectFill

        view.addSubview(cameraButton)

        /// text above camera button for small screen, below camera button for iphoneX+
        let textY: CGFloat = minY == 2 ? cameraButton.frame.minY - 24 : minY + cameraHeight + 10

        if minY == 2 {
            /// add bottom mask that covers entire capture section
            cameraMask = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 135, width: UIScreen.main.bounds.width, height: 135))
            cameraMask.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        } else {
            /// add mask that just covers alive // still text
            cameraMask = UIView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - 98.5, y: textY - 1, width: 197, height: 23))
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
            // layer0.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: -1, b: 0, c: 0, d: -70.41, tx: 1, ty: 35.73))
            cameraMask.layer.insertSublayer(layer0, at: 0)
        }

        let buttonY: CGFloat = minY == 2 ? UIScreen.main.bounds.height - 70.5 : UIScreen.main.bounds.height - 82.5

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
        galleryText.font = UIFont(name: "SFCompactText-Semibold", size: 11)
        galleryText.textAlignment = .center
        galleryText.text = "Gallery"
        view.addSubview(galleryText)

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
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        self.view.addGestureRecognizer(pan)

        let zoom = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        self.view.addGestureRecognizer(zoom)

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
        self.view.addSubview(tapIndicator)

        frontFlashView = UIView(frame: view.frame)
        frontFlashView.backgroundColor = .white
        frontFlashView.isHidden = true
        self.view.addSubview(frontFlashView)

    }

    @objc func switchFlash(_ sender: UIButton) {

        if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            cameraController.flashMode = .on
        } else {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            cameraController.flashMode = .off
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
        } catch {
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

    @objc func captureImage(_ sender: UIButton) {

        cameraController.captureImage {(image, _) in
            guard var image = image else {
                return
            }

            let selfie = self.cameraController.currentCameraPosition == .front

            if selfie {
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }

            let resizedImage = self.ResizeImage(with: image, scaledToFill: CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight))!

            var imageCropVC: RSKImageCropViewController!
            imageCropVC = RSKImageCropViewController(image: resizedImage, cropMode: RSKImageCropMode.circle)

            imageCropVC.isRotationEnabled = false
            imageCropVC.delegate = self
            imageCropVC.dataSource = self
            imageCropVC.cancelButton.setTitleColor(.systemBlue, for: .normal)
            imageCropVC.chooseButton.setTitleColor(.systemBlue, for: .normal)
            imageCropVC.chooseButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
            imageCropVC.cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
            imageCropVC.cancelButton.setTitle("Back", for: .normal)
            imageCropVC.moveAndScaleLabel.text = "Preview Image"
            imageCropVC.moveAndScaleLabel.font = UIFont(name: "SFCompactText-Regular", size: 20)

            imageCropVC.modalPresentationStyle = .fullScreen
            self.present(imageCropVC, animated: true, completion: nil)
        }
    }

    @objc func cancelTap(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        switchCameras()
    }

    func configureCameraController() {

        cameraController.prepare(position: .front) {(error) in
            if let error = error {
                print(error)
            }

            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    DispatchQueue.main.async { // 4
                        self.configureCameraController()
                    }
                }
            } else if AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                let alert = UIAlertController(title: "Allow camera access to take a picture", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                                                switch action.style {
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
                                                switch action.style {
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
                     //   self.switchCameras()
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

    @objc func openCamRoll(_ sender: UIButton) {
        self.openCamRoll()
    }

    func openCamRoll() {

        if PHPhotoLibrary.authorizationStatus() == .notDetermined { // 1
            DispatchQueue.main.async { // 2
                PHPhotoLibrary.requestAuthorization { _ in // 3
                    DispatchQueue.main.async { // 4
                        self.openCamRoll()
                    }
                }
            }
            return

        } else if PHPhotoLibrary.authorizationStatus() == .denied || PHPhotoLibrary.authorizationStatus() == .restricted {
            let alert = UIAlertController(title: "Allow photo access to add a picture", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                                            switch action.style {
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
                                            switch action.style {
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

        } else {

            imagePicker.delegate = self
           // imagePicker.modalPresentationStyle = .fullScreen
            imagePicker.sourceType = .photoLibrary

            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .highlighted)
            UINavigationBar.appearance().backgroundColor = UIColor(named: "SpotBlack")

            present(imagePicker, animated: true, completion: nil)
            /// dismiss and present image picker

        }
    }

    @objc func panGesture(_ gesture: UIPanGestureRecognizer) {
        /// swipe between camera types or remove camera on swipe down
        let direction = gesture.velocity(in: self.view)
        if gesture.state == .ended || gesture.state == .cancelled {
            if abs(direction.y) > abs(direction.x) && direction.y > 200 {
                self.dismiss(animated: true, completion: nil)
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

    @objc func tap(_ tapGesture: UITapGestureRecognizer) {
        let position = tapGesture.location(in: view)
        setFocus(position: position)
    }

    func setFocus(position: CGPoint) {

        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized { return }

        let bounds = UIScreen.main.bounds
        let screenSize = bounds.size
        let focusPoint = CGPoint(x: position.y / screenSize.height, y: 1.0 - position.x / screenSize.width)

        /// add disappearing tap circle indicator and set focus on the tap area
        if position.y < UIScreen.main.bounds.height - 100 && position.y > 50 {
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

extension EditProfileCameraController: UIImagePickerControllerDelegate, RSKImageCropViewControllerDelegate, RSKImageCropViewControllerDataSource {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        var image: UIImage = (info[UIImagePickerController.InfoKey.originalImage] as? UIImage) ?? UIImage()
        if picker.sourceType == .camera && picker.cameraDevice == .front {
            image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
        }

        var imageCropVC: RSKImageCropViewController!
        imageCropVC = RSKImageCropViewController(image: image, cropMode: RSKImageCropMode.circle)

        imageCropVC.isRotationEnabled = false
        imageCropVC.delegate = self
        imageCropVC.dataSource = self
        imageCropVC.cancelButton.setTitleColor(.systemBlue, for: .normal)
        imageCropVC.chooseButton.setTitleColor(.systemBlue, for: .normal)
        imageCropVC.chooseButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
        imageCropVC.cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 18)
        imageCropVC.cancelButton.setTitle("Back", for: .normal)
        imageCropVC.moveAndScaleLabel.text = "Preview Image"
        imageCropVC.moveAndScaleLabel.font = UIFont(name: "SFCompactText-Regular", size: 20)

        imageCropVC.modalPresentationStyle = .fullScreen
        picker.present(imageCropVC, animated: true, completion: nil)
    }

    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        /// pass back image to edit profile
      //  editProfileVC.imageView.image = croppedImage
      // editProfileVC.newProfilePic = croppedImage
        Mixpanel.mainInstance().track(event: "EditProfileCameraCapture")
        editProfileVC.dismiss(animated: true, completion: nil)
    }

    func imageCropViewControllerCustomMaskRect(_ controller: RSKImageCropViewController) -> CGRect {

        let aspectRatio = CGSize(width: 16, height: 16)

        let viewWidth = controller.view.frame.width
        let viewHeight = controller.view.frame.height

        var maskWidth = viewWidth

        let maskHeight = maskWidth * aspectRatio.height / aspectRatio.width
        maskWidth = maskWidth - 1

        while maskHeight != floor(maskHeight) {
            maskWidth = maskWidth + 1
        }

        let maskSize = CGSize(width: maskWidth, height: maskHeight)

        let maskRect = CGRect(x: (viewWidth - maskSize.width) * 0.5, y: (viewHeight - maskSize.height) * 0.5, width: maskSize.width, height: maskSize.height)

        return maskRect
    }

    func imageCropViewControllerCustomMaskPath(_ controller: RSKImageCropViewController) -> UIBezierPath {
        let rect = controller.maskRect

        let point1 = CGPoint(x: rect.minX, y: rect.maxY)
        let point2 = CGPoint(x: rect.maxX, y: rect.maxY)
        let point3 = CGPoint(x: rect.maxX, y: rect.minY)
        let point4 = CGPoint(x: rect.minX, y: rect.minY)

        let rectangle = UIBezierPath()

        rectangle.move(to: point1)
        rectangle.addLine(to: point2)
        rectangle.addLine(to: point3)
        rectangle.addLine(to: point4)
        rectangle.close()

        return rectangle
    }

    func imageCropViewControllerCustomMovementRect(_ controller: RSKImageCropViewController) -> CGRect {
        controller.maskRect
    }
}

extension EditProfileCameraController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? false) /// cancel touche
    }
}
