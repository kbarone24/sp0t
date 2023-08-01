//
//  CreatePostPickerDelegates.swift
//  Spot
//
//  Created by Kenny Barone on 7/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI

extension CreatePostController {
    func launchCamera() {
        addActionSheet()
    }

    func addActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                // TODO: open imagePicker
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.mediaTypes = ["public.image", "public.movie"]
                picker.sourceType = .camera
                picker.videoMaximumDuration = 15
                picker.videoQuality = .typeHigh
                self?.cameraPicker = picker
                self?.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                // TODO: open imagePicker
                var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                config.filter = .any(of: [.images, .videos])
                config.selectionLimit = 1
                config.preferredAssetRepresentationMode = .current
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self?.galleryPicker = picker
                self?.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )
        present(alert, animated: true)
    }

    private func launchStillImagePreview(imageObject: ImageObject) {
        print("launch still image preview")
        DispatchQueue.main.async {
            let vc = StillImagePreviewView(imageObject: imageObject)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }

    private func launchVideoEditor(asset: PHAsset) {
        DispatchQueue.main.async {
            let vc = VideoEditorController(videoAsset: asset)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

extension CreatePostController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismissPickers()
        if let image = info[.originalImage] as? UIImage {
            let imageObject = ImageObject(
                id: UUID().uuidString,
                asset: PHAsset(),
                rawLocation: UserDataModel.shared.currentLocation,
                stillImage: image,
                creationDate: Date(),
                fromCamera: true)
            addThumbnailView(imageObject: imageObject, videoObject: nil)
            
        } else if let url = info[.mediaURL] as? URL {
            let video = VideoObject(
                id: UUID().uuidString,
                asset: PHAsset(),
                thumbnailImage: url.getThumbnail(),
                videoData: nil,
                videoPath: url,
                rawLocation: UserDataModel.shared.currentLocation,
                creationDate: Date(),
                fromCamera: true
            )
            addThumbnailView(imageObject: nil, videoObject: video)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismissPickers()
        picker.dismiss(animated: false)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismissPickers()
        if let result = results.first {
            let itemProvider = result.itemProvider

            guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first,
                  let utType = UTType(typeIdentifier)
            else { return }


            if utType.conforms(to: .movie) {
                let identifiers = results.compactMap(\.assetIdentifier)
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                print("fetch result", fetchResult)
                if let asset = fetchResult.firstObject {
                    print("got asset")
                    self.launchVideoEditor(asset: asset)
                }

            } else {
                print("get photo")
                self.getPhoto(from: itemProvider) { [weak self] image in
                    guard let self = self else { return }
                    if let image {
                        self.launchStillImagePreview(imageObject: self.generateImageObject(image: image))
                    }
                }
            }
        }
    }

    private func getPhoto(from itemProvider: NSItemProvider, completion: @escaping (_ image: UIImage?) -> Void) {
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let error = error {
                    print(error.localizedDescription)
                }
                completion(object as? UIImage)
            }
        }
    }

    private func generateImageObject(image: UIImage) -> ImageObject {
        let imageObject = ImageObject(
            id: UUID().uuidString,
            asset: PHAsset(),
            rawLocation: UserDataModel.shared.currentLocation,
            stillImage: image,
            creationDate: Date(),
            fromCamera: true)
        return imageObject
    }

    private func getVideo(from itemProvider: NSItemProvider, typeIdentifier: String, completion: @escaping (_ videoURL: URL?) -> Void) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            if let error = error {
                print(error.localizedDescription)
                completion(nil)
            }

            guard let url = url else { return }

            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            guard let targetURL = documentsDirectory?.appendingPathComponent(url.lastPathComponent) else { return }

            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }

                try FileManager.default.copyItem(at: url, to: targetURL)
                completion(targetURL)

            } catch {
                print(error.localizedDescription)
                completion(nil)
            }
        }
    }

    private func addThumbnailView(imageObject: ImageObject?, videoObject: VideoObject?) {
        // TODO: save object and add to view

    }
}

extension CreatePostController: VideoEditorDelegate, StillImagePreviewDelegate {
    func finishPassing(image: ImageObject) {
        print("finish passing image")
        dismissPickers()
        addThumbnailView(imageObject: image, videoObject: nil)
    }

    func finishPassing(video: VideoObject) {
        print("finish passing video")
        dismissPickers()
        addThumbnailView(imageObject: nil, videoObject: video)
    }

    private func dismissPickers() {
        cameraPicker?.dismiss(animated: false)
        cameraPicker = nil

        galleryPicker?.dismiss(animated: false)
        galleryPicker = nil
    }
}

// src: https://www.appcoda.com/phpicker/

