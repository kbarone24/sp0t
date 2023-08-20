//
//  ImageVideoService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/13/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import SDWebImage
import PINCache
import FirebaseFirestore
import FirebaseStorage

protocol ImageVideoServiceProtocol {
    func uploadImages(
        images: [UIImage],
        parentView: UIView?,
        progressFill: UIView?,
        fullWidth: CGFloat,
        completion: @escaping (([String], Bool) -> Void)
    )
    
    func uploadVideo(data: Data, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void)
    func downloadVideo(url: String, usingCache: Bool, completion: @escaping ((URL?) -> Void))
   // func downloadImages(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize, usingCache: Bool, completion: (([UIImage]) -> Void)?)
   // func downloadGIFsFramesInBackground(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize)
}

final class ImageVideoService: ImageVideoServiceProtocol {

    enum ImageVideoServiceError: Error {
        case parsingError
    }
    
    private let fireStore: Firestore
    private let storage: Storage
    
    init(fireStore: Firestore, storage: Storage) {
        self.fireStore = fireStore
        self.storage = storage
    }
    
    func uploadImages(
        images: [UIImage],
        parentView: UIView?,
        progressFill: UIView?,
        fullWidth: CGFloat,
        completion: @escaping (([String], Bool) -> Void)
    ) {
        guard !images.isEmpty else {
            completion([], false)
            return
        }
        
        var failed = false
        var success = false
        var urls: [String] = []
        
        _ = images.map { _ in
            urls.append("")
        }
        
        var index = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            /// no downloaded URLs means that this post isnt even close to uploading so trigger failed upload earlier to avoid making the user wait
            if progressFill?.bounds.width != fullWidth && !urls.contains(where: { $0 != "" }) && !failed {
                failed = true
                completion([], true)
                return
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            /// run failed upload on second try if it wasnt already run
            if progressFill?.bounds.width != fullWidth && !failed && !success {
                failed = true
                completion([], true)
                return
            }
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else {
                return
            }
            
            let interval = 0.7 / Double(images.count)
            var downloadCount: CGFloat = 0
            
            for image in images {
                let imageID = UUID().uuidString
                let storageRef = self.storage
                    .reference()
                    .child(FirebaseStorageFolder.pictures.reference)
                    .child("\(imageID)")
                
                var imageData = image.jpegData(compressionQuality: 0.5)
                if imageData?.count ?? 0 > 1_000_000 {
                    imageData = image.jpegData(compressionQuality: 0.3)
                }
                
                guard let imageData else {
                    return
                }
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                storageRef
                    .putData(imageData, metadata: metadata) { _, error in
                        guard error == nil else {
                            failed = !failed ? true : true
                            completion([], true)
                            return
                        }
                        
                        storageRef
                            .downloadURL { url, _ in
                                guard let url = url, error == nil else {
                                    failed = true
                                    completion([], true)
                                    return
                                }
                                
                                let urlString = url.absoluteString
                                
                                let i = images.lastIndex(where: { $0 == image })
                                urls[i ?? 0] = urlString
                                downloadCount += 1
                                
                                DispatchQueue.main.async {
                                    let progress = downloadCount * interval
                                    let frameWidth: CGFloat = min(((0.3 + progress) * fullWidth), fullWidth)
                                    progressFill?.snp.updateConstraints {
                                        $0.width.equalTo(frameWidth)
                                    }
                                    
                                    UIView.animate(withDuration: 0.15) {
                                        parentView?.layoutIfNeeded()
                                    }
                                }
                                
                                index += 1
                                
                                if failed {
                                    /// dont want to return anything after failed upload runs
                                    return
                                }
                                
                                if index == images.count {
                                    DispatchQueue.main.async {
                                        success = true
                                        completion(urls, false)
                                        return
                                    }
                                }
                            }
                    }
            }
        }
    }
    
    func uploadVideo(data: Data, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void) {
        var uploaded = false
        var failed = false

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else {
                failure(ImageVideoServiceError.parsingError)
                return
            }

            // TODO: not an ideal implementation for calculating failed upload but just going to keep in sync with uploadImage until we refactor with something better
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                if !failed && !uploaded {
                    failed = true
                    success("")
                    return
                }
            }
            
            let videoID = UUID().uuidString
            let uploadMetaData = StorageMetadata()
            uploadMetaData.contentType = "video/mp4"
            
            let storageRef = self.storage.reference()
                .child(FirebaseStorageFolder.videos.reference)
                .child(videoID)

            storageRef.putData(data, metadata: uploadMetaData) { _, error in
                if let error {
                    failed = true
                    failure(error)
                } else if !failed {
                    storageRef.downloadURL { url, error in
                        guard error == nil, let urlString = url?.absoluteString, !failed else {
                            success("")
                            return
                        }
                        uploaded = true
                        success(urlString)
                    }
                }
            }
        }
    }
    
    // TODO: Add access to cache for video
    func downloadVideo(url: String, usingCache: Bool, completion: @escaping ((URL?) -> Void)) {
        guard let videoURL = URL(string: url),
              let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        
        // check if the file already exist at the destination folder if you don't want to download it twice
        guard !FileManager.default.fileExists(atPath: documentsDirectoryURL.appendingPathComponent(videoURL.lastPathComponent).path) else {
            completion(documentsDirectoryURL.appendingPathComponent(videoURL.lastPathComponent))
            return
        }
        
        // set up your download task
        URLSession.shared.downloadTask(with: videoURL) { location, response, error in
            
            // use guard to unwrap your optional url
            guard let location = location, error == nil else {
                completion(nil)
                return
            }
            
            // create a deatination url with the server response suggested file name
            let destinationURL = documentsDirectoryURL.appendingPathComponent(response?.suggestedFilename ?? videoURL.lastPathComponent)
            
            try? FileManager.default.moveItem(at: location, to: destinationURL)
            completion(destinationURL)
        }
        .resume()
    }
    /*
    func downloadImages(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize, usingCache: Bool, completion: (([UIImage]) -> Void)?) {
        guard !urls.isEmpty else {
            completion?([])
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var images: [UIImage] = []
            
            guard !usingCache else {
                _ = urls.map { url in
                    if let image = PINCache.shared.object(forKey: url) as? UIImage {
                        images.append(image)
                    }
                }
                
                completion?(images)
                return
            }
            
            var frameIndexes = frameIndexes ?? []
            if frameIndexes.isEmpty {
                for i in 0...urls.count - 1 {
                    frameIndexes.append(i)
                }
            }
            
            var aspect: [CGFloat] = []
            if let aspectRatios, aspectRatios.isEmpty {
                for _ in 0...urls.count - 1 {
                    aspect.append(1.3333)
                }
            }
            
            var currentAspect: CGFloat = 1
            
            for x in 0...urls.count - 1 {
                let postURL = urls[x]
                if let y = frameIndexes.firstIndex(where: { $0 == x }), let aspectRatios {
                    currentAspect = aspectRatios[y]
                }
                
                let adjustedSize = CGSize(width: size.width, height: size.width * currentAspect)
                let transformer = SDImageResizingTransformer(size: adjustedSize, scaleMode: .aspectFit)
                
                if let image = PINCache.shared.object(forKey: postURL) as? UIImage {
                    images.append(image)
                    
                    // This will get called in the case where all images are already cached
                    if x == urls.count - 1 && images.count == urls.count {
                        completion?(images)
                    }
                    continue
                }
                
                SDWebImageManager.shared.loadImage(
                    with: URL(string: postURL),
                    options: [.highPriority, .scaleDownLargeImages],
                    context: [.imageTransformer: transformer], progress: nil) { (rawImage, _, _, _, _, _) in
                    defer {
                        if x == urls.count - 1 {
                            completion?(images)
                        }
                    }
                    
                    _ = urls.lastIndex(where: { $0 == postURL })
                    guard let image = rawImage else {
                        images.append(UIImage())
                        return
                    }
                    images.append(image)
                    PINCache.shared.setObject(image, forKey: postURL)
                }
            }
        }
    }

    func downloadGIFsFramesInBackground(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize) {
        guard let frameIndexes else {
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            var gifURLs: [String] = []
            
            for (index, _) in urls.enumerated() {
                gifURLs.append(contentsOf: self?.getGifImageURLs(imageURLs: urls, frameIndexes: frameIndexes, imageIndex: index) ?? [])
            }
            
            let adjustedSize = CGSize(width: size.width, height: size.width * 1.3333)
            let transformer = SDImageResizingTransformer(size: adjustedSize, scaleMode: .aspectFit)
            
            _ = gifURLs.map { postURL in
                
                SDWebImageManager.shared.loadImage(
                    with: URL(string: postURL),
                    options: [.highPriority, .scaleDownLargeImages],
                    context: [.imageTransformer: transformer], progress: nil) { (rawImage, _, _, _, _, _) in
                    guard let image = rawImage else {
                        return
                    }
                    PINCache.shared.setObject(image, forKey: postURL)
                }
            }
        }
    }
     */
}
