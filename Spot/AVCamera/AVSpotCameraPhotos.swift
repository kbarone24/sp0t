//
//  AVSpotCameraPhotos.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation
import UIKit

extension AVSpotCamera {
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        
        guard let captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        photoOutput?.capturePhoto(with: settings, delegate: self)
        photoCaptureCompletionBlock = completion
    }
    
    func captureGIF(completion: @escaping ([UIImage]) -> Void) {
        
        guard let captureSession, captureSession.isRunning else { completion([]); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        start = CFAbsoluteTimeGetCurrent()
        gifCaptureCompletionBlock = completion
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension AVSpotCamera: AVCapturePhotoCaptureDelegate {
    
    func configureDeviceInputs(position: CameraPosition) throws {
        guard let captureSession else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        if position == .rear, let rearCamera = self.rearCamera {
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            guard let rearCameraInput else { return }
            
            if captureSession.canAddInput(rearCameraInput) {
                captureSession.addInput(rearCameraInput)
            }
            
            currentCameraPosition = .rear
            
        } else if position == .front, let frontCamera = frontCamera {
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            guard let frontCameraInput else { return }
            
            if captureSession.canAddInput(frontCameraInput) {
                captureSession.addInput(frontCameraInput)
            } else {
                throw CameraControllerError.inputsAreInvalid
            }
            
            currentCameraPosition = .front
            
        } else {
            throw CameraControllerError.noCamerasAvailable
        }
    }
    
    func configureCaptureDevices() throws {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        let cameras = session.devices.compactMap { $0 }
        
        if cameras.isEmpty {
            throw CameraControllerError.noCamerasAvailable
        }
        
        for camera in cameras {
            
            if camera.position == .front {
                frontCamera = camera
            }
            
            if camera.position == .back {
                rearCamera = camera
            }
            
            try camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            camera.unlockForConfiguration()
        }
    }
    
    func configurePhotoOutput() throws {
        guard let captureSession = captureSession else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        photoOutput = AVCapturePhotoOutput()
        guard let photoOutput else { return }
        
        photoOutput.setPreparedPhotoSettingsArray(
            [
                AVCapturePhotoSettings(
                    format: [
                        AVVideoCodecKey: AVVideoCodecType.jpeg
                    ]
                )
            ],
            completionHandler: nil
        )
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            self.photoCaptureCompletionBlock?(nil, error)
            return
        }
        
        let data = photo.fileDataRepresentation() ?? UIImage().pngData()
        let image = UIImage(data: data ?? Data())
        self.photoCaptureCompletionBlock?(image, nil)
    }
}
