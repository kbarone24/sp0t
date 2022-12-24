//
//  CMSampleBufferExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import AVFoundation

/// source: https://www.appcoda.com/avfoundation-swift-guide/
extension CMSampleBuffer {
    func image(orientation: UIImage.Orientation,
               scale: CGFloat = 1.0) -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        return UIImage(
            ciImage: ciImage,
            scale: scale,
            orientation: orientation
        )
    }
}
/// https://stackoverflow.com/questions/15726761/make-an-uiimage-from-a-cmsamplebuffer
