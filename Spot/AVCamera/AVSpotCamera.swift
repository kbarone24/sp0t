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
import MetalKit

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
    
    var flashMode: AVCaptureDevice.FlashMode = .off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var previewShown = false
    
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioWriterInput: AVAssetWriterInput?
    var outputFileLocation: URL?
    var isRecording = false
    var sessionAtSourceTime: CMTime?
    
    private(set) var metalCommandQueue: MTLCommandQueue?
    private(set) var metalDevice: MTLDevice?
    private(set) var ciContext: CIContext?
    var currentCIImage: CIImage?
    var capturedImage: UIImage?
    var takePicture = false
    
    let previewView: MTKView
    
    override init() {
        previewView = MTKView()
        previewView.layer.contentsGravity = .resizeAspectFill
        previewView.layer.cornerRadius = 5.0
        previewView.isPaused = true
        previewView.enableSetNeedsDisplay = false
        previewView.framebufferOnly = false
        
        metalDevice = MTLCreateSystemDefaultDevice()
        previewView.device = metalDevice
        metalCommandQueue = metalDevice?.makeCommandQueue()
        
        if let metalDevice {
            ciContext = CIContext(mtlDevice: metalDevice)
        }
        
        super.init()
        previewView.delegate = self
    }
    
    func prepare(position: CameraPosition, completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                self?.captureSession = AVCaptureSession()
                try self?.configureCaptureDevices()
                try self?.configureDeviceInputs(position: position)
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
        guard let captureSession = self.captureSession, captureSession.isRunning else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        view.insertSubview(previewView, at: 0)
        
        let cameraAspect: CGFloat = UserDataModel.shared.maxAspect
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect
        
        previewView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.height.equalTo(cameraHeight)
            make.width.equalTo(UIScreen.main.bounds.width)
        }
        
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
        
        guard let videoOutput else {
            captureSession.commitConfiguration()
            return
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
        videoOutput.connections.forEach {
            $0.automaticallyAdjustsVideoMirroring = false
            $0.isVideoMirrored = self.currentCameraPosition == .front
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
