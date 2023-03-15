//
//  CameraViewControllerAPIExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import NextLevel
import AVFoundation
import UIKit
import JPSVolumeButtonHandler
import Mixpanel
import Photos
import CoreData
import Firebase

extension CameraViewController {
    func getFailedUploads() {
        guard let coreDataService = try? ServiceContainer.shared.service(for: \.coreDataService) else {
            return
        }
        
        coreDataService.fetchFailedImageUploads { [weak self] postDraft, postImage in
            guard let self, let postDraft, let postImage else {
                return
            }
            
            self.postDraft = postDraft
            
            DispatchQueue.main.async {
                self.failedPostView.coverImage.image = postImage
                self.view.addSubview(self.failedPostView)
                self.failedPostView.snp.makeConstraints {
                    $0.edges.equalToSuperview()
                }
            }
        }
    }
    
    func deletePostDraft() {
        guard let coreDataService = try? ServiceContainer.shared.service(for: \.coreDataService),
              let timeStampID = postDraft?.timestamp
        else {
            return
        }
        
        coreDataService.deletePostDraft(timestampID: timeStampID)
        failedPostView.removeFromSuperview()
    }
    
    func uploadPostDraft() {
        guard let coreDataService = try? ServiceContainer.shared.service(for: \.coreDataService) else {
            return
        }
        
        coreDataService.uploadPostDraft(postDraft: postDraft, parentView: self.view, progressFill: self.failedPostView.progressFill) { [weak self] successful in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if successful {
                    self?.showSuccessAlert()
                } else {
                    self?.showFailAlert()
                }
            }
        }
    }
    
    func showSuccessAlert() {
        deletePostDraft()
        let alert = UIAlertController(
            title: "Post successfully uploaded!",
            message: "",
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        
        present(alert, animated: true, completion: nil)
    }
    
    func showFailAlert() {
        let alert = UIAlertController(
            title: "Upload failed",
            message: "Post saved to your drafts",
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        present(alert, animated: true, completion: nil)
    }
    
    func showGenericAlert() {
        let alert = UIAlertController(
            title: "Something went wrong.",
            message: "Try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        present(alert, animated: true, completion: nil)
    }
    
    func getMap(mapID: String, completion: @escaping (_ map: CustomMap, _ failed: Bool) -> Void) {
        
        let emptyMap = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: "",
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: []
        )
        
        if mapID.isEmpty {
            completion(emptyMap, false)
            return
        }
        
        let db = Firestore.firestore()
        let mapRef = db.collection("maps").document(mapID)
        
        mapRef.getDocument { (doc, _) in
            do {
                let unwrappedInfo = try doc?.data(as: CustomMap.self)
                guard var mapInfo = unwrappedInfo else { completion(emptyMap, true); return }
                mapInfo.id = mapID
                completion(mapInfo, false)
                return
            } catch {
                completion(emptyMap, true)
                return
            }
        }
    }
}

extension CameraViewController {
    @objc internal func takePhoto() {
        print("tap capture")
        capturePhoto()
    }
    
    func capturePhoto() {
        // play system camera shutter sound
        AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1_108), nil)
        NextLevel.shared.capturePhotoFromVideo()
        cameraButton.isEnabled = false
    }

    @objc internal func handleFocusTapGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        let tapPoint = gestureRecognizer.location(in: self.cameraView)
        pointInCamera(center: tapPoint)
        let adjustedPoint = NextLevel.shared.previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
        NextLevel.shared.focusExposeAndAdjustWhiteBalance(atAdjustedPoint: adjustedPoint)
    }
    
    private func pointInCamera(center: CGPoint) {
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: 30.0,
            startAngle: 0.0,
            endAngle: CGFloat(Double.pi * 2),
            clockwise: true
        )
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 3.0
        
        view.layer.addSublayer(shapeLayer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shapeLayer.removeFromSuperlayer()
        }
    }

    private func fillProgressView() {
        if let videoPressStartTime {
            let currentTime = Date().timeIntervalSince1970
            var progressFillAmount = Float((currentTime - videoPressStartTime) / Double(maxVideoDuration.value))
            if let progressViewCachedPosition {
                progressFillAmount += progressViewCachedPosition
            }
            let timeOfProgress = Float(maxVideoDuration.value) * progressFillAmount
            if timeOfProgress > 0.5 {
                // dont show progress view on image capture (short tap)
                progressView.isHidden = false
                progressView.setProgress(progressFillAmount, animated: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.fillProgressView()
            }
        }
    }

    func toggleCaptureButtons(enabled: Bool) {
        if enabled {
            // don't show progress view immediately when capture begins, only show after user has held for 1 second
            progressView.isHidden = true
        }
        instructionsLabel.isHidden = !enabled
        cameraButton.isEnabled = enabled
        nextButton.isHidden = true
    }

    private func configureForNextTake() {
        progressViewCachedPosition = progressView.progress
        videoPressStartTime = nil
        cameraButton.isEnabled = true
        nextButton.isHidden = false
    }

    private func checkForPhotoCapture() -> Bool {
        // force end capture if user tapped instead of press
        let timeOfProgress = Float(maxVideoDuration.value) * progressView.progress
        if timeOfProgress < 0.5 {
            endCapture(photoCapture: true)
            return true
        }
        return false
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CameraViewController: UIGestureRecognizerDelegate {
    @objc internal func handleLongPressGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            toggleCaptureButtons(enabled: false)
            NextLevel.shared.captureMode = .video

            // record start time in milliseconds
            videoPressStartTime = Date().timeIntervalSince1970
            fillProgressView()

            startCapture()
            _panStartPoint = gestureRecognizer.location(in: self.view)
            _panStartZoom = CGFloat(NextLevel.shared.videoZoomFactor)
            
        case .changed:
            let newPoint = gestureRecognizer.location(in: self.view)
            let scale = (_panStartPoint.y / newPoint.y)
            let newZoom = (scale * _panStartZoom)
            NextLevel.shared.videoZoomFactor = Float(newZoom)

        case .ended, .cancelled, .failed:
            pauseCapture()
            if !checkForPhotoCapture() {
                configureForNextTake()
            }

        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer
    }
}
