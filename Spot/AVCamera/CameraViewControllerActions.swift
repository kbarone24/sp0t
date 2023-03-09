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
import JPSVolumeButtonHandler
import Mixpanel
import Photos
import CoreData
import Firebase

extension CameraViewController {
    @objc func galleryTap() {
        openGallery()
    }

    @objc func imagePreviewRemove() {
        print("set up post")
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
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
    
    func openGallery(assetsFetched: Bool) {
        DispatchQueue.main.async {
            let vc = PhotoGalleryController()
            if self.navigationController?.viewControllers.contains(where: { $0 is PhotoGalleryController }) ?? false { return }
            vc.fetchFromGallery = !assetsFetched
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func cancelFromGallery() {
        print("cancel from gallery")
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
            showSettingsAlert(title: "Allow location access in Settings to post on sp0t", message: "sp0t needs your location to pin your posts on the map", location: true)
            
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
    
    func endCapture() {
        if let session = NextLevel.shared.session {
            if session.clips.count > 1 {
                session.mergeClips(usingPreset: AVAssetExportPresetHighestQuality) { [weak self] (url: URL?, error: Error?) in
                    
                    guard let self, let url, error == nil else {
                        return
                    }
                    
                    self.capturedVideo(path: url)
                }
            } else if let lastClipUrl = session.lastClipUrl {
                self.capturedVideo(path: lastClipUrl)
                
            } else if session.currentClipHasStarted {
                session.endClip { [weak self] clip, error in
                    
                    guard let self, let url = clip?.url, error == nil else {
                        return
                    }
                    self.capturedVideo(path: url)
                }
            } else {
                // prompt that the video has been saved
                let alertController = UIAlertController(title: "Video Capture", message: "Not enough video captured!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
        progressView.isHidden = true
        NextLevel.shared.videoZoomFactor = 0.0
    }
    
    func capturedVideo(path: URL) {
        guard let videoData = try? Data(contentsOf: path, options: .mappedIfSafe)
        else {
            self.showGenericAlert()
            return
        }

        UploadPostModel.shared.videoFromCamera = true
        let vc = ImagePreviewController()
        vc.mode = .video(url: path)
        let object = VideoObject(
            id: UUID().uuidString,
            asset: PHAsset(),
            videoData: videoData,
            videoPath: path,
            rawLocation: UserDataModel.shared.currentLocation,
            creationDate: Date(),
            fromCamera: true
        )
        vc.videoObject = object
        UploadPostModel.shared.videoFromCamera = true
        
        self.navigationController?.pushViewController(vc, animated: false)
    }
}
