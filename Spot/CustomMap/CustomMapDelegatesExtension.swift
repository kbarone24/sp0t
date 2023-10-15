//
//  CustomMapDelegatesExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import PhotosUI
import Photos

extension CustomMapController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !datasource.snapshot().sectionIdentifiers.isEmpty else { return UIView() }
        let section = datasource.snapshot().sectionIdentifiers[section]
        switch section {
        case .main(map: let map, let activeSortMethod):
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: MapOverviewHeader.reuseID) as? MapOverviewHeader
            header?.configure(map: map, sort: activeSortMethod, delegate: self)
            return header
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2), !isRefreshingPagination, !disablePagination {
            isRefreshingPagination = true

            self.postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
            sort.send((viewModel.activeSortMethod, useEndDoc: true))
        }

        // highlight post after upload or if passing through
        let item = snapshot.itemIdentifiers[indexPath.row]
        switch item {
        case .item(post: let post):
            if post.highlightCell, let cell = cell as? SpotPostCell, viewModel.activeSortMethod == .New {
                highlightSelectedPost(post: post, cell: cell, indexPath: indexPath)
            }
        }
    }

    private func highlightSelectedPost(post: Post, cell: SpotPostCell, indexPath: IndexPath) {
        let duration: TimeInterval = 1.0
        let delay: TimeInterval = 1.0

        var postID = post.id ?? ""
        var commentID: String?

        if let parentID = post.parentPostID {
            postID = parentID
            commentID = post.id ?? ""
        }

        DispatchQueue.main.async {
            cell.highlightCell(duration: duration, delay: delay)
            self.viewModel.removePostHighlight(postID: postID, commentID: commentID)
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
            self.refresh.send(false)
        }
    }
}

extension CustomMapController: PostCellDelegate {
    func likePost(post: Post) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: Post) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: Post) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: Post) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func moreButtonTap(post: Post) {
        addPostActionSheet(post: post)
    }

    func viewMoreTap(parentPostID: String) {
        HapticGenerator.shared.play(.light)
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            postListener.send((forced: true, commentInfo: (post: post, endDocument: post.lastCommentDocument)))
        }
    }

    func replyTap(spot: Spot?, parentPostID: String, parentPosterID: String, replyToID: String, replyToUsername: String) {
        openCreate(
            parentPostID: parentPostID,
            parentPosterID: parentPosterID,
            replyToID: replyToID,
            replyToUsername: replyToUsername,
            imageObject: nil,
            videoObject: nil)
    }

    func profileTap(userInfo: UserProfile) {
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func spotTap(post: Post) {
        guard let postID = post.id, let spotID = post.spotID, let spotName = post.spotName else { return }
        let spot = Spot(id: spotID, spotName: spotName)
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot, passedPostID: postID, passedCommentID: nil))

        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func mapTap(post: Post) {}
}

extension CustomMapController: MapHeaderDelegate {
    func joinMap() {
        viewModel.joinMap()
        refresh.send(false)
    }

    func newSort() {
        guard viewModel.activeSortMethod == .Hot else { return }
        viewModel.activeSortMethod = .New
        refresh.send(false)

        postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
        let useEndDoc = viewModel.recentPosts.isEmpty
        sort.send((.New, useEndDoc: useEndDoc))

        isLoadingNewPosts = true
    }

    func hotSort() {
        guard viewModel.activeSortMethod == .New else { return }
        viewModel.activeSortMethod = .Hot
        refresh.send(false)

        viewModel.lastRecentDocument = nil
        postListener.send((forced: false, commentInfo: (post: nil, endDocument: nil)))
        let useEndDoc = viewModel.topPosts.isEmpty
        sort.send((.Hot, useEndDoc: useEndDoc))

        isLoadingNewPosts = true
    }
}

extension CustomMapController: SpotTextFieldFooterDelegate {
    func textAreaTap() {
        openCreate(parentPostID: nil, parentPosterID: nil, replyToID: nil, replyToUsername: nil, imageObject: nil, videoObject: nil)
    }

    func cameraTap() {
        addActionSheet()
    }

    func addActionSheet() {
        // add camera here, return to map controller on cancel, push Create with selected content on confirm
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                guard let self else { return }
                let picker = UIImagePickerController()
                picker.allowsEditing = false
                picker.mediaTypes = ["public.image", "public.movie"]
                picker.sourceType = .camera
                picker.videoMaximumDuration = 15
                picker.videoQuality = .typeHigh
                picker.delegate = self
                self.cameraPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
                guard let self else { return }
                var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                config.filter = .any(of: [.images, .videos])
                config.selectionLimit = 1
                config.preferredAssetRepresentationMode = .current
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                self.galleryPicker = picker
                self.present(picker, animated: true)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )
        present(alert, animated: true)
    }

    func openCreate(parentPostID: String?, parentPosterID: String?, replyToID: String?, replyToUsername: String?, imageObject: ImageObject?, videoObject: VideoObject?) {
        guard viewModel.cachedMap.memberIDs.contains(UserDataModel.shared.uid) else { return }
        let vc = CreatePostController(
            spot: nil,
            map: viewModel.cachedMap,
            parentPostID: parentPostID,
            parentPosterID: parentPosterID,
            replyToID: replyToID,
            replyToUsername: replyToUsername,
            imageObject: imageObject,
            videoObject: videoObject)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

extension CustomMapController: CreatePostDelegate {
    func finishUpload(post: Post) {
        viewModel.addNewPost(post: post)
        self.scrollToPostID = post.id ?? ""
        self.refresh.send(false)
    }
}


extension CustomMapController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false)

        if let image = info[.originalImage] as? UIImage {
            let imageObject = ImageObject(image: image, coordinate: UserDataModel.shared.currentLocation.coordinate, fromCamera: true)
            openCreate(parentPostID: nil,
                       parentPosterID: nil,
                       replyToID: nil,
                       replyToUsername: nil,
                       imageObject: imageObject,
                       videoObject: nil)

        } else if let url = info[.mediaURL] as? URL {
            let videoObject = VideoObject(url: url, coordinate: UserDataModel.shared.currentLocation.coordinate, fromCamera: true)
            openCreate(parentPostID: nil,
                       parentPosterID: nil,
                       replyToID: nil,
                       replyToUsername: nil,
                       imageObject: nil,
                       videoObject: videoObject)
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

        let identifiers = results.compactMap(\.assetIdentifier)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        let asset = fetchResult.firstObject
        let coordinate = asset?.location?.coordinate ?? UserDataModel.shared.currentLocation.coordinate

        if utType.conforms(to: .movie) {
            if let asset {
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
                        self.launchStillImagePreview(imageObject: ImageObject(image: image, coordinate: coordinate, fromCamera: false))
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

extension CustomMapController: VideoEditorDelegate, StillImagePreviewDelegate {
    func finishPassing(imageObject: ImageObject) {
        openCreate(
            parentPostID: nil,
            parentPosterID: nil,
            replyToID: nil,
            replyToUsername: nil,
            imageObject: imageObject,
            videoObject: nil)
    }

    func finishPassing(videoObject: VideoObject) {
        openCreate(parentPostID: nil,
                   parentPosterID: nil,
                   replyToID: nil,
                   replyToUsername: nil,
                   imageObject: nil,
                   videoObject: videoObject)
    }
}
