//
//  AVCameraControllerFunctions.swift
//  Spot
//
//  Created by Kenny Barone on 11/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Firebase
import Photos
import Mixpanel

extension AVCameraController {
    @objc func cameraRotateTap(_ sender: UIButton) {
        switchCameras()
    }

    func switchCameras() {
        do {
            try cameraController?.switchCameras()
            self.resetZoom()
            self.setFocus(position: cameraView.center)
        } catch {
            // TODO: Handle errors here, show error alert
            print(error)
        }
    }

    @objc func switchFlash(_ sender: UIButton) {
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff") {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            if !gifMode {
                cameraController?.flashMode = .on
            }
        } else {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            if !gifMode {
                cameraController?.flashMode = .off
            }
        }
    }

    func setStillFlash() {
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff")! {
            cameraController?.flashMode = .off
        } else {
            cameraController?.flashMode = .on
        }
    }

    func setGifFlash() {
        cameraController?.flashMode = .off
    }

    @objc func backTap() {
        DispatchQueue.main.async { self.navigationController?.popViewController(animated: true) }
    }

    @objc func cancelTap() {
        popToMap()
    }

    func removeCamera() {
        DispatchQueue.main.async {
            if self.newMapMode { self.navigationController?.popViewController(animated: true)
            } else {
                self.popToMap()
            }
        }
    }

    @objc func galleryTap(_ sender: UIButton) {
        self.galleryTap()
    }

    func popToMap() {
        // show view controller sliding down as transtition
        DispatchQueue.main.async { [weak self] in
            self?.navigationItem.leftBarButtonItem = UIBarButtonItem()
            self?.navigationItem.rightBarButtonItem = UIBarButtonItem()

            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromBottom

            DispatchQueue.main.async {
                if let mapVC = self?.navigationController?.viewControllers[(self?.navigationController?.viewControllers.count ?? 2) - 2] as? MapController {
                    mapVC.uploadMapReset()
                }
                /// add up to down transition on return to map
                self?.navigationController?.view.layer.add(transition, forKey: kCATransition)
                self?.navigationController?.popViewController(animated: false)
            }
        }
    }

    func galleryTap() {
        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            openGallery(assetsFetched: true)
        } else {
            askForGalleryAccess()
        }
    }

    func openGallery(assetsFetched: Bool) {
        DispatchQueue.main.async {
            guard let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "PhotoGallery") as? PhotoGalleryController else { return }
            if self.navigationController?.viewControllers.contains(where: { $0 is PhotoGalleryController }) ?? false { return }
            vc.fetchFromGallery = !assetsFetched
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func setAutoExposure(_ sender: NSNotification) {
        self.setAutoExposure()
    }

    @objc func pinch(_ pinch: UIPinchGestureRecognizer) {
        // pinch to adjust zoomLevel
        let minimumZoom: CGFloat = 1.0
        let maximumZoom: CGFloat = 5.0

        let device: AVCaptureDevice?
        if cameraController?.currentCameraPosition == .rear, let rearCamera = cameraController?.rearCamera {
            device = rearCamera
        } else if let frontCamera = cameraController?.frontCamera {
            device = frontCamera
        } else {
            device = nil
        }

        let newScaleFactor = minMaxZoom(device: device, factor: pinch.scale * lastZoomFactor, minimumZoom: minimumZoom, maximumZoom: maximumZoom)

        switch pinch.state {
        case .began:
            fallthrough
        case .changed:
            update(device: device, scale: newScaleFactor)
        case .ended, .cancelled:
            lastZoomFactor = minMaxZoom(device: device, factor: newScaleFactor, minimumZoom: minimumZoom, maximumZoom: maximumZoom)
            update(device: device, scale: lastZoomFactor)
        default: break
        }
    }


    @objc func tap(_ tapGesture: UITapGestureRecognizer) {
        /// set focus and show cirlcle indicator at that location
        let position = tapGesture.location(in: cameraView)
        setFocus(position: position)
    }

    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        switchCameras()
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
        self.cameraController?.captureImage { [weak self] (image, _) in

            guard var image = image else { return }
            guard let self = self else { return }

            let flash = self.flashButton.image(for: .normal) == UIImage(named: "FlashOn")
            let selfie = self.cameraController?.currentCameraPosition == .front

            Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])

            if selfie {
                /// flip image orientation on selfie
                guard let cgImage = image.cgImage else { return }
                image = UIImage(cgImage: cgImage, scale: image.scale, orientation: UIImage.Orientation.leftMirrored)
            }

            let resizedImage = self.ResizeImage(with: image, scaledToFill: CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight)) ?? UIImage()

            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {

                let object = ImageObject(
                    id: UUID().uuidString,
                    asset: PHAsset(),
                    rawLocation: UserDataModel.shared.currentLocation,
                    stillImage: resizedImage,
                    animationImages: [],
                    animationIndex: 0,
                    directionUp: true,
                    gifMode: self.gifMode,
                    creationDate: Date(),
                    fromCamera: true)

                vc.cameraObject = object
                UploadPostModel.shared.imageFromCamera = true

                if let navController = self.navigationController {
                    navController.pushViewController(vc, animated: false)
                }
            }
        }
    }

    func disableButtons() {
        /// disable buttons while camera is capturing
        cameraButton.isEnabled = false
        backButton.isEnabled = false
        cancelButton.isEnabled = false
        galleryButton.isEnabled = false
        flashButton.isEnabled = false
        cameraRotateButton.isEnabled = false
        volumeHandler?.stop()
    }

    func enableButtons() {
        cameraButton.isEnabled = true
        backButton.isEnabled = true
        cancelButton.isEnabled = true
        galleryButton.isEnabled = true
        flashButton.isEnabled = true
        cameraRotateButton.isEnabled = true
        volumeHandler?.start(true)
    }
}
