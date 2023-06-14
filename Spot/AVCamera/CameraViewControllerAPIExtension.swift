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
import Mixpanel
import Photos
import CoreData
import Firebase
import FirebaseFirestore

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
            title: "Something went wrong",
            message: "Try again",
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        present(alert, animated: true, completion: nil)
    }
}

extension CameraViewController {
    @objc internal func takePhoto() {
        capturePhoto()
    }
    
    func capturePhoto() {
        // play system camera shutter sound
        AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1_108), nil)
        NextLevel.shared.capturePhotoFromVideo()
        cameraButton.enabled = false
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
        if cancelOnDismiss { return }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.fillProgressView()
            }
        }
    }

    func toggleCaptureButtons(enabled: Bool) {
        if enabled {
            // don't show progress view immediately when capture begins, only show after user has held for 1 second
            progressView.isHidden = true
            saveButton.isHidden = true
        } else {
            nextStepsLabel.isHidden = true
        }

        instructionsLabel.isHidden = !enabled
        galleryButton.isHidden = !enabled
        galleryText.isHidden = !enabled

        cameraButton.enabled = enabled

        nextButton.isHidden = !enabled
        saveButton.isHidden = !enabled
        cancelButton.isHidden = !enabled
        backButton.isHidden = !enabled
        cameraRotateButton.isHidden = !enabled
        flashButton.isHidden = !enabled
        cameraDeviceView.isHidden = !enabled
        undoClipButton.isHidden = !enabled
        doubleTap.isEnabled = enabled
    }

    func configureForNextTake() {
        videoPressStartTime = nil
        cameraButton.enabled = true
        nextButton.isHidden = false
        undoClipButton.isHidden = false

        saveButton.isHidden = false
        saveButton.saved = false
        backButton.isHidden = false
        cancelButton.isHidden = false
        backButton.isHidden = false
        cameraRotateButton.isHidden = false
        flashButton.isHidden = false
        undoClipButton.isHidden = false
        doubleTap.isEnabled = true

        cameraDeviceView.isHidden = NextLevel.shared.devicePosition == .front

        progressViewCachedPosition = progressView.progress
        addClipMarker()
        addNextSteps()
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

    private func addClipMarker() {
        let clipMarker = UIView()
        clipMarker.backgroundColor = .white
        clipMarker.tag = 1
        progressView.addSubview(clipMarker)
        let leadingOffset = progressView.frame.width * CGFloat(progressViewCachedPosition ?? 0)
        clipMarker.snp.makeConstraints {
            $0.leading.equalTo(leadingOffset)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(2)
            $0.height.equalTo(18)
        }
    }

    private func addNextSteps() {
        let cachedPosition = progressViewCachedPosition
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            if self?.progressViewCachedPosition == cachedPosition, cachedPosition ?? 0 < 0.95, !NextLevel.shared.isRecording, !(self?.cancelOnDismiss ?? true) {
                self?.nextStepsLabel.isHidden = false
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CameraViewController: UIGestureRecognizerDelegate {
    @objc internal func handleLongPressGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if cancelOnDismiss { return }
        switch gestureRecognizer.state {
        case .began:
            toggleCaptureButtons(enabled: false)
            panToZoom.isEnabled = true
            pinchToZoom.isEnabled = false
            NextLevel.shared.captureMode = .video

            // record start time in milliseconds
            videoPressStartTime = Date().timeIntervalSince1970
            fillProgressView()

            startCapture()
            _longPressStartPoint = gestureRecognizer.location(in: self.view)

        case .changed:
            let newPoint = gestureRecognizer.location(in: self.view)
            let adjust = (_longPressStartPoint.y / newPoint.y) - 1
            NextLevel.shared.videoZoomFactor *= (1 + Float(adjust) * 2)
            _longPressStartPoint = newPoint

        case .ended, .cancelled, .failed:
            panToZoom.isEnabled = false
            pinchToZoom.isEnabled = true
            pauseCapture()
            if !checkForPhotoCapture() {
                configureForNextTake()
            }

        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        if gestureRecognizer is UILongPressGestureRecognizer {
            return adjustedCameraButtonFrame.contains(location)
        }
        if gestureRecognizer is UITapGestureRecognizer {
            return !adjustedCameraButtonFrame.contains(location)
        }

        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UILongPressGestureRecognizer || otherGestureRecognizer is UILongPressGestureRecognizer
    }
}
