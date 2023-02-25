//
//  PostControllerTableViewExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

extension PostController: UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let addRefresh = selectedRefreshStatus == .activelyRefreshing ? 1 : 0
        return postsList.count + addRefresh
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row > postsList.count - 1, let cell = tableView.dequeueReusableCell(withIdentifier: ContentLoadingCell.reuseID) as? ContentLoadingCell {
            return cell
            
        } else if let cell = tableView.dequeueReusableCell(withIdentifier: ContentViewerCell.reuseID) as? ContentViewerCell, let post = postsList[safe: indexPath.row] {
            cell.delegate = self
            
            if post.postVideo != nil || post.videoURL != nil || post.videoLocalPath != nil {
                cell.setUp(post: post, parentVC: parentVC, row: indexPath.row, mode: .video)
                
            } else {
                cell.setUp(post: post, parentVC: parentVC, row: indexPath.row, mode: .image)
            }
            
            return cell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return max(0.01, tableView.bounds.height - 0.01)
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if abs(indexPath.row - selectedPostIndex) > 3 { return }
            
            guard let post = postsList[safe: indexPath.row] else { return }
            if PostImageModel.shared.loadingOperations[post.id ?? ""] != nil { return }
            
            let dataLoader = PostImageLoader(post)
            dataLoader.queuePriority = .high
            PostImageModel.shared.loadingQueue.addOperation(dataLoader)
            PostImageModel.shared.loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if abs(indexPath.row - selectedPostIndex) < 4 { return }
            guard let post = postsList[safe: indexPath.row] else { return }
            if let imageLoader = PostImageModel.shared.loadingOperations[post.id ?? ""] {
                imageLoader.cancel()
                PostImageModel.shared.loadingOperations.removeValue(forKey: post.id ?? "")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let updateCellImage: ([UIImage]?) -> Void = { [weak self] (images) in
            guard let self = self, let post = self.postsList[safe: indexPath.row] else { return }
            if post.imageURLs.count != images?.count { return } /// patch fix for wrong images getting called with a post -> crashing on image out of bounds on get frame indexes
            
            if let index = self.postsList.lastIndex(where: { $0.id == post.id }) { if indexPath.row != index { return }  }
            
            if indexPath.row == self.selectedPostIndex { PostImageModel.shared.currentImageSet = (id: post.id ?? "", images: images ?? []) }
            self.setContentFor(indexPath: indexPath, images: images ?? [], cell: cell)
        }
        
        guard let post = postsList[safe: indexPath.row] else {
            return
        }
        
        // Try to find an existing data loader
        if let dataLoader = PostImageModel.shared.loadingOperations[post.id ?? ""] {
            // Has the data already been loaded?
            if dataLoader.images.count == post.imageURLs.count {
                setContentFor(indexPath: indexPath, images: dataLoader.images, cell: cell)
                //  loadingOperations.removeValue(forKey: post.id ?? "")
            } else {
                // No data loaded yet, so add the completion closure to update the cell once the data arrives
                dataLoader.loadingCompleteHandler = updateCellImage
            }
        } else {
            if let videoURL = post.videoURL, let imageVideoService = try? ServiceContainer.shared.service(for: \.imageVideoService) {
                
                imageVideoService.downloadVideo(url: videoURL) { [weak self] url in
                    self?.setContentFor(indexPath: indexPath, videoURL: url, cell: cell)
                }
                
                return
            }
            
            /// Need to create a data loader for this index path
            if indexPath.row == self.selectedPostIndex && PostImageModel.shared.currentImageSet.id == post.id ?? "" {
                updateCellImage(PostImageModel.shared.currentImageSet.images)
                return
            }
            
            let dataLoader = PostImageLoader(post)
            /// Provide the completion closure, and kick off the loading operation
            dataLoader.loadingCompleteHandler = updateCellImage
            PostImageModel.shared.loadingQueue.addOperation(dataLoader)
            PostImageModel.shared.loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    func setContentFor(
        indexPath: IndexPath,
        images: [UIImage] = [],
        videoURL: URL? = nil,
        cell: UITableViewCell
    ) {
        let delay: TimeInterval = animatingToNextRow ? 0.25 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let cell = cell as? ContentViewerCell else {
                return
            }
            
            switch cell.mode {
            case .image:
                cell.setImages(images: images)
                
            case .video:
                cell.setVideo(url: videoURL)
            }
        }
    }
}
