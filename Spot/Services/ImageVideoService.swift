//
//  ImageVideoService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 1/13/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase

protocol ImageVideoServiceProtocol {
    func uploadImages(
        images: [UIImage],
        parentView: UIView?,
        progressFill: UIView?,
        fullWidth: CGFloat,
        completion: @escaping (([String], Bool) -> Void)
    )
    
    func uploadVideo(url: URL, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void)
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
}
