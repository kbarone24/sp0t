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

protocol ImageVideoServiceProtocol {
    func uploadImages(
        images: [UIImage],
        parentView: UIView?,
        progressFill: UIView?,
        fullWidth: CGFloat,
        completion: @escaping (([String], Bool) -> Void)
    )
    
    func uploadVideo(url: URL, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void)
    func downloadVideo(url: String, completion: @escaping ((URL?) -> Void))
    func downloadImages(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize) async throws -> [UIImage]
}

final class ImageVideoService: ImageVideoServiceProtocol {
    
    enum ImageVideoServiceError: Error {
        case parsingError
    }
    
    private let fireStore: Firestore
    private let storage: Storage
    private let imageCache = CacheService<String, UIImage>()
    
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
        
        images.forEach { _ in
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
                                    failed = !failed ? true : true
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
    
    func uploadVideo(url: URL, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self, let data = try? Data(contentsOf: url) else {
                failure(ImageVideoServiceError.parsingError)
                return
            }
            
            let videoID = UUID().uuidString
            let uploadMetaData = StorageMetadata()
            uploadMetaData.contentType = "video/mp4"
            
            let storageRef = self.storage.reference()
                .child(FirebaseStorageFolder.videos.reference)
                .child(videoID)
            
            storageRef.putData(data, metadata: uploadMetaData) { result in
                switch result {
                case .success:
                    storageRef.downloadURL { url, error in
                        guard error == nil, let urlString = url?.absoluteString else {
                            success("")
                            return
                        }
                        
                        success(urlString)
                    }
                    
                case .failure(let error):
                    failure(error)
                }
            }
        }
    }
    
    func downloadVideo(url: String, completion: @escaping ((URL?) -> Void)) {
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
    
    func downloadImages(urls: [String], frameIndexes: [Int]?, aspectRatios: [CGFloat]?, size: CGSize) async throws -> [UIImage] {
        guard !urls.isEmpty else {
            return []
        }
        
        return try await withUnsafeThrowingContinuation { [unowned self] continuation in
            
            var images: [UIImage] = []
            
            let cachedKeys = self.imageCache.allCachedKeys()
            if cachedKeys.count == urls.count {
                for key in cachedKeys where cachedKeys.count == urls.count {
                    if let image = self.imageCache.entry(forKey: key)?.value {
                        images.append(image)
                    }
                }
                
                continuation.resume(returning: images)
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
                
                defer {
                    if x == urls.count - 1 {
                        continuation.resume(returning: images)
                    }
                }
                
                let postURL = urls[x]
                if let y = frameIndexes.firstIndex(where: { $0 == x }), let aspectRatios {
                    currentAspect = aspectRatios[y]
                }
                
                let adjustedSize = CGSize(width: size.width, height: size.width * currentAspect)
                let transformer = SDImageResizingTransformer(size: adjustedSize, scaleMode: .aspectFit)
                
                SDWebImageManager.shared.loadImage(
                    with: URL(string: postURL),
                    options: [.highPriority, .scaleDownLargeImages],
                    context: [.imageTransformer: transformer], progress: nil) { (rawImage, _, _, _, _, _) in
                        let i = urls.lastIndex(where: { $0 == postURL })
                        guard let image = rawImage else {
                            images[i ?? 0] = UIImage()
                            return
                        }
                        images[i ?? 0] = image
                        self.imageCache.removeValue(forKey: postURL)
                        self.imageCache.insert(CacheService.Entry(key: postURL, value: image))
                    }
            }
        }
    }
}
