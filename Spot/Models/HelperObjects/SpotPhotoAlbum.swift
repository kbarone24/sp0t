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
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetChangeRequest.location = UserDataModel.shared.currentLocation
            guard let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset else { return }
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            let enumeration: NSArray = [assetPlaceHolder]
            albumChangeRequest?.addAssets(enumeration)

        }, completionHandler: nil)
    }

    func save(videoURL: URL) {
        guard let assetCollection else { return }
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            assetChangeRequest?.location = UserDataModel.shared.currentLocation
            guard let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset else { return }
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
            let enumeration: NSArray = [assetPlaceHolder]
            albumChangeRequest?.addAssets(enumeration)

        }, completionHandler: nil)
    }
}
