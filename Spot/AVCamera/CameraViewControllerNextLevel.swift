//
//  CameraViewControllerNextLevel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import NextLevel
import AVFoundation
import UIKit
import Photos
import Mixpanel

// MARK: - NextLevelPhotoDelegate
extension CameraViewController: NextLevelPhotoDelegate {
    func nextLevel(_ nextLevel: NextLevel, output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, photoConfiguration: NextLevelPhotoConfiguration) { }
    
    func nextLevel(_ nextLevel: NextLevel, output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings, photoConfiguration: NextLevelPhotoConfiguration) { }
    
    func nextLevel(_ nextLevel: NextLevel, output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings, photoConfiguration: NextLevelPhotoConfiguration) { }
    
    func nextLevel(_ nextLevel: NextLevel, didFinishProcessingPhoto photo: AVCapturePhoto, photoDict: [String: Any], photoConfiguration: NextLevelPhotoConfiguration) {
        self.cameraButton.transform = .identity
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            return
        }
        capturedImage(image: image)
    }
    
    func nextLevelDidCompletePhotoCapture(_ nextLevel: NextLevel) { }
    
    func nextLevel(_ nextLevel: NextLevel, didFinishProcessingPhoto photo: AVCapturePhoto) {
    }
    
}

// MARK: - NextLevelVideoDelegate
extension CameraViewController: NextLevelVideoDelegate {
    
    // video zoom
    func nextLevel(_ nextLevel: NextLevel, didUpdateVideoZoomFactor videoZoomFactor: Float) {}
    
    // video frame processing
    func nextLevel(_ nextLevel: NextLevel, willProcessRawVideoSampleBuffer sampleBuffer: CMSampleBuffer, onQueue queue: DispatchQueue) {}
    
    func nextLevel(_ nextLevel: NextLevel, willProcessFrame frame: AnyObject, timestamp: TimeInterval, onQueue queue: DispatchQueue) {
    }
    
    // enabled by isCustomContextVideoRenderingEnabled
    func nextLevel(_ nextLevel: NextLevel, renderToCustomContextWithImageBuffer imageBuffer: CVPixelBuffer, onQueue queue: DispatchQueue) {
    }
    
    // video recording session
    func nextLevel(_ nextLevel: NextLevel, didSetupVideoInSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didSetupAudioInSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didStartClipInSession session: NextLevelSession) {
        if flashMode == .on {
            if nextLevel.devicePosition == .back {
                nextLevel.torchMode = .on
            } else {
                frontFlashView.isHidden = false
            }
        }
    }
    func nextLevel(_ nextLevel: NextLevel, didCompleteClip clip: NextLevelClip, inSession session: NextLevelSession) {
        nextLevel.torchMode = .off
        frontFlashView.isHidden = true
    }
    func nextLevel(_ nextLevel: NextLevel, didAppendVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didAppendAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didAppendVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didSkipVideoPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: TimeInterval, inSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didSkipVideoSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {}
    func nextLevel(_ nextLevel: NextLevel, didSkipAudioSampleBuffer sampleBuffer: CMSampleBuffer, inSession session: NextLevelSession) {}
    
    func nextLevel(_ nextLevel: NextLevel, didCompleteSession session: NextLevelSession) {
        // called when a configuration time limit is specified
        self.endCapture(forced: true)
    }
    
    // video frame photo
    func nextLevel(_ nextLevel: NextLevel, didCompletePhotoCaptureFromVideoFrame photoDict: [String: Any]?) {
        if let dictionary = photoDict,
           let photoData = dictionary[NextLevelPhotoJPEGKey] as? Data,
           let photoImage = UIImage(data: photoData) {
            capturedImage(image: photoImage)
        }
    }
    
    func capturedImage(image: UIImage) {
        let selfie = NextLevel.shared.devicePosition == .front
        let flash = NextLevel.shared.flashMode == .on
        let image = image
        
        Mixpanel.mainInstance().track(event: "CameraStillCapture", properties: ["flash": flash, "selfie": selfie])

        let resizedImage = image.resize(scaledToFill: CGSize(width: UIScreen.main.bounds.width, height: self.cameraHeight)) ?? UIImage()

        let vc = ImagePreviewController()
        let object = ImageObject(
            id: UUID().uuidString,
            asset: PHAsset(),
            rawLocation: UserDataModel.shared.currentLocation,
            stillImage: resizedImage,
            animationImages: [],
            animationIndex: 0,
            directionUp: true,
            gifMode: false,
            creationDate: Date(),
            fromCamera: true)
        vc.imageObject = object
        UploadPostModel.shared.imageFromCamera = true
        vc.mode = .image

        if let navController = self.navigationController {
            navController.pushViewController(vc, animated: false)
        }

        // Reset manipulated values. Stop next level session to cancel any clips that may have started during photo capture
        toggleCaptureButtons(enabled: true)
        resetProgressView()
        NextLevel.shared.stop()
    }
}

// MARK: - NextLevelFlashDelegate
extension CameraViewController: NextLevelFlashAndTorchDelegate {
    func nextLevelDidChangeFlashMode(_ nextLevel: NextLevel) {}
    func nextLevelDidChangeTorchMode(_ nextLevel: NextLevel) {}
    func nextLevelFlashActiveChanged(_ nextLevel: NextLevel) {}
    func nextLevelTorchActiveChanged(_ nextLevel: NextLevel) {}
    func nextLevelFlashAndTorchAvailabilityChanged(_ nextLevel: NextLevel) {}
}

extension CameraViewController: NextLevelPreviewDelegate {
    // preview
    func nextLevelWillStartPreview(_ nextLevel: NextLevel) {}
    func nextLevelDidStopPreview(_ nextLevel: NextLevel) {}
}

extension CameraViewController: NextLevelDeviceDelegate {
    // position, orientation
    func nextLevelDevicePositionWillChange(_ nextLevel: NextLevel) {
        // Capture while camera flip is happening causes camera to freeze up -> Disable user interaction until flip is complete
        DispatchQueue.main.async { self.view.isUserInteractionEnabled = false }
    }
    
    func nextLevelDevicePositionDidChange(_ nextLevel: NextLevel) {}
    
    func nextLevel(_ nextLevel: NextLevel, didChangeDeviceOrientation deviceOrientation: NextLevelDeviceOrientation) {
        nextLevel.mirroringMode = .auto
        DispatchQueue.main.async { self.view.isUserInteractionEnabled = true }
    }
    
    // format
    func nextLevel(_ nextLevel: NextLevel, didChangeDeviceFormat deviceFormat: AVCaptureDevice.Format) { }
    
    // aperture
    func nextLevel(_ nextLevel: NextLevel, didChangeCleanAperture cleanAperture: CGRect) {}
    
    // lens
    func nextLevel(_ nextLevel: NextLevel, didChangeLensPosition lensPosition: Float) {}
    
    // focus, exposure, white balance
    func nextLevelWillStartFocus(_ nextLevel: NextLevel) {}
    func nextLevelDidStopFocus(_  nextLevel: NextLevel) {}
    func nextLevelWillChangeExposure(_ nextLevel: NextLevel) {}
    func nextLevelDidChangeExposure(_ nextLevel: NextLevel) {}
    
    func nextLevelWillChangeWhiteBalance(_ nextLevel: NextLevel) {}
    func nextLevelDidChangeWhiteBalance(_ nextLevel: NextLevel) {}
}

// MARK: - NextLevelDelegate
extension CameraViewController: NextLevelDelegate {
    
    // permission
    func nextLevel(_ nextLevel: NextLevel, didUpdateAuthorizationStatus status: NextLevelAuthorizationStatus, forMediaType mediaType: AVMediaType) {}
    
    // configuration
    func nextLevel(_ nextLevel: NextLevel, didUpdateVideoConfiguration videoConfiguration: NextLevelVideoConfiguration) {}
    
    func nextLevel(_ nextLevel: NextLevel, didUpdateAudioConfiguration audioConfiguration: NextLevelAudioConfiguration) {}
    
    // session
    func nextLevelSessionWillStart(_ nextLevel: NextLevel) {}
    func nextLevelSessionDidStart(_ nextLevel: NextLevel) {}
    func nextLevelSessionDidStop(_ nextLevel: NextLevel) {}
    
    // interruption
    func nextLevelSessionWasInterrupted(_ nextLevel: NextLevel) {}
    func nextLevelSessionInterruptionEnded(_ nextLevel: NextLevel) {}
    
    // mode
    func nextLevelCaptureModeWillChange(_ nextLevel: NextLevel) {}
    func nextLevelCaptureModeDidChange(_ nextLevel: NextLevel) {}
}
