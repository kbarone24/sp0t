//
//  URLExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension URL {
    func getThumbnail() -> UIImage {
        // we want to get a fresh thumbnail in case the user changed the start time of the video
        do {
            let asset = AVURLAsset(url: self, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch let error {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return UIImage()
        }
    }
}
