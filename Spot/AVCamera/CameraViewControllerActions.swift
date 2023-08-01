//
//  CameraViewControllerActions.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import NextLevel
import AVFoundation
import UIKit
import Mixpanel
import Photos
import CoreData
import Firebase

extension CameraViewController {
    @objc func nextTap() {
        // end capture before recording for max duration
        endCapture()
    }

    @objc func switchFlash() {
        if flashButton.image(for: .normal) == UIImage(named: "FlashOff") {
            flashButton.setImage(UIImage(named: "FlashOn"), for: .normal)
            flashMode = .on
        } else {
            flashButton.setImage(UIImage(named: "FlashOff"), for: .normal)
            flashMode = .off
        }
    }

    @objc func cameraRotateTap() {
        switchCameras()
    }

    @objc func switchCameras() {
        NextLevel.shared.flipCaptureDevicePosition()
        cameraDeviceView.isHidden = NextLevel.shared.devicePosition == .front
    }

    @objc func backTap() {
        self.navigationController?.popViewController(animated: true)
    }

    @objc func cancelTap() {
        popToMap()
    }

    @objc func cameraDoubleTap() {
        switchCameras()
    }

    @objc func retakeTap() {
        if let session = NextLevel.shared.session {
            session.removeAllClips()
        }
        for sub in progressView.subviews where sub.tag == 1 {
            sub.removeFromSuperview()
        }
        progressView.setProgress(0, animated: false)
        progressViewCachedPosition = progressView.progress
        nextStepsLabel.isHidden = true
        toggleCaptureButtons(enabled: true)
    }

    @objc func undoClipTap() {
        if let sub = progressView.subviews.last { sub.removeFromSuperview() }
        let progressPosition = progressView.subviews.last(where: { $0.tag == 1 })?.frame.maxX ?? 0
        let progressFillAmount = Float(progressPosition / progressView.bounds.width)

        progressView.setProgress(progressFillAmount, animated: false)
        progressViewCachedPosition = progressView.progress

        NextLevel.shared.session?.removeLastClip()
        nextStepsLabel.isHidden = true

        if NextLevel.shared.session?.clips.isEmpty ?? true {
            toggleCaptureButtons(enabled: true)
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            _panStartZoom = CGFloat(NextLevel.shared.videoZoomFactor)
        case .changed:
            NextLevel.shared.videoZoomFactor = Float(_panStartZoom * gesture.scale)
        default:
            return
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            _panStartPoint = gesture.location(in: self.view)
        case .changed:
            let newPoint = gesture.location(in: self.view)
            let adjust = (_panStartPoint.y / newPoint.y) - 1
            NextLevel.shared.videoZoomFactor *= (1 + Float(adjust) * 2)
            _panStartPoint = newPoint
        default:
            return
        }
    }

    func showSettingsAlert(title: String, message: String?, location: Bool) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let settingsAction = UIAlertAction(
            title: "Open settings",
            style: .default) { _ in
                guard let settingsString = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsString, options: [:], completionHandler: nil)
            }

        alert.addAction(settingsAction)

        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel) { [weak self] _ in
                if location {
                    DispatchQueue.main.async {
                        if self?.newMapMode ?? false {
                            self?.navigationController?.popViewController(animated: true)
                        } else {
                            self?.popToMap()
                        }
                    }
                }
            }

        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    @objc func galleryTap() {
        openGallery()
    }

    @objc func imagePreviewRemove() {
        setUpPost()
    }

    @objc func photoGalleryRemove() {
        cancelFromGallery()
    }

    private func openGallery() {
        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            openGallery(assetsFetched: true)
        } else {
            askForGalleryAccess()
        }
        
    }
    
    func popToMap() {
        UploadPostModel.shared.destroy()
        DispatchQueue.main.async { self.navigationController?.popViewController(animated: true) }
    }
    
    func openGallery(assetsFetched: Bool) {
        /*
        DispatchQueue.main.async {
            let vc = PhotoGalleryController()
            if self.navigationController?.viewControllers.contains(where: { $0 is PhotoGalleryController }) ?? false { return }
            vc.fetchFromGallery = !assetsFetched
            self.navigationController?.pushViewController(vc, animated: true)
        }
        */
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

// MARK: - permissions
extension CameraViewController {
    func askForLocationAccess() {
        switch CLLocationManager().authorizationStatus {
        case .restricted, .denied, .notDetermined:
            showSettingsAlert(title: "Allow location access in Settings to post on sp0t", message: "sp0t needs your location to find spots near you", location: true)
        default:
            break
        }
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
            
        default:
            return
        }
    }
}

extension CameraViewController {
    internal func startCapture() {
        NextLevel.shared.record()
    }
    
    internal func pauseCapture() {
        NextLevel.shared.pause()
    }
    
    func endCapture(photoCapture: Bool? = false, forced: Bool? = false) {
        cancelOnDismiss = true
        if photoCapture ?? false {
            // user held down for < minimum -> capture photo
            NextLevel.shared.capturePhotoFromVideo()

        } else if let session = NextLevel.shared.session {
            if session.clips.count > 1 {
                session.mergeClips(usingPreset: AVAssetExportPresetHighestQuality) { [weak self] (url: URL?, error: Error?) in
                    
                    guard let self, let url, error == nil else {
                        return
                    }
                    
                    self.capturedVideo(path: url, forced: forced)
                }
            } else if let lastClipUrl = session.lastClipUrl {
                self.capturedVideo(path: lastClipUrl, forced: forced)

            } else if session.currentClipHasStarted {
                session.endClip { [weak self] clip, error in
                    guard let self, let url = clip?.url, error == nil else {
                        return
                    }
                    self.capturedVideo(path: url, forced: forced)
                }
            } else {
                // TODO: replace with more robust error handling
                let alertController = UIAlertController(title: "Video Capture", message: "Video clip not long enough", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
        NextLevel.shared.videoZoomFactor = 0.0
    }
    
    func capturedVideo(path: URL, forced: Bool? = false) {
        // TODO: configure passback to CreatePost
        guard let videoData = try? Data(contentsOf: path, options: .mappedIfSafe)
        else {
            self.showGenericAlert()
            return
        }
        Mixpanel.mainInstance().track(event: "CameraVideoCapture", properties: nil)
        let thumbnailImage = NextLevel.shared.session?.clips.last?.thumbnailImage ?? UIImage()
        UploadPostModel.shared.videoFromCamera = true
        let vc = ImagePreviewController()
        vc.mode = .video(url: path)
        let object = VideoObject(
            id: UUID().uuidString,
            asset: PHAsset(),
            thumbnailImage: thumbnailImage,
            videoData: videoData,
            videoPath: path,
            rawLocation: UserDataModel.shared.currentLocation,
            creationDate: Date(),
            fromCamera: true
        )
        vc.videoObject = object
        UploadPostModel.shared.videoFromCamera = true

        self.navigationController?.pushViewController(vc, animated: false)

        if forced ?? false { configureForNextTake() }
        // toggleCaptureButtons(enabled: true)
        // resetProgressView()
    }

    func capturedImage(image: UIImage) {
        print("captured image")
        let selfie = NextLevel.shared.devicePosition == .front
        let flash = NextLevel.shared.flashMode == .on
        let image = image

        Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])

        let resizedImage = image.resize(scaledToFill: CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight)) ?? UIImage()

        let imageObject = ImageObject(
            id: UUID().uuidString,
            asset: PHAsset(),
            rawLocation: UserDataModel.shared.currentLocation,
            stillImage: resizedImage,
            creationDate: Date(),
            fromCamera: true)
        UploadPostModel.shared.imageFromCamera = true

        let vc = StillImagePreviewView(imageObject: imageObject)
        if let navController = self.navigationController {
            navController.pushViewController(vc, animated: false)
        }

        // Reset manipulated values. Stop next level session to cancel any clips that may have started during photo capture
        toggleCaptureButtons(enabled: true)
        resetProgressView()
    }
}
