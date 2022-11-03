//
//  PhotoGalleryController.swift
//  Spot
//
//  Created by kbarone on 4/21/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Foundation
import MapKit
import Mixpanel
import Photos
import PhotosUI
import UIKit

class PhotoGalleryController: UIViewController, PHPhotoLibraryChangeObserver {
    lazy var imageManager = PHCachingImageManager()
    let options: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        return options
    }()

    let thumbnailSize = CGSize(width: UIScreen.main.bounds.width / 4 - 0.1, height: (UIScreen.main.bounds.width / 3))
    var offset: CGFloat = 0
    var maxOffset: CGFloat = (UIScreen.main.bounds.width / 4 * 75) // reload triggered at 300 images
    var refreshes = 0
    var cancelOnDismiss = false
    var fetchFromGallery = false // true if gallery access was just enabled

    lazy var imagePreview: ImagePreviewView = {
        let view = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height))
        return view
    }()

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout {
            $0.scrollDirection = .vertical
            $0.minimumLineSpacing = 0.1
            $0.minimumInteritemSpacing = 0.1
            $0.sectionFootersPinToVisibleBounds = true
        }
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.register(SelectedImagesFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "SelectedFooter")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: -50, right: 0)
        collectionView.isUserInteractionEnabled = true
        collectionView.allowsSelection = true
        collectionView.scrollsToTop = false
        return collectionView
    }()

    lazy var imageFetcher = ImageFetcher()

    deinit {
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ScrollGallery"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addCollectionView()
        addNotifications()
        if fetchFromGallery { fetchGalleryAssets() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UploadPostModel.shared.galleryOpen = true
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhotoGalleryOpen")
        cancelOnDismiss = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelOnDismiss = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UploadPostModel.shared.galleryOpen = false
        removePreviews()
        // reset nav bar colors (only set if limited picker was shown)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)
    }

    func setUpNavBar() {
        navigationItem.title = "Gallery"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.addBlackBackground()
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.isTranslucent = false

        let cancelButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(cancelTap(_:)))
        navigationItem.setLeftBarButton(cancelButton, animated: false)
        self.navigationItem.leftBarButtonItem?.tintColor = nil

        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .lightContent
        }
    }

    func addCollectionView() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(removePreview(_:)), name: NSNotification.Name("PreviewRemove"), object: nil)
        if UploadPostModel.shared.galleryAccess == .limited {
            PHPhotoLibrary.shared().register(self)
            showLimitedAlert()
        }
    }

    func showFailedDownloadAlert() {
        let alert = UIAlertController(title: "Unable to download image from iCloud", message: "\n Your iPhone storage may be full", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // max offset is the value at which the tableview should reload data -> starting point is after 700 of the first 1000 pictures
        offset = scrollView.contentOffset.y

        if offset > maxOffset {
            // refresh after 900 posts past the 1000x mark
            self.maxOffset = (UIScreen.main.bounds.width / 4 * 225) + UIScreen.main.bounds.width / 4 * (250 * CGFloat(self.refreshes))
            if (refreshes + 1) * 1_000 < UploadPostModel.shared.imageObjects.count {
                self.refreshes += 1
                DispatchQueue.main.async { self.collectionView.reloadData() }
            }
        }
    }

    @objc func cancelTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CalleryCancelTap")
        if let cameraVC = navigationController?.viewControllers.first(where: { $0 is AVCameraController }) as? AVCameraController {
            cameraVC.cancelFromGallery()
            DispatchQueue.main.async { self.navigationController?.popToViewController(cameraVC, animated: true) }
        }
    }

    @objc func nextTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "GalleryNextTap")
        if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "ImagePreview") as? ImagePreviewController {
            DispatchQueue.main.async { self.navigationController?.pushViewController(vc, animated: false) }
        }
    }

    @objc func removePreview(_ sender: NSNotification) {
        imagePreview.removeFromSuperview()
    }
}

extension PhotoGalleryController {
    func fetchGalleryAssets() {
        UploadPostModel.shared.fetchAssets { _ in
            UploadPostModel.shared.imageObjects.sort(by: { !$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected })
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }
}

extension PhotoGalleryController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let maxImages = (refreshes + 1) * 1_000
        let imageCount = UploadPostModel.shared.imageObjects.count
        return min(maxImages, imageCount)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as? GalleryCell else { return UICollectionViewCell() }

        if let imageObject = UploadPostModel.shared.imageObjects[safe: indexPath.row] {
            let selected = UploadPostModel.shared.selectedObjects.contains(where: { $0.id == imageObject.0.id })
            let asset = imageObject.0.asset
            let row = indexPath.row
            cell.setUp(asset: asset, row: row, selected: selected, id: imageObject.0.id)

            // set cellImage from here -> processes weren't consistently offloading with deinit
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                cell.requestID = self.imageManager.requestImage(for: imageObject.0.asset, targetSize: self.thumbnailSize, contentMode: .aspectFill, options: self.options) { (result, info) in
                    if info?["PHImageCancelledKey"] != nil { return }
                    if row != indexPath.row { print("!="); return }
                    DispatchQueue.main.async { if let result { cell.imageView.image = result } }
                }
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageObject = UploadPostModel.shared.imageObjects[indexPath.row].image
        // if image has been downloaded show preview right away
        if imageObject.stillImage != UIImage() {
            addPreviewView(object: imageObject, galleryIndex: indexPath.row)
        } else {
            // download image to show in preview
            downloadImage(index: indexPath.row) { stillImage in
                UploadPostModel.shared.imageObjects[indexPath.row].image.stillImage = stillImage
                self.addPreviewView(object: UploadPostModel.shared.imageObjects[indexPath.row].image, galleryIndex: indexPath.row)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width / 4 - 0.1, height: view.bounds.width / 3)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return UploadPostModel.shared.selectedObjects.isEmpty ? CGSize(width: UIScreen.main.bounds.width, height: 120) : CGSize(width: UIScreen.main.bounds.width, height: 220)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SelectedFooter", for: indexPath) as? SelectedImagesFooter {
            footer.setUp()
            return footer
        }
        return UICollectionReusableView()
    }

    func downloadImage(index: Int, completion: @escaping (_ stillImage: UIImage) -> Void) {

        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell {

            let currentAsset = UploadPostModel.shared.imageObjects[index].image.asset

            // this cell is fetching, cancel fetch and return
            if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: index); return  }

            // fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            if imageFetcher.isFetching { cancelFetchForRowAt(index: imageFetcher.fetchingIndex) }
            cell.addActivityIndicator()

            imageFetcher.fetchImage(currentAsset: currentAsset, item: index) { [weak self] stillImage, failed  in

                guard let self = self else { return }
                cell.removeActivityIndicator()

                // return on download fail
                if self.cancelOnDismiss { return }
                if failed { self.showFailedDownloadAlert(); return }
                if stillImage == UIImage() { return } // canceled download

                completion(stillImage)
                return
            }
        }
    }

    func deselectFromFooter(id: String) {
        if let index = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.image.id == id }) {
            deselect(index: index)
        }
    }

    func deselect(index: Int) {
        let paths = getSelectedPaths(newRow: index, select: false)
        guard let selectedObject = UploadPostModel.shared.imageObjects[safe: index]?.image else { return }

        // deselect image on circle tap
        UploadPostModel.shared.selectObject(imageObject: selectedObject, selected: false)
        reloadItems(paths: paths)
    }

    func select(index: Int) {
        guard let selectedObject = UploadPostModel.shared.imageObjects[safe: index]?.image else { return }
        if UploadPostModel.shared.selectedObjects.count > 4 { return }

        let paths = getSelectedPaths(newRow: index, select: true)

        if selectedObject.stillImage != UIImage() {
            // select image immediately
            UploadPostModel.shared.selectObject(imageObject: selectedObject, selected: true)
            reloadItems(paths: paths)

        } else {
            // download image and select
            downloadImage(index: index) { stillImage in

                UploadPostModel.shared.imageObjects[index].image.stillImage = stillImage

                if UploadPostModel.shared.selectedObjects.count < 5 {

                    UploadPostModel.shared.selectObject(imageObject: UploadPostModel.shared.imageObjects[index].image, selected: true)
                    if self.cancelOnDismiss { return }
                    self.reloadItems(paths: paths)
                }
            }
        }
    }

    func reloadItems(paths: [IndexPath]) {
        DispatchQueue.main.async {
            // self.collectionView.reloadData()
             self.collectionView.reloadItems(at: paths)
             if let footer = self.collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter).first as? SelectedImagesFooter {
                footer.setUp()
            }
        }
    }

    func cancelFetchForRowAt(index: Int) {
        Mixpanel.mainInstance().track(event: "GalleryCancelImageFetch")

        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell else { return }
        guard let currentObject = UploadPostModel.shared.imageObjects[safe: index]?.image else { return }
        let currentAsset = currentObject.asset

        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }

    func getSelectedPaths(newRow: Int, select: Bool) -> [IndexPath] {
        // reload all visible if going from max / not max selected
        if (UploadPostModel.shared.selectedObjects.count == 5 && !select) || (UploadPostModel.shared.selectedObjects.count == 4 && select) { return collectionView.indexPathsForVisibleItems }
        var selectedPaths: [IndexPath] = []
        for object in UploadPostModel.shared.selectedObjects {
            if let index = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.image.id == object.id }) {
                selectedPaths.append(IndexPath(item: Int(index), section: 0))
            }
        }

        let newPath = IndexPath(item: newRow, section: 0)
        if !selectedPaths.contains(where: { $0 == newPath }) { selectedPaths.append(newPath) }
        return selectedPaths
    }
}
