//
//  AVSpotCamera.swift
//  Spot
//
//  Created by kbarone on 3/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import AVFoundation
import CoreMedia
import Photos
import UIKit

final class AVSpotCamera: NSObject {
    
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var photoOutput: AVCapturePhotoOutput?
    var videoOutput: AVCaptureVideoDataOutput?
    var audioOutput: AVCaptureAudioDataOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var flashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var previewShown = false
    
    var start: CFAbsoluteTime?
    var gifCaptureCompletionBlock: (([UIImage]) -> Void)?
    lazy var aliveImages: [UIImage] = []
    
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var outputFileLocation: URL?
    var isRecording = false
    var sessionAtSourceTime: CMTime?
    
    func prepare(position: CameraPosition, completionHandler: @escaping (Error?) -> Void) {
        
        DispatchQueue(label: "prepare").async { [weak self] in
            do {
                self?.captureSession = AVCaptureSession()
                try self?.configureCaptureDevices()
                try self?.configureDeviceInputs(position: position)
                try self?.configurePhotoOutput()
                self?.captureSession?.startRunning()
                try self?.configureVideoOutput()
            } catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) throws {
        
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        guard let previewLayer else { throw CameraControllerError.captureSessionIsMissing }
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        
        let cameraAspect: CGFloat = UserDataModel.shared.maxAspect
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cameraHeight)
        previewLayer.cornerRadius = 5
        previewShown = true
    }
    
    func switchCameras() throws {
        
        guard let currentCameraPosition,
              let captureSession,
              captureSession.isRunning else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        captureSession.beginConfiguration()
        
        switch currentCameraPosition {
            
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        captureSession.commitConfiguration()
    }
    
    func switchToFrontCamera() throws {
        
        guard let captureSession,
              case let inputs = captureSession.inputs,
              let rearCameraInput = self.rearCameraInput,
              inputs.contains(rearCameraInput),
              let frontCamera
        else {
            throw CameraControllerError.invalidOperation
        }
        
        self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
        
        captureSession.removeInput(rearCameraInput)
        
        guard let frontCameraInput else {
            throw CameraControllerError.invalidOperation
        }
        
        if captureSession.canAddInput(frontCameraInput) {
            captureSession.addInput(frontCameraInput)
            
            self.currentCameraPosition = .front
        } else {
            throw CameraControllerError.invalidOperation
        }
    }
    
    func switchToRearCamera() throws {
        guard let inputs = captureSession?.inputs,
              let frontCameraInput = self.frontCameraInput,
              inputs.contains(frontCameraInput),
              let rearCamera = self.rearCamera,
              let captureSession
        else {
            throw CameraControllerError.invalidOperation
        }
        
        self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        
        captureSession.removeInput(frontCameraInput)
        
        guard let rearCameraInput else {
            throw CameraControllerError.invalidOperation
        }
        
        if captureSession.canAddInput(rearCameraInput) {
            captureSession.addInput(rearCameraInput)
            self.currentCameraPosition = .rear
        } else {
            throw CameraControllerError.invalidOperation
        }
    }
}
