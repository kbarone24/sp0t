//
//  AVCameraControllerExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation
import Mixpanel
import UIKit
import Photos

// permissions
extension AVCameraController {
    func askForLocationAccess() {
        showSettingsAlert(title: "Allow location access in Settings to post on sp0t", message: "sp0t needs your location to pin your posts on the map", location: true)
    }

    func askForCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { access in
                if access {
                    self.setUpInitialCaptureSession()
                } else {
                    self.removeCamera()
                }
            }
        case .denied, .restricted:
            // prompt to open settings if user had already rejected
            showSettingsAlert(title: "Allow camera access in Settings to post on sp0t", message: nil, location: false)
        default: return
        }
    }

    private func showSettingsAlert(title: String, message: String?, location: Bool) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open settings", style: .default, handler: { _ in
            guard let settingsString = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsString, options: [:], completionHandler: nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in
            if location { self.removeCamera() }
        }))
        DispatchQueue.main.async { self.present(alert, animated: true) }
    }

    func askForGalleryAccess() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { access in
                if access == .authorized || access == .limited {
                    self.openGallery(assetsFetched: false)
                }
            }
        case .restricted, .denied:
            // prompt to open settings if user had already rejected
            showSettingsAlert(title: "Allow gallery access in Settings to post a photo from your gallery", message: nil, location: false)
        default: return
        }
    }
}

extension AVCameraController {
    func restartCaptureSession() {
        DispatchQueue.main.async {
            self.cameraController?.previewLayer?.connection?.isEnabled = true
            self.enableButtons()
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.cameraController?.captureSession?.startRunning()
        }
    }

    // set up camera preview on screen if we have user permission
    func configureCameraController() {
        cameraController?.prepare(position: .rear) { [weak self] _ in
            guard let self = self else { return }
            try? self.cameraController?.displayPreview(on: self.cameraView)
            self.enableButtons()
            self.setAutoExposure()
        }
    }

    func setAutoExposure() {
        let device: AVCaptureDevice?
        if cameraController?.currentCameraPosition == .rear, let rearCamera = cameraController?.rearCamera {
            device = rearCamera
        } else if let frontCamera = cameraController?.frontCamera {
            device = frontCamera
        } else {
            device = nil
        }

        try? device?.lockForConfiguration()
        device?.isSubjectAreaChangeMonitoringEnabled = true

        if device?.isFocusModeSupported(.continuousAutoFocus) ?? false {
            device?.focusMode = .continuousAutoFocus
        }

        if device?.isExposureModeSupported(.continuousAutoExposure) ?? false {
            device?.exposureMode = .continuousAutoExposure
        }

        device?.unlockForConfiguration()
    }

    func resetZoom() {
        // resets the zoom level when switching between rear and front cameras

        let device: AVCaptureDevice?
        if cameraController?.currentCameraPosition == .rear, let rearCamera = cameraController?.rearCamera {
            device = rearCamera
        } else if let frontCamera = cameraController?.frontCamera {
            device = frontCamera
        } else {
            device = nil
        }

        do {
            try device?.lockForConfiguration()
            defer { device?.unlockForConfiguration() }
            device?.videoZoomFactor = 1.0
            self.lastZoomFactor = 1.0

        } catch {
            // TODO: Handle errors here, show error alert
            print("\(error.localizedDescription)")
        }
    }

    func setFocus(position: CGPoint) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            return
        }

        let bounds = UIScreen.main.bounds
        let screenSize = bounds.size
        let focusPoint = CGPoint(x: position.y / screenSize.height, y: 1.0 - position.x / screenSize.width)

        /// add disappearing tap circle indicator and set focus on the tap area
        let minY: CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        let maxY: CGFloat = minY + cameraHeight

        guard position.y < maxY && position.y > minY else {
            return
        }

        tapIndicator.snp.updateConstraints {
            $0.top.equalTo(position.y - 25)
            $0.leading.equalTo(position.x - 25)
        }

        tapIndicator.alpha = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.tapIndicator.alpha = 0.0
            }
        }

        let device: AVCaptureDevice?
        if cameraController?.currentCameraPosition == .rear, let rearCamera = cameraController?.rearCamera {
            device = rearCamera
        } else if let frontCamera = cameraController?.frontCamera {
            device = frontCamera
        } else {
            device = nil
        }

        do {
            try device?.lockForConfiguration()
            if device?.isFocusPointOfInterestSupported ?? false {
                device?.focusPointOfInterest = focusPoint
                device?.focusMode = .autoFocus
            }

            if device?.isExposurePointOfInterestSupported ?? false {
                device?.exposurePointOfInterest = focusPoint
                device?.exposureMode = .autoExpose
            }

            device?.unlockForConfiguration()

        } catch {
            // TODO: Handle errors here, show error alert
            print("There was an error focusing the device's camera")
        }
    }

    func cancelFromGallery() {
        Mixpanel.mainInstance().track(event: "UploadCancelFromGallery", properties: nil)
        // reset selectedImages and imageObjects
        UploadPostModel.shared.selectedObjects.removeAll()
        while let i = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.selected }) {
            UploadPostModel.shared.imageObjects[i].selected = false
        }
    }
}

extension AVCameraController: UIGestureRecognizerDelegate {
    func minMaxZoom(device: AVCaptureDevice?, factor: CGFloat, minimumZoom: CGFloat, maximumZoom: CGFloat) -> CGFloat {
        guard let device = device else { return 0.0 }
        return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
    }

    func update(device: AVCaptureDevice?, scale factor: CGFloat) {
        do {
            try device?.lockForConfiguration()
            defer { device?.unlockForConfiguration() }
            device?.videoZoomFactor = factor
        } catch {
            print("\(error.localizedDescription)")
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view?.isKind(of: UIButton.self) ?? false) /// cancel touche
    }
}
