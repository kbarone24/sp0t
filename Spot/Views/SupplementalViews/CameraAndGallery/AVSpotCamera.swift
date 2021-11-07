//
//  AVSpotCamera.swift
//  Spot
//
//  Created by kbarone on 3/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Photos

class AVSpotCamera: NSObject {
    
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
    var previewLayer: AVCaptureVideoPreviewLayer?
    var flashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?, Bool?, Data?, URL?) -> Void)?
    var previewShown = false
        
    var liveEnabled = false
    var stillImageData: Data!
    var stillImage: UIImage!
    lazy var aliveImages: [UIImage] = []
    
    let videoFilename = "render"
    let videoFilenameExt = "mov"
    
    var outputURL: URL {
        // Use the CachesDirectory so the rendered video file sticks around as long as we need it to.
        // Using the CachesDirectory ensures the file won't be included in a backup of the app.
        let fileManager = FileManager.default
        if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        }
        fatalError("URLForDirectory() failed")
    }

    func prepare(position: CameraPosition, completionHandler: @escaping (Error?) -> Void) {
        
        
        func createCaptureSession() { captureSession = AVCaptureSession() }
        
        func configureCaptureDevices() throws {
            
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            let cameras = (session.devices.compactMap { $0 })
            if cameras.isEmpty { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                
                if camera.position == .front { frontCamera = camera }
                
                if camera.position == .back {
                    rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
            
        }
        
        func configureDeviceInputs() throws {
            
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
                        
            if position == .rear, let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                currentCameraPosition = .rear
            }
                
            else if position == .front, let frontCamera = frontCamera {

                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                currentCameraPosition = .front
                
            } else {
                throw CameraControllerError.noCamerasAvailable }
            
            captureSession.commitConfiguration()
        }
        
        func configurePhotoOutput() throws {
            
            guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            photoOutput = AVCapturePhotoOutput()
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            captureSession.sessionPreset = .photo
            
            if captureSession.canAddOutput(photoOutput!) { captureSession.addOutput(photoOutput!) }
            
            photoOutput!.isHighResolutionCaptureEnabled = true
            setLiveEnabled(gifMode: false)

            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
                
            catch {
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
    
    func setLiveEnabled(gifMode: Bool) {
        print("gif mode", gifMode)
        let live = photoOutput!.isLivePhotoCaptureSupported && gifMode
        photoOutput!.isLivePhotoCaptureEnabled = live
        photoOutput?.isLivePhotoAutoTrimmingEnabled = live
        liveEnabled = live
    }
    
    func displayPreview(on view: UIView) throws {
        
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? 82 : 2
        let cameraHeight = UIScreen.main.bounds.width * 1.5

        view.layer.insertSublayer(previewLayer!, at: 0)
        previewLayer?.frame = CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: cameraHeight)
        previewLayer?.cornerRadius = 12
        previewShown = true
    }
    
    func switchCameras() throws {
        
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
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
        
        guard let inputs = captureSession?.inputs, let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
            let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
        
        self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
        
        captureSession!.removeInput(rearCameraInput)
        
        if captureSession!.canAddInput(self.frontCameraInput!) {
            captureSession!.addInput(self.frontCameraInput!)
            print("inputs", captureSession!.inputs)
            self.currentCameraPosition = .front
        }
            
        else { throw CameraControllerError.invalidOperation }
    }
    
    func switchToRearCamera() throws {
        guard let inputs = captureSession?.inputs, let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
            let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
        
        self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        
        captureSession!.removeInput(frontCameraInput)
        
        if captureSession!.canAddInput(self.rearCameraInput!) {
            captureSession!.addInput(self.rearCameraInput!)
            
            self.currentCameraPosition = .rear
        }
            
        else { throw CameraControllerError.invalidOperation }
    }
    
    func captureImage(gifMode: Bool, completion: @escaping (UIImage?, Error?, Bool?, Data?, URL?) -> Void) {
        
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        photoCaptureCompletionBlock = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        removeFileAtURL(fileURL: outputURL)
        
        setLiveEnabled(gifMode: gifMode)
        if liveEnabled && gifMode { settings.livePhotoMovieFileURL = outputURL }
        
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension AVSpotCamera: AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
        
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime,
                     photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
            
        self.photoCaptureCompletionBlock?(stillImage, error, liveEnabled, stillImageData, outputFileURL)
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error, false, Data(), URL(string: "")) }

        let data = photo.fileDataRepresentation() ?? UIImage().pngData()
        stillImageData = data
        
        let image = UIImage(data: data ?? Data())
        stillImage = image
        
        print("live enabled here", liveEnabled)
        if !liveEnabled { self.photoCaptureCompletionBlock?(image, error, liveEnabled, data, URL(string: "")) }
    }
    
    func removeFileAtURL(fileURL: URL) {
        
        do {
            try FileManager.default.removeItem(atPath: fileURL.path)
        }
        catch _ as NSError {
            // Assume file doesn't exist.
        }
    }

}
