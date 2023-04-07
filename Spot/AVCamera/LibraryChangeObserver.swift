//
//  CameraChangeDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 4/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos

// check for changes to photo library -> mostly for adding videos user saves through sp0t camera. Added here because gallery fetch happens when user opens camera
extension CameraViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        if let assetsFull = UploadPostModel.shared.assetsFull, let changes = changeInstance.changeDetails(for: assetsFull) {
            UploadPostModel.shared.assetsFull = changes.fetchResultAfterChanges
            DispatchQueue.main.async {
                let galleryVC = self.navigationController?.viewControllers.first(where: { $0 is PhotoGalleryController }) as? PhotoGalleryController
                if changes.hasIncrementalChanges {
                    // currently not checking for removed to avoid having to deal with selected objects being removed
                    if let inserted = changes.insertedIndexes, inserted.count > 0 {
                        UploadPostModel.shared.enumerateOnChange(indexSet: inserted) { complete in
                            if complete {
                                DispatchQueue.main.async { galleryVC?.collectionView.reloadData() }
                            }
                        }
                    } else if let changed = changes.changedIndexes, changed.count > 0 {
                        UploadPostModel.shared.enumerateOnChange(indexSet: changed) { complete in
                            if complete {
                                DispatchQueue.main.async { galleryVC?.collectionView.reloadData() }
                            }
                        }
                    }
                } else {
                    // no incremental change found, fetch everything (only found this to happen when user updated limited gallery in testing)
                    let indexSet = IndexSet(0..<(UploadPostModel.shared.assetsFull?.count ?? 0))
                    UploadPostModel.shared.enumerateOnChange(indexSet: indexSet) { complete in
                        if complete {
                            DispatchQueue.main.async { galleryVC?.collectionView.reloadData() }
                        }
                    }
                }
            }
        }
    }
}
