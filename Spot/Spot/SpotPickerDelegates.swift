//
//  SpotPickerDelegates.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PhotosUI

extension SpotController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false)

        if let image = info[.originalImage] as? UIImage {
            let imageObject = ImageObject(image: image, fromCamera: true)
            openCreate(parentPostID: nil, replyUsername: nil, imageObject: imageObject, videoObject: nil)

        } else if let url = info[.mediaURL] as? URL {
            let videoObject = VideoObject(url: url, fromCamera: true)
            openCreate(parentPostID: nil, replyUsername: nil, imageObject: nil, videoObject: videoObject)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            picker.dismiss(animated: true)
            return
        }

        let itemProvider = result.itemProvider
        guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
              let utType = UTType(typeIdentifier)
        else { return }

        if utType.conforms(to: .movie) {
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            if let asset = fetchResult.firstObject {
                DispatchQueue.main.async {
                    self.launchVideoEditor(asset: asset)
                    picker.dismiss(animated: true)
                }
            }

        } else {
            itemProvider.getPhoto { [weak self] image in
                guard let self = self else { return }
                if let image {
                    DispatchQueue.main.async {
                        self.launchStillImagePreview(imageObject: ImageObject(image: image, fromCamera: false))
                        picker.dismiss(animated: true)
                    }
                }
            }
        }

    }

    func launchStillImagePreview(imageObject: ImageObject) {
        let vc = StillImagePreviewView(imageObject: imageObject)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: false)
    }

    func launchVideoEditor(asset: PHAsset) {
        let vc = VideoEditorController(videoAsset: asset)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: false)
    }
}

extension SpotController: VideoEditorDelegate, StillImagePreviewDelegate {
    func finishPassing(imageObject: ImageObject) {
        openCreate(parentPostID: nil, replyUsername: nil, imageObject: imageObject, videoObject: nil)
    }

    func finishPassing(videoObject: VideoObject) {
        openCreate(parentPostID: nil, replyUsername: nil, imageObject: nil, videoObject: videoObject)
    }
}
