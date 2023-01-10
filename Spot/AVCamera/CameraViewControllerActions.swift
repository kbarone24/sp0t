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
        openGalary()
    }
    
    private func openGalary() {
        if UploadPostModel.shared.galleryAccess == .authorized || UploadPostModel.shared.galleryAccess == .limited {
            openGallery(assetsFetched: true)
        } else {
            askForGalleryAccess()
        }
    }
    
    func popToMap() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem()
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromBottom
        
        if let homeController = UIApplication.shared.keyWindow?.rootViewController as? HomeScreenContainerController {
            homeController.uploadMapReset()
        }
        /// add up to down transition on return to map
        self.navigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.popViewController(animated: false)
    }
    
    func openGallery(assetsFetched: Bool) {
        DispatchQueue.main.async {
            guard let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "PhotoGallery") as? PhotoGalleryController else { return }
            if self.navigationController?.viewControllers.contains(where: { $0 is PhotoGalleryController }) ?? false { return }
            vc.fetchFromGallery = !assetsFetched
            self.navigationController?.pushViewController(vc, animated: true)
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
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut) { [weak self] in
            self?.cameraButton.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        }
        
        NextLevel.shared.record()
    }
    
    internal func pauseCapture() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            self?.cameraButton.transform = .identity
        }) { _ in
            NextLevel.shared.pause()
        }
    }
    
    internal func endCapture() {
        if let session = NextLevel.shared.session {
            if session.clips.count > 1 {
                session.mergeClips(usingPreset: AVAssetExportPresetHighestQuality, completionHandler: { [weak self] (url: URL?, error: Error?) in
                    if let url = url {
                        self?.capturedVideo(path: url)
                    } else if let _ = error {
                        print("failed to merge clips at the end of capture \(String(describing: error))")
                    }
                })
                
            } else if let lastClipUrl = session.lastClipUrl {
                self.capturedVideo(path: lastClipUrl)
                
            } else if session.currentClipHasStarted {
                session.endClip(completionHandler: { [weak self] (clip, error) in
                    if error == nil, let url = clip?.url {
                        self?.capturedVideo(path: url)
                    } else {
                        print("Error saving video: \(error?.localizedDescription ?? "")")
                    }
                })
                
            } else {
                // prompt that the video has been saved
                let alertController = UIAlertController(title: "Video Capture", message: "Not enough video captured!", preferredStyle: .alert)
                let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(okAction)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func capturedVideo(path: URL) {
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {
                UploadPostModel.shared.imageFromCamera = true
                vc.mode = .video(url: path)
                if let navController = self.navigationController {
                    navController.pushViewController(vc, animated: false)
                }
            }
        }
    }
}
