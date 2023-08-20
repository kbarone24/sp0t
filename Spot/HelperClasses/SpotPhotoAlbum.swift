//
//  SpotPhotoAlbum.swift
//  Spot
//
//  Created by kbarone on 4/15/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import Photos
import UIKit

class SpotPhotoAlbum: NSObject {
    static let shared = SpotPhotoAlbum()
    var assetCollection: PHAssetCollection?

    override init() {
        super.init()

        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
            return
        }

        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
            PHPhotoLibrary.requestAuthorization({ (_: PHAuthorizationStatus) -> Void in
                ()
            })
        }

        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            self.createAlbum()
        } else {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }
    }

    func requestAuthorizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            // ideally this ensures the creation of the photo album even if authorization wasn't prompted till after init was done
            self.createAlbum()
        }
    }

    func createAlbum() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "sp0t")
        }, completionHandler: { success, _ in
            if success {
                self.assetCollection = self.fetchAssetCollectionForAlbum()
            }
        })
    }

    func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "sp0t")
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let object = collection.firstObject {
            return object
        }
        return nil
    }

    func save(image: UIImage) {
        guard let assetCollection else { return }
        let mergedImage = addWatermarkToPhoto(photo: image)
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: mergedImage)
            assetChangeRequest.location = UserDataModel.shared.currentLocation
            guard let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset else { return }
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            let enumeration: NSArray = [assetPlaceHolder]
            albumChangeRequest?.addAssets(enumeration)

        }, completionHandler: nil)
    }

    func save(videoURL: URL, addWatermark: Bool) {
        guard let assetCollection else { return }
        addWatermarkToVideo(videoURL: videoURL, addWatermark: addWatermark, completion: { mergedURL in
            guard let mergedURL else { print("couldnt get merged url"); return }
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: mergedURL)
                assetChangeRequest?.location = UserDataModel.shared.currentLocation
                guard let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset else { print("couldnt get assetPlaceholder"); return }
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
                let enumeration: NSArray = [assetPlaceHolder]
                albumChangeRequest?.addAssets(enumeration)
            }, completionHandler: nil)
        })
    }

    // Add watermark to photo
    func addWatermarkToPhoto(photo: UIImage) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(photo.size, false, 0.0)
        photo.draw(at: CGPoint.zero)

        let logoImage = UIImage(named: "ExportLogo")
        let logoRect = CGRect(x: 17, y: photo.size.height - 17 - 45, width: 45, height: 45)
        logoImage?.draw(in: logoRect)

        let sp0tRect = CGRect(x: 72, y: photo.size.height - 17 - 45, width: 200, height: 27)
        let sp0tAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "UniversCE-Black", size: 27) as Any,
            .foregroundColor: UIColor.white
        ]
        let sp0tString = NSAttributedString(string: "sp0t", attributes: sp0tAttributes)
        sp0tString.draw(in: sp0tRect)

        let usernameRect = CGRect(x: 72, y: photo.size.height - 17 - 17, width: 300, height: 18)
        let usernameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "UniversCE-Black", size: 15) as Any,
            .foregroundColor: UIColor.white
        ]
        let usernameString = NSAttributedString(string: "@\(UserDataModel.shared.userInfo.username)", attributes: usernameAttributes)
        usernameString.draw(in: usernameRect)

        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return mergedImage ?? photo
    }

    // add watermark to video
    func addWatermarkToVideo(videoURL: URL, addWatermark: Bool, completion: @escaping (URL?) -> Void) {
        // Saved during capture, return original URL
        if !addWatermark {
            completion(videoURL)
            return
        }
        // Get combined image to represent the entire watermark
        // Frames are smaller here -> Something with video scale was causing export to be off
        let logoImage = UIImage(named: "ExportLogo")
        let logoRect = CGRect(x: 0, y: 0, width: 30, height: 30)

        let sp0tRect = CGRect(x: 36, y: 0, width: 200, height: 18)
        let sp0tAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "UniversCE-Black", size: 18) as Any,
            .foregroundColor: UIColor.white
        ]
        let sp0tString = NSAttributedString(string: "sp0t", attributes: sp0tAttributes)


        let usernameRect = CGRect(x: 36, y: 19, width: 300, height: 10)
        let usernameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "UniversCE-Black", size: 9) as Any,
            .foregroundColor: UIColor.white
        ]
        let usernameString = NSAttributedString(string: "@\(UserDataModel.shared.userInfo.username)", attributes: usernameAttributes)

        UIGraphicsBeginImageContextWithOptions(CGSize(width: UIScreen.main.bounds.width - 44, height: 30), false, 0)
        logoImage?.draw(in: logoRect)
        sp0tString.draw(in: sp0tRect)
        usernameString.draw(in: usernameRect)

        // Get the combined image from the graphics context
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        let mixComposition = AVMutableComposition()
        let asset = AVAsset(url: videoURL)
        let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
        let timerange = CMTimeRangeMake(start: .zero, duration: asset.duration)
        let outputURL = createOutputURL()

        let compositionVideoTrack:AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))!

        do {
            try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: .zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            print(error)
            completion(videoURL)
            return
        }

        var processedFrames = 0
        let watermarkFilter = CIFilter(name: "CISourceOverCompositing") ?? CIFilter()
        let watermarkImage = CIImage(image: combinedImage ?? UIImage())

        let videoComposition = AVVideoComposition(asset: asset) { (filteringRequest) in
            let source = filteringRequest.sourceImage.clampedToExtent()
            watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
            let transform = CGAffineTransform(translationX: 30, y: 30)
            watermarkFilter.setValue(watermarkImage?.transformed(by: transform), forKey: "inputImage")
            filteringRequest.finish(with: watermarkFilter.outputImage!, context: nil)
            processedFrames += 1
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(videoURL)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        exportSession.exportAsynchronously(completionHandler: {
            switch exportSession.status {
            case .completed:
                // Export completed successfully
                completion(outputURL)
            case .failed, .cancelled, .unknown:
                // Export failed or was cancelled
                completion(videoURL)
            default:
                break
            }
        })
    }

    /// modified from: https://stackoverflow.com/questions/40530367/swift-3-how-to-add-watermark-on-video-avvideocompositioncoreanimationtool-ios

    private  func createOutputURL() -> URL? {
        let fileManager = FileManager.default
        do {
            let documentDirectoryURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let outputURL = documentDirectoryURL.appendingPathComponent("watermarkedVideo.\(Date().timeIntervalSince1970.second).mp4")
            return outputURL
        } catch {
            print("Error: \(error)")
            return nil
        }
    }
}
