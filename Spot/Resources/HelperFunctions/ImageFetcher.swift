//
//  ImageFetcher.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos

class ImageFetcher {
    
    var context: PHLivePhotoEditingContext!
    var requestID: Int32 = 1
    var contentRequestID: Int = 1
    
    var isFetching = false
    var fetchingIndex = -1

    lazy var imageManager = PHCachingImageManager()

    func fetchLivePhoto(currentAsset: PHAsset, animationImages: [UIImage], completion: @escaping(_ animationImages: [UIImage], _ failed: Bool) -> Void) {
        
        if !animationImages.isEmpty { completion(animationImages, false); return }
        isFetching = true

        var animationImages: [UIImage] = []
        
        let editingOptions = PHContentEditingInputRequestOptions()
        editingOptions.isNetworkAccessAllowed = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            self.contentRequestID = currentAsset.requestContentEditingInput(with: editingOptions) { [weak self] input, info in

                guard let self = self else { return }
                
                if info["PHContentEditingInputCancelledKey"] != nil { completion([], false); return }
                if info["PHContentEditingInputErrorKey"] != nil { completion([], true); return }
                
                var frameImages: [UIImage] = []
                
                if let input = input {

                    self.context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
                    
                    /// download live photos by cycling through frame processor and capturing frames
                    self.context!.frameProcessor = { frame, _ in
                        frameImages.append(UIImage(ciImage: frame.image))
                        return frame.image
                    }
                    
                    let output = PHContentEditingOutput(contentEditingInput: input)
                    
                    self.context?.saveLivePhoto(to: output, options: nil, completionHandler: { [weak self] success, err in
                        
                        guard let self = self else { return }
                        if !success || err != nil || frameImages.isEmpty { completion([], false); return }
                        /// distanceBetweenFrames fixed at 2 right now, always taking the middle 16 frames of the Live often with large offsets. This number is variable though
                        let distanceBetweenFrames: Double = 2
                        let rawFrames = Double(frameImages.count) / distanceBetweenFrames
                        let numberOfFrames: Double = rawFrames > 11 ? 9 : rawFrames > 7 ? max(7, rawFrames - 2) : rawFrames
                        let rawOffsest = max((rawFrames - numberOfFrames) * distanceBetweenFrames/2, 2) /// offset on beginning and ending of the frames
                        let offset = Int(rawOffsest)
                        
                        let aspect = frameImages[0].size.height / frameImages[0].size.width
                        let size = CGSize(width: min(frameImages[0].size.width, UIScreen.main.bounds.width * 1.5), height: min(frameImages[0].size.height, aspect * UIScreen.main.bounds.width * 1.5))
                        
                        let image0 = self.ResizeImage(with: frameImages[offset], scaledToFill: size)
                        animationImages.append(image0 ?? UIImage())
                        
                        /// add middle frames, trimming first couple and last couple
                        let intMultiplier = (frameImages.count - offset * 2)/Int(numberOfFrames)
                        for i in 1...Int(numberOfFrames) {
                            let multiplier = offset + intMultiplier * i
                            let j = multiplier > frameImages.count - 1 ? frameImages.count - 1 : multiplier
                            let image = self.ResizeImage(with: frameImages[j], scaledToFill: size)
                            animationImages.append(image ?? UIImage())
                        }
                    
                        self.isFetching = false
                        self.fetchingIndex = -1
                        DispatchQueue.main.async { completion(animationImages, false) }
                        return
                    })
                }
            }
        }
    }
    
    func fetchImage(currentAsset: PHAsset, item: Int, completion: @escaping(_ result: UIImage, _ failed: Bool) -> Void) {
        
        // let currentAsset = imageObjects[item].asset
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            guard let self = self else { return }
            
            self.requestID = self.imageManager.requestImage(for: currentAsset,
                                                            targetSize: CGSize(width: currentAsset.pixelWidth, height: currentAsset.pixelHeight),
                                                            contentMode: .aspectFill,
                                                            options: options) { (image, info) in
                
                DispatchQueue.main.async { [weak self] in
                    /// return blank image on error
                    if info?["PHImageCancelledKey"] != nil { completion(UIImage(), false); return }
                    guard let self = self else { completion(UIImage(), true); return}
                    guard let result = image else { completion( UIImage(), true); return }
                    
                    let aspect = result.size.height / result.size.width
                    let size = CGSize(width: min(result.size.width, UIScreen.main.bounds.width * 2.0), height: min(result.size.height, aspect * UIScreen.main.bounds.width * 2.0))
                    let resizedImage = self.ResizeImage(with: result, scaledToFill: size)
                    self.isFetching = false
                    self.fetchingIndex = -1
                    
                    completion(resizedImage ?? UIImage(), false)
                    return
                }
            }
        }
    }
    
    func ResizeImage(with image: UIImage?, scaledToFill size: CGSize) -> UIImage? {
        
        let scale: CGFloat = max(size.width / (image?.size.width ?? 0.0), size.height / (image?.size.height ?? 0.0))
        let width: CGFloat = round((image?.size.width ?? 0.0) * scale)
        let height: CGFloat =  round((image?.size.height ?? 0.0) * scale)
        let imageRect = CGRect(x: (size.width - width) / 2.0 - 1.0, y: (size.height - height) / 2.0 - 1.5, width: width + 2.0, height: height + 3.0)
        
        /// if image rect size > image size, make them the same?
        
        let clipSize = CGSize(width: floor(size.width), height: floor(size.height)) /// fix rounding error for images taken from camera
        UIGraphicsBeginImageContextWithOptions(clipSize, false, 0.0)
        
        image?.draw(in: imageRect)

        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }

    func cancelFetchForAsset(asset: PHAsset) {
        
        asset.cancelContentEditingInputRequest(contentRequestID)
        
        if context != nil { context.cancel() }
        imageManager.cancelImageRequest(requestID)
        
        isFetching = false
        fetchingIndex = -1
    }
}
