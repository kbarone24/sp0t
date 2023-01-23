//
//  PostImageLoader.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import SDWebImage
import UIKit

class PostImageModel {

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    static let shared = PostImageModel()

    var loadingQueue: OperationQueue
    var loadingOperations: [String: PostImageLoader]
    var currentImageSet: (id: String, images: [UIImage]) = (id: "", images: [])

    init() {
        loadingQueue = OperationQueue()
        loadingOperations = [String: PostImageLoader]()
        currentImageSet = (id: "", images: [])
    }
}

class PostImageLoader: Operation {
    /// set of operations for loading a postImage
    var images: [UIImage] = []
    var loadingCompleteHandler: (([UIImage]?) -> Void)?
    private var post: MapPost

    init(_ post: MapPost) {
        self.post = post
    }

    override func main() {

        if isCancelled { return }

        var imageCount = 0
        var images: [UIImage] = []
        for _ in post.imageURLs {
            images.append(UIImage())
        }

        func imageEscape() {
            imageCount += 1
            if imageCount == post.imageURLs.count {
                self.images = images
                self.loadingCompleteHandler?(images)
            }
        }

        if post.imageURLs.count == 0 { return }

        var frameIndexes = post.frameIndexes ?? []
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i) } }

        var aspectRatios = post.aspectRatios ?? []
        if aspectRatios.isEmpty { for _ in 0...post.imageURLs.count - 1 { aspectRatios.append(1.3333) } }

        var currentAspect: CGFloat = 1

        for x in 0...post.imageURLs.count - 1 {

            let postURL = post.imageURLs[x]
            if let y = frameIndexes.firstIndex(where: { $0 == x }) { currentAspect = aspectRatios[y] }

            let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.width * 2 * currentAspect), scaleMode: .aspectFit)

            SDWebImageManager.shared.loadImage(with: URL(string: postURL), options: [.highPriority, .scaleDownLargeImages], context: [.imageTransformer: transformer], progress: nil) { (rawImage, _, _, _, _, _) in
                DispatchQueue.main.async { [weak self] in

                    guard let self = self else { return }
                    if self.isCancelled { return }

                    let i = self.post.imageURLs.lastIndex(where: { $0 == postURL })
                    guard let image = rawImage else { images[i ?? 0] = UIImage(); imageEscape(); return } /// return blank image on failed download
                    images[i ?? 0] = image
                    imageEscape()
                }
            }
        }
    }
}
