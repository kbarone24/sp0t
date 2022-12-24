//
//  AVSpotCameraVideo.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation
import CoreMedia
import UIKit

extension AVSpotCamera {
    
    private func setUpWriter() {
        outputFileLocation = videoFileLocation()
        videoWriter = try? AVAssetWriter(outputURL: outputFileLocation!, fileType: .mp4)
        
        // add video input
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 720,
            AVVideoHeightKey: 1280,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2300000,
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
    
    //video file location method
    
    func videoFileLocation() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as URL
        let filePath = documentsURL.appendingPathComponent("tempMovie.mp4")
        if FileManager.default.fileExists(atPath: filePath.absoluteString) {
            do {
                try FileManager.default.removeItem(at: filePath)
            }
            catch {
                // exception while deleting old cached file
                // ignore error if any
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
        
        /// start a timer when alive capture initiated
        /// show if timer >  .0.12, take image as capture, pass to avcameracontroller, reset timer
        /// stop timer on 10th capture
        
        guard let start else { return }
        
        let writable = canWrite()

        if writable, sessionAtSourceTime == nil,
           case let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) {
            
            sessionAtSourceTime = time
            videoWriter?.startSession(atSourceTime: time)
        }
        
        if output == videoOutput {
            connection.videoOrientation = .portrait

            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        if writable, output == videoOutput,
           let videoWriterInput,
            videoWriterInput.isReadyForMoreMediaData {
            videoWriterInput.append(sampleBuffer)
            
        } else if writable, output == audioOutput,
                  let audioWriterInput,
                  audioWriterInput.isReadyForMoreMediaData {
            audioWriterInput.append(sampleBuffer)
        }
        
        let diff = CFAbsoluteTimeGetCurrent() - start
        if diff > 0.08 {
            
            let orientation: UIImage.Orientation = currentCameraPosition == .front ? .leftMirrored : .right
            guard case let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer),
                  let cgImage = image.cgImage
            else { return }
            
            let liveImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
            
            aliveImages.append(liveImage)
            self.start = CFAbsoluteTimeGetCurrent()
            
            if aliveImages.count == 10 {
                gifCaptureCompletionBlock?(aliveImages)
                self.start = nil
                aliveImages = []
            }
        }
    }
    
    func configureVideoOutput() throws {
        guard let captureSession = captureSession else {
            throw CameraControllerError.captureSessionIsMissing
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        if let videoDataOutputConnection = videoOutput?.connection(with: .video),
           videoDataOutputConnection.isVideoStabilizationSupported {
            videoDataOutputConnection.preferredVideoStabilizationMode = .cinematic
        }
        
        audioOutput = AVCaptureAudioDataOutput()
        
        captureSession.beginConfiguration()
        
        guard let videoOutput else {
            captureSession.commitConfiguration()
            return
        }
        
        videoOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue(label: "sample buffer delegate", qos: .userInteractive, attributes: []))
        
        if captureSession.canAddOutput(videoOutput) {  captureSession.addOutput(videoOutput)
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
        
        captureSession.sessionPreset = .high
        captureSession.commitConfiguration()
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        guard let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return UIImage() }
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        // let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        guard let quartzImage = context?.makeImage() else { return UIImage() }
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage)
        
        return (image)
    }
}
