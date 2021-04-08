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
    
    static let sharedInstance = SpotPhotoAlbum()
    var assetCollection: PHAssetCollection!
    
     override init() {
            super.init()

            if let assetCollection = fetchAssetCollectionForAlbum() {
                self.assetCollection = assetCollection
                return
            }

            if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
                PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in
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
                print("trying again to create the album")
                self.createAlbum()
            } else {
                print("should really prompt the user to let them know it's failed")
            }
        }

        func createAlbum() {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "sp0t")
            }) { success, error in
                if success {
                    self.assetCollection = self.fetchAssetCollectionForAlbum()
                }
            }
        }

        func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", "sp0t")
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

            if let _: AnyObject = collection.firstObject {
                return collection.firstObject
            }
            return nil
        }

        func save(image: UIImage) {
            if assetCollection == nil {
                return                          // if there was an error upstream, skip the save
            }

            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
                let enumeration: NSArray = [assetPlaceHolder!]
                albumChangeRequest!.addAssets(enumeration)

            }, completionHandler: nil)
        }
    
    func save(videoURL: URL) {
        if assetCollection == nil {
            return                          // if there was an error upstream, skip the save
        }
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
            let enumeration: NSArray = [assetPlaceHolder!]
            albumChangeRequest!.addAssets(enumeration)

        }, completionHandler: nil)
    }
}
    
