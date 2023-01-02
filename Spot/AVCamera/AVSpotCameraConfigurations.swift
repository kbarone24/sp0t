//
//  AVSpotCameraConfigurations.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation
import CoreMedia
import UIKit

// MARK: - AVCapturePhotoCaptureDelegate

extension AVSpotCamera: AVCapturePhotoCaptureDelegate {
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
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        
        guard let captureSession, captureSession.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        photoOutput?.capturePhoto(with: settings, delegate: self)
        photoCaptureCompletionBlock = completion
    }
}

extension AVSpotCamera {
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
}

extension AVSpotCamera {
    internal func configureVideoOutput() throws {
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
        
        videoOutput = AVCaptureVideoDataOutput()
        if let videoDataOutputConnection = videoOutput?.connection(with: .video),
           videoDataOutputConnection.isVideoStabilizationSupported {
            videoDataOutputConnection.preferredVideoStabilizationMode = .cinematic
        }
        
        captureSession.beginConfiguration()
        
        guard let videoOutput else {
            captureSession.commitConfiguration()
            return
        }
        
        videoOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            self as AVCaptureVideoDataOutputSampleBufferDelegate,
            queue: DispatchQueue(
                label: "videoQueue",
                qos: .userInteractive
            )
        )
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        audioOutput = AVCaptureAudioDataOutput()
        
        if let audioOutput, captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }
        
        guard let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
              let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice)
        else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(audioDeviceInput) {
            captureSession.addInput(audioDeviceInput)
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
        videoOutput.connections.forEach {
            $0.automaticallyAdjustsVideoMirroring = false
            $0.isVideoMirrored = self.currentCameraPosition == .front
        }
        
        captureSession.sessionPreset = .high
        captureSession.commitConfiguration()
    }

    private func setUpWriter() {
        outputFileLocation = videoFileLocation()
        
        guard let outputFileLocation else {
            return
        }
        
        videoWriter = try? AVAssetWriter(outputURL: outputFileLocation, fileType: .mp4)
        
        // add video input
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 720,
            AVVideoHeightKey: 1_280,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_300_000
            ]
        ])
        
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        guard let videoWriterInput, let videoWriter else {
            return
        }
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        // add audio input
        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: nil)
        
        audioWriterInput?.expectsMediaDataInRealTime = true
        
        guard let audioWriterInput else {
            return
        }
        
        if videoWriter.canAdd(audioWriterInput) {
            videoWriter.add(audioWriterInput)
        }
        
        videoWriter.startWriting()
    }
    
    func canWrite() -> Bool {
        return isRecording && videoWriter != nil && videoWriter?.status == .writing
    }
    
    // video file location method
    func videoFileLocation() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        let filePath = documentsURL.appendingPathComponent("tempMovie.mp4")
        if FileManager.default.fileExists(atPath: filePath.absoluteString) {
            do {
                try FileManager.default.removeItem(at: filePath)
            } catch {
                photoCaptureCompletionBlock?(nil, error)
            }
        }
        
        return documentsURL
    }
    
    func startRecordingVideo() {
        guard !isRecording else { return }
        isRecording = true
        sessionAtSourceTime = nil
        setUpWriter()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func endRecordingVideo() {
        guard isRecording else { return }
        isRecording = false
        videoWriterInput?.markAsFinished()
        
        videoWriter?.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AVSpotCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        
        self.currentCIImage = ciImage
        
        previewView.draw()
        
        // get UIImage out of CIImage
        let uiImage = UIImage(ciImage: ciImage)
        
        guard takePicture else {
            return // We have nothing to do with the image buffer
        }
        
        DispatchQueue.main.async {
            self.capturedImage = uiImage
            self.takePicture = false
            self.photoCaptureCompletionBlock?(uiImage, nil)
        }
    }
}
