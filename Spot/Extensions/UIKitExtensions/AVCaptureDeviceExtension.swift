//
//  AVCaptureDeviceExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation

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
