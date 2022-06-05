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
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var previewShown = false
    
    var start: CFAbsoluteTime!
    var gifCaptureCompletionBlock: (([UIImage]) -> Void)?
    lazy var aliveImages: [UIImage] = []
        
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
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        func configurePhotoOutput() throws {
            
            guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            photoOutput = AVCapturePhotoOutput()
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(photoOutput!) { captureSession.addOutput(photoOutput!) }
            
            captureSession.startRunning()
        }
        
      /*  func configureVideoOutput() throws {
            
            guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            videoOutput = AVCaptureVideoDataOutput()
            if let videoDataOutputConnection = videoOutput?.connection(with: .video), videoDataOutputConnection.isVideoStabilizationSupported {
                videoDataOutputConnection.preferredVideoStabilizationMode = .cinematic
                
            }
            
            videoOutput!.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
            videoOutput!.alwaysDiscardsLateVideoFrames = true
            videoOutput!.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
            
            if captureSession.canAddOutput(videoOutput!) {  captureSession.addOutput(videoOutput!)  }
        } */
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
           //     try configureVideoOutput()
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
    
    
    
    func displayPreview(on view: UIView) throws {
        
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        
        let cameraAspect: CGFloat = UserDataModel.shared.screenSize == 0 ? 1.7 : UserDataModel.shared.screenSize == 1 ? 1.78 : 1.85
        let cameraHeight = UIScreen.main.bounds.width * cameraAspect

        view.layer.insertSublayer(previewLayer!, at: 0)
        previewLayer?.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: cameraHeight)
        previewLayer?.cornerRadius = 15
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

   func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
    
       guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
    
       let settings = AVCapturePhotoSettings()
       settings.flashMode = self.flashMode
    
       photoOutput?.capturePhoto(with: settings, delegate: self)
       photoCaptureCompletionBlock = completion
   }
    
    func captureGIF(completion: @escaping ([UIImage]) -> Void) {
        
        guard let captureSession = captureSession, captureSession.isRunning else { completion([]); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        start = CFAbsoluteTimeGetCurrent()
        gifCaptureCompletionBlock = completion
    }
    
}

extension AVSpotCamera: AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        /// start a timer when alive capture initiated
        /// show if timer >  .0.12, take image as capture, pass to avcameracontroller, reset timer
        /// stop timer on 10th capture
        
        if start != nil {
            
            let diff = CFAbsoluteTimeGetCurrent() - start
            if diff > 0.08 {
                
                let orientation = currentCameraPosition == .front ? UIImage.Orientation.leftMirrored : UIImage.Orientation.right
                var image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
                image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: orientation)

                aliveImages.append(image)
                start = CFAbsoluteTimeGetCurrent()
                
                if aliveImages.count == 10 {
                    gifCaptureCompletionBlock?(aliveImages)
                    start = nil
                    aliveImages = []
                }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }

        let data = photo.fileDataRepresentation() ?? UIImage().pngData()
        let image = UIImage(data: data ?? Data())
        self.photoCaptureCompletionBlock?(image, nil)
    }
    
    func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage
    {
      // Get a CMSampleBuffer's Core Video image buffer for the media data
      let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      // Lock the base address of the pixel buffer
      CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);


      // Get the number of bytes per row for the pixel buffer
      let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!);

      // Get the number of bytes per row for the pixel buffer
      let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!);
      // Get the pixel buffer width and height
      let width = CVPixelBufferGetWidth(imageBuffer!);
      let height = CVPixelBufferGetHeight(imageBuffer!);

      // Create a device-dependent RGB color space
      let colorSpace = CGColorSpaceCreateDeviceRGB();

      // Create a bitmap graphics context with the sample buffer data
      var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
      bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
      //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
      let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
      // Create a Quartz image from the pixel data in the bitmap graphics context
      let quartzImage = context?.makeImage();
      // Unlock the pixel buffer
      CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly);

      // Create an image object from the Quartz image
      let image = UIImage.init(cgImage: quartzImage!);

      return (image)
        
    }
    
}

extension AVCaptureDevice {

    /// toggles the device's flashlight, if possible
    func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            let torchOn = !device.isTorchActive
            try device.setTorchModeOn(level: 1.0)
            device.torchMode = torchOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Error toggling Flashlight: \(error)")
        }
    }
}


///source: https://www.appcoda.com/avfoundation-swift-guide/
extension CMSampleBuffer {
    func image(orientation: UIImage.Orientation,
               scale: CGFloat = 1.0) -> UIImage? {
        if let buffer = CMSampleBufferGetImageBuffer(self) {
            let ciImage = CIImage(cvPixelBuffer: buffer)

            return UIImage(ciImage: ciImage,
                           scale: scale,
                           orientation: orientation)
        }

        return nil
    }
}
///https://stackoverflow.com/questions/15726761/make-an-uiimage-from-a-cmsamplebuffer
