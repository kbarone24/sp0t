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
    
    @objc internal func handlePhotoTapGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        capture()
    }
    
    func capture() {
        // play system camera shutter sound
        AudioServicesPlaySystemSoundWithCompletion(SystemSoundID(1_108), nil)
        NextLevel.shared.captureMode = .photo
        NextLevel.shared.capturePhoto()
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
}

// MARK: - UIGestureRecognizerDelegate

extension CameraViewController: UIGestureRecognizerDelegate {

    @objc internal func handleLongPressGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        NextLevel.shared.captureMode = .video
        
        switch gestureRecognizer.state {
        case .began:
            self.startCapture()
            self._panStartPoint = gestureRecognizer.location(in: self.view)
            self._panStartZoom = CGFloat(NextLevel.shared.videoZoomFactor)
            
        case .changed:
            let newPoint = gestureRecognizer.location(in: self.view)
            let scale = (self._panStartPoint.y / newPoint.y)
            let newZoom = (scale * self._panStartZoom)
            NextLevel.shared.videoZoomFactor = Float(newZoom)
            
        case .ended:
            break
            
        case .cancelled:
            break
            
        case .failed:
            self.pauseCapture()
            fallthrough
            
        default:
            break
        }
    }
}
