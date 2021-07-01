
//
//  PhotoGalleryPicker.swift
//  Spot
//
//  Created by kbarone on 12/20/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Foundation
import UIKit
import Firebase
import Photos
import Mixpanel
import PhotosUI

protocol PhotoGalleryDelegate {
    func FinishPassing(images: [(UIImage, Int, CLLocation)])
}

class PhotoGalleryPicker: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver {
    
    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    lazy var imageObjects: [ImageObject] = []
    lazy var imageManager = PHCachingImageManager()
    
    var baseSize: CGSize!
    
    var delegate: PhotoGalleryDelegate?
    var editSpotCount = 0
    var offset: CGFloat = 0
    var maxOffset: CGFloat = (UIScreen.main.bounds.width/4 * 75)
    var assetsFirst: PHFetchResult<PHAsset>!
    
    var refreshSafe = false
    var fullGallery = false 
    var refreshes = 0
    
    var maskView: UIView!
    var previewView: GalleryPreviewView!

    var downloadCircle: UIActivityIndicatorView!
    var isFetching = false
    var cancelOnDismiss = false
    
    var context: PHLivePhotoEditingContext!
    var requestID: Int32 = 1
    var contentRequestID: Int = 1
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        navigationItem.title = "Photo gallery"
        
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        parentVC.mapVC.customTabBar.tabBar.isHidden = true
        cancelOnDismiss = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        cancelOnDismiss = true
        removePreviews()
    }
    
    deinit {
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ScrollGallery"), object: nil)
         PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "galleryCell")
        
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0.1
        layout.minimumInteritemSpacing = 0.1
        layout.estimatedItemSize = baseSize
        layout.itemSize = baseSize
        
        collectionView.isUserInteractionEnabled = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsSelection = true
        collectionView.setCollectionViewLayout(layout, animated: false)
        view.addSubview(collectionView)
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe(_:)))
        leftSwipe.direction = .left
        collectionView.addGestureRecognizer(leftSwipe)
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maskTap(_:))))
        maskView.isUserInteractionEnabled = true
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        collectionView.register(galleryActivityIndicator.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "footerView")
        
        getGalleryImages()
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrollToTop(_:)), name: NSNotification.Name("ScrollGallery"), object: nil)
        
        
        guard let containerVC = self.parent as? PhotosContainerController else { return }
        if containerVC.limited {
            PHPhotoLibrary.shared().register(self) /// eventually probably want to do this after
            showLimitedAlert()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)

        /// reset nav bar colors (only set if limited picker was shown)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhotoGalleryOpen")
    }
    
    @objc func leftSwipe(_ sender: UISwipeGestureRecognizer) {
        guard let parentVC = parent as? PhotosContainerController else { return }
        if parentVC.selectedIndex == 0 { parentVC.switchToMapSeg() }
    }
    
    @objc func scrollToTop(_ sender: NSNotification) {
        collectionView.setContentOffset(CGPoint(x: 0, y: 10), animated: true)
    }
    
    func getGalleryImages() {
        
        /// get first 1000 images here for quick load on gallery
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1000
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        //get assets first to load initial view and not have to wait for all of initial assets to be fetched
        assetsFirst = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        if assetsFirst.count == 0 { return }
        
        var indexSet: IndexSet!
        if assetsFirst.count > 1000 {
            indexSet =  IndexSet(0...999)
        } else {
            indexSet = IndexSet(0...assetsFirst.count - 1)
        }
        
        fetchAssets(indexSet: indexSet, first: true)
    }
    
    func fetchAssets(indexSet: IndexSet, first: Bool) {
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.version = .current
        
        var fetchObject: PHFetchResult<PHAsset>!
        if first {
            fetchObject = assetsFirst
        } else {
            fetchObject = parentVC.assetsFull
        }
        
        var localObjects: [ImageObject] = []

        /// try not specifiying queue until reload
        DispatchQueue.global(qos: .userInitiated).async { fetchObject.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            guard let self = self else { return }

            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            if localObjects.contains(where: {$0.asset == object}) || self.imageObjects.contains(where: {$0.asset == object}) { return }
            let imageObj = ImageObject(asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], gifMode: false, creationDate: creationDate)
            localObjects.append(imageObj)

            if localObjects.count == 1000 || parentVC.assetsFull != nil && self.imageObjects.count + localObjects.count == parentVC.assetsFull.count {
                /// if self.imageObjects.count == (self.refreshes + 1) * 1000 || (parentVC.assetsFull != nil && self.imageObjects.count == parentVC.assetsFull.count) {
                
                self.imageObjects.append(contentsOf: localObjects)
                self.imageObjects.sort(by: {$0.creationDate > $1.creationDate})

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.collectionView.reloadData()
                    self.refreshSafe = true
                }
    
                fetchObject = nil /// seems to be preventing memory leak
            }
        }}
    }
    
    func showLimitedAlert() {
        
        let alert = UIAlertController(title: "Allow sp0t to access your photos", message: "You've allowed access to a limited number of photos", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Allow access to all photos", style: .default, handler: { action in
                                        switch action.style{
                                        case .default:
                                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                                        default: return
                                        }}))
        
        alert.addAction(UIAlertAction(title: "Select more photos", style: .default, handler: { action in
                                        switch action.style{
                                        case .default:
                                            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .normal)
                                            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .highlighted)
                                            UINavigationBar.appearance().backgroundColor = UIColor(named: "SpotBlack")
                                            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
                                        default: return
                                        }}))
        
        alert.addAction(UIAlertAction(title: "Keep current selection", style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)

    }
    
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
    }
    
    func removePreviews() {
        
        maskView.removeFromSuperview()

        /// remove saved images from image objects to avoid memory pile up
        if previewView != nil && previewView.selectedIndex == 0 {
            if let i = imageObjects.firstIndex(where: {$0.asset == previewView.object.asset}) {
                imageObjects[i].animationImages.removeAll()
                imageObjects[i].stillImage = UIImage()
            }
        }
        
        if previewView != nil { for sub in previewView.subviews { sub.removeFromSuperview()}; previewView.removeFromSuperview(); previewView = nil }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageObjects.count
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        guard let parentVC = parent as? PhotosContainerController else { return UICollectionReusableView() }

        let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerView", for: indexPath) as! galleryActivityIndicator
        if parentVC.assetsFull != nil && self.imageObjects.count == parentVC.assetsFull.count  || fullGallery {
            footerView.setUp(animate: false)
        } else {
            /// animate footer if refresh isn't done
            footerView.setUp(animate: true)
        }
        return footerView
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "galleryCell", for: indexPath) as! GalleryCell
        guard let parentVC = parent as? PhotosContainerController else { return UICollectionViewCell() }
        // cell.image = nil
        
        if let imageObject = imageObjects[safe: indexPath.row] {
            var index = 0
            if let trueIndex = parentVC.selectedObjects.lastIndex(where: {$0.index == indexPath.row}) { index = trueIndex + 1 }
            cell.setUp(asset: imageObject.asset, row: indexPath.row, index: index, editSpot: parentVC.editSpotMode)
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

        var path = [IndexPath]()
        path.append(indexPath)
        
        guard let parentVC = parent as? PhotosContainerController else { return }
                
        if parentVC.selectedObjects.contains(where: {$0.index == indexPath.row}) {
            deselect(index: indexPath.row, circleTap: false)
            
        } else {
            select(index: indexPath.row, circleTap: false)
        }
    }
    
    func deselect(index: Int, circleTap: Bool) {
                
        let paths = getSelectedPaths(newRow: index)
        guard let parentVC = parent as? PhotosContainerController else { return }
        guard let selectedObject = imageObjects[safe: index] else { return }

        if !circleTap {
            var selectedIndex = 0
            if let trueIndex = parentVC.selectedObjects.lastIndex(where: {$0.index == index}) { selectedIndex = trueIndex + 1 }
            self.addPreviewView(object: selectedObject, selectedIndex: selectedIndex, galleryIndex: index)
            
        } else {
            parentVC.selectedObjects.removeAll(where: {$0.index == index})
            if parentVC.selectedObjects.count == 0 { parentVC.removeNextButton() }
            DispatchQueue.main.async { self.collectionView.reloadItems(at: paths) }
        }
    }
    
    func select(index: Int, circleTap: Bool) {
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        guard let selectedObject = imageObjects[safe: index] else { return }
        if parentVC.selectedObjects.count > 4 { showMaxImagesAlert(); return }
        if parentVC.editSpotMode && parentVC.selectedObjects.count > 0 { return }
    
        let paths = getSelectedPaths(newRow: index)
        
        if selectedObject.stillImage != UIImage() {
            
            if !circleTap {
                self.addPreviewView(object: selectedObject, selectedIndex: 0, galleryIndex: index)
            } else {
                parentVC.selectedObjects.append((selectedObject, index))
                self.checkForNext()
                DispatchQueue.main.async { self.collectionView.reloadItems(at: paths) }
            }
            
        } else {

            if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell {
                
                let currentAsset = self.imageObjects[index].asset
                var local = true
                let resourceArray = PHAssetResource.assetResources(for: currentAsset)
                if let isLocal = resourceArray.first?.value(forKey: "locallyAvailable") as? Bool { local = isLocal }

                /// this cell is fetching, cancel fetch and return
                if cell.activityIndicator.isAnimating {
                    cell.activityIndicator.stopAnimating()
                    currentAsset.cancelContentEditingInputRequest(contentRequestID)
                    if context != nil { context.cancel() }
                    imageManager.cancelImageRequest(requestID)
                    self.isFetching = false
                    return
                }

                if self.isFetching { return } /// another cell is fetching, just return
                cell.addActivityIndicator()
                
                self.isFetching = true
                if imageObjects[index].asset.mediaSubtypes.contains(.photoLive) && !parentVC.editSpotMode {
                    
                    fetchLivePhoto(item: index, isLocal: local, selected: false) { [weak self] animationImages, stillImage, failed in

                        guard let self = self else { return }
                        
                        self.isFetching = false
                        cell.removeActivityIndicator()
                        
                        if self.cancelOnDismiss { return }
                        if failed { self.showFailedDownloadAlert(); return }
                        if stillImage == UIImage() { return } /// canceled

                        self.imageObjects[index] = (ImageObject(asset: self.imageObjects[index].asset, rawLocation: self.imageObjects[index].rawLocation, stillImage: stillImage, animationImages: animationImages, gifMode: true, creationDate: self.imageObjects[index].creationDate))

                        ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                        if parentVC.selectedObjects.count < 5 {
                            
                            let newObject = (ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, stillImage: stillImage, animationImages: animationImages, gifMode: true, creationDate: selectedObject.creationDate), index)
                            
                            if !circleTap {
                                self.addPreviewView(object: newObject.0, selectedIndex: 0, galleryIndex: index)
                                
                            } else {
                                parentVC.selectedObjects.append(newObject)
                                self.checkForNext()
                                DispatchQueue.main.async {
                                    if self.cancelOnDismiss { return }
                                    self.collectionView.reloadItems(at: paths)
                                }
                            }
                        }
                    }
                    
                } else {
                    
                    self.fetchImage(item: index, isLocal: local, selected: true) { [weak self] result, failed  in
                        
                        guard let self = self else { return }
                        self.isFetching = false
                        cell.removeActivityIndicator()
                        
                        if self.cancelOnDismiss { return }
                        ///return on download fail
                        if failed { self.showFailedDownloadAlert(); return }
                        if result == UIImage() { return } /// canceled
                        
                        ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                        if parentVC.selectedObjects.count < 5 {
                            
                            /// append new image object with fetched image
                            let newObject = (ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, stillImage: result, animationImages: [], gifMode: false, creationDate: selectedObject.creationDate), index)
                            cell.removeActivityIndicator()
                            
                            if !circleTap {
                                self.addPreviewView(object: newObject.0, selectedIndex: 0, galleryIndex: index)
                            } else {
                                parentVC.selectedObjects.append(newObject)
                                self.checkForNext()
                                DispatchQueue.main.async {
                                    if self.cancelOnDismiss { return }
                                    self.collectionView.reloadItems(at: paths)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getSelectedPaths(newRow: Int) -> [IndexPath] {
        
        var selectedPaths: [IndexPath] = []
        guard let parentVC = parent as? PhotosContainerController else { return selectedPaths }
        let selectedRows = parentVC.selectedObjects.map({$0.index})
        for row in selectedRows { selectedPaths.append(IndexPath(item: row, section: 0)) }
        let newPath = IndexPath(item: newRow, section: 0)
        if !selectedPaths.contains(where: {$0 == newPath}) { selectedPaths.append(newPath) }
        return selectedPaths
    }
    
    func addPreviewView(object: ImageObject, selectedIndex: Int, galleryIndex: Int) {

        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)

        let width = UIScreen.main.bounds.width - 50
        let pY = UIScreen.main.bounds.height/2 - width * 0.667
        
        previewView = GalleryPreviewView(frame: CGRect(x: 25, y: pY, width: width, height: width * 1.3333))
        previewView.isUserInteractionEnabled = true
        previewView.picker = self
        previewView.setUp(object: object, selectedIndex: selectedIndex, galleryIndex: galleryIndex)
        maskView.addSubview(previewView)
    }
        
    func checkForNext() {
        guard let parentVC = parent as? PhotosContainerController else { return }
        if parentVC.selectedObjects.count == 1 { parentVC.addNextButton() }
    }
    
    func showMaxImagesAlert() {
        
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 200, width: UIScreen.main.bounds.width, height: 32))
        let errorLabel = UILabel(frame: CGRect(x: 23, y: 6, width: UIScreen.main.bounds.width - 46, height: 18))

        errorBox.backgroundColor = UIColor.lightGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "5 photos max"
        errorLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        
        view.addSubview(errorBox)
        errorBox.addSubview(errorLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            errorLabel.removeFromSuperview()
            errorBox.removeFromSuperview()
        }
    }
    
    func fetchLivePhoto(item: Int, isLocal: Bool, selected: Bool, completion: @escaping(_ animationImages: [UIImage], _ stillImage: UIImage, _ failed: Bool) -> Void) {
        
        var stillImage = UIImage()
        var animationImages: [UIImage] = []
        let currentAsset = imageObjects[item].asset
        var downloadCount = 0
        
        let editingOptions = PHContentEditingInputRequestOptions()
        editingOptions.isNetworkAccessAllowed = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            /// download live photos by cycling through frame processor and capturing frames
            self.contentRequestID = currentAsset.requestContentEditingInput(with: editingOptions) { [weak self] input, info in
                
                guard let self = self else { return }
                
                if info["PHContentEditingInputCancelledKey"] != nil { completion([UIImage()], UIImage(), false); return }
                if info["PHContentEditingInputErrorKey"] != nil { completion([UIImage()], UIImage(), true); return }
                
                var frameImages: [UIImage] = []
                
                if let input = input {
                    
                    self.context = PHLivePhotoEditingContext(livePhotoEditingInput: input)
                    
                    self.context!.frameProcessor = { frame, _ in
                        frameImages.append(UIImage(ciImage: frame.image))
                        return frame.image
                    }
                                    
                    let output = PHContentEditingOutput(contentEditingInput: input)

                    self.context?.saveLivePhoto(to: output, options: nil, completionHandler: { [weak self] success, err in

                        guard let self = self else { return }
                        if !success || err != nil || frameImages.isEmpty { completion([UIImage()], UIImage(), false); return }
                        
                                                
                        let distanceBetweenFrames = frameImages.count < 20 ? 3 : frameImages.count < 40 ? 4 : 5
                        let rawFrames = frameImages.count / distanceBetweenFrames
                        let numberOfFrames = rawFrames > 12 ? 10 : rawFrames > 8 ? max(8, rawFrames - 2) : rawFrames
                        let offset = max((rawFrames - numberOfFrames) * distanceBetweenFrames/2, 2)
                                     
                        let aspect = frameImages[0].size.height / frameImages[0].size.width
                        let size = CGSize(width: min(frameImages[0].size.width, UIScreen.main.bounds.width * 1.5), height: min(frameImages[0].size.height, aspect * UIScreen.main.bounds.width * 1.5))

                        let image0 = self.ResizeImage(with: frameImages[offset], scaledToFill: size)
                        animationImages.append(image0 ?? UIImage())

                        /// add middle frames, trimming first couple and last couple
                        let intMultiplier = (frameImages.count - offset)/numberOfFrames
                        for i in 1...numberOfFrames {
                            let multiplier = offset + intMultiplier * i
                            let j = multiplier > frameImages.count - 1 ? frameImages.count - 1 : multiplier
                            let image = self.ResizeImage(with: frameImages[j], scaledToFill: size)
                            animationImages.append(image ?? UIImage())
                        }
                        
                        downloadCount += 1
                        if downloadCount == 2 { DispatchQueue.main.async { completion(animationImages, stillImage, false) } }
                        return
                    })
                }
            }
        
            /// download still image regularly
            self.fetchImage(item: item, isLocal: isLocal, selected: selected) { result, failed in
                
                if failed || result == UIImage() { completion([UIImage()], UIImage(), false); return }
                stillImage = result
                
                downloadCount += 1
                if downloadCount == 2 { DispatchQueue.main.async { completion(animationImages, stillImage, false) } }
            }
        }
    }
    
    func fetchImage(item: Int, isLocal: Bool, selected: Bool, completion: @escaping(_ result: UIImage, _ failed: Bool) -> Void) {
        
        let currentAsset = imageObjects[item].asset
        
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
                    
                    /// update with new image, set thumbnail to false
                    self.imageObjects[item] = (ImageObject(asset: self.imageObjects[item].asset, rawLocation: self.imageObjects[item].rawLocation, stillImage: resizedImage ?? UIImage(), animationImages: [], gifMode: false, creationDate: self.imageObjects[item].creationDate))
                    completion(resizedImage ?? UIImage(), false)
                    return
                }
            }
        }
    }
    
    func showFailedDownloadAlert() {
        let alert = UIAlertController(title: "Unable to download image from iCloud", message: "\n Your iPhone storage may be full", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                                        switch action.style{
                                        case .default:
                                            print("ok")
                                        case .cancel:
                                            print("cancel")
                                        case .destructive:
                                            print("destruct")
                                        @unknown default:
                                            fatalError()
                                        }}))
        present(alert, animated: true)
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //max offset is the value at which the tableview should reload data -> starting point is after 700 of the first 1000 pictures
        guard let parentVC = parent as? PhotosContainerController else { return }

        offset = scrollView.contentOffset.y
        if offset > maxOffset && refreshSafe {
            //refresh after 900 posts past the 1000x mark
            self.maxOffset = (UIScreen.main.bounds.width/4 * 225) + UIScreen.main.bounds.width/4 * (250 * CGFloat(self.refreshes))
            if self.imageObjects.count < parentVC.assetsFull.count {
                refreshSafe = false
                var indexSet: IndexSet!
                if refreshes > 8 {
                    self.fullGallery = true
                    DispatchQueue.main.async { self.collectionView.reloadData() }
                    return
                }
                self.refreshes = self.refreshes + 1
                if parentVC.assetsFull.count > (self.refreshes + 1) * 1000 {
                    indexSet =  IndexSet(self.refreshes * 1000 ... ((self.refreshes + 1) * 1000) - 1)
                } else {
                    indexSet = IndexSet(self.refreshes * 1000 ... parentVC.assetsFull.count - 1)
                    self.fullGallery = true
                }
                self.fetchAssets(indexSet: indexSet, first: false)
            }
        }
    }
    
    // for .limited photoGallery access
    func photoLibraryDidChange(_ changeInstance: PHChange) {

        DispatchQueue.main.async {
         
            if changeInstance.changeDetails(for: self.assetsFirst) != nil {
              /// couldn't get change handler to work so just reload everything for now
                self.imageObjects.removeAll()
                self.collectionView.reloadData()
                self.getGalleryImages()
            }
        }
    }
}


class GalleryCell: UICollectionViewCell {
    
    var image: UIImageView!
    var imageMask: UIView!
    var circleView: CircleView!
    lazy var activityIndicator = UIActivityIndicatorView()
    
    var globalRow: Int!
    var thumbnailSize: CGSize!
    lazy var requestID: Int32 = 1
    lazy var imageManager = PHCachingImageManager()
    var liveIndicator: UIImageView!
    
    func setUp(asset: PHAsset, row: Int, index: Int, editSpot: Bool) {
        
        self.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        self.globalRow = row
        
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        layer.borderWidth = 1
        layer.borderColor = UIColor(named: "SpotBlack")?.cgColor
        isOpaque = true
        
        setUpThumbnailSize()
        resetCell()
        
        image = UIImageView(frame: self.bounds)
        image.image = UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1), size: thumbnailSize)
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = false
        addSubview(image)
                
        /// add mask for selected images
        if index != 0 {
            imageMask = UIView(frame: self.bounds)
            imageMask.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
            addSubview(imageMask)
        }
        
        if asset.mediaSubtypes.contains(.photoLive) && !editSpot {
            liveIndicator = UIImageView(frame: CGRect(x: self.bounds.midX - 9, y: self.bounds.midY - 9, width: 18, height: 18))
            liveIndicator.image = UIImage(named: "PreviewGif")
            addSubview(liveIndicator)
        }
        
        addCircle(index: index)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            guard let self = self else { return }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            self.requestID = self.imageManager.requestImage(for: asset, targetSize: self.thumbnailSize, contentMode: .aspectFill, options: options) { (result, info) in
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if row != self.globalRow { return }
                    if result != nil { self.image.image = result! }
                }
            }
        }
    }
    
    private func setUpThumbnailSize() {
        let scale = UIScreen.main.scale * 0.75
        thumbnailSize = CGSize(width: self.bounds.width * scale, height: self.bounds.height * scale)
    }
    
    ///https://stackoverflow.com/questions/40226949/ios-phimagemanager-cancelimagerequest-not-working
    
    
    func addActivityIndicator() {
        if activityIndicator.superview != nil { activityIndicator.startAnimating(); return }
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.startAnimating()
        addSubview(activityIndicator)
        bringSubviewToFront(activityIndicator)
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageManager.cancelImageRequest(requestID)
        image.image = nil
        if imageMask != nil { imageMask.backgroundColor = nil }
    }
    
    deinit {
        imageManager.cancelImageRequest(requestID)
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ScrollGallery"), object: nil)
    }
    
    func resetCell() {
        
        if image != nil { image.image = nil }
        if circleView != nil { for sub in circleView.subviews {sub.removeFromSuperview()}; circleView = CircleView() }
        if liveIndicator != nil { liveIndicator.image = UIImage() }
        
        if self.gestureRecognizers != nil {
            for gesture in self.gestureRecognizers! {
                self.removeGestureRecognizer(gesture)
            }
        }
    }

    func addCircle(index: Int) {

        circleView = CircleView(frame: CGRect(x: bounds.width - 27, y: 6, width: 23, height: 23))
        circleView.setUp(index: index)
        addSubview(circleView)
        
        let circleButton = UIButton(frame: CGRect(x: bounds.width - 33, y: 0, width: 33, height: 33))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(circleButton)
    }
    
    @objc func circleTap(_ sender: UIButton) {
        guard let picker = viewContainingController() as? PhotoGalleryPicker else { pickFromCluster(); return }
        guard let container = picker.parent as? PhotosContainerController else { return }
        
        let selectedRows = container.selectedObjects.map({$0.index})
        var selectedPaths: [IndexPath] = []
        for row in selectedRows { selectedPaths.append(IndexPath(item: row, section: 0)) }
        let newPath = IndexPath(item: globalRow, section: 0)
        if !selectedPaths.contains(where: {$0 == newPath}) { selectedPaths.append(newPath) }

        container.selectedObjects.contains(where: {$0.index == globalRow}) ? picker.deselect(index: globalRow, circleTap: true) : picker.select(index: globalRow, circleTap: true)
    }
    
    func pickFromCluster() {
        
        guard let cluster = viewContainingController() as? ClusterPickerController else { return }
        
        let selectedRows = cluster.selectedObjects.map({$0.index})
        var selectedPaths: [IndexPath] = []
        for row in selectedRows { selectedPaths.append(IndexPath(item: row, section: 0)) }
        let newPath = IndexPath(item: globalRow, section: 0)
        if !selectedPaths.contains(where: {$0 == newPath}) { selectedPaths.append(newPath) }

        cluster.selectedObjects.contains(where: {$0.index == globalRow}) ? cluster.deselect(index: globalRow, circleTap: true) : cluster.select(index: globalRow, circleTap: true)
    }
}

class galleryActivityIndicator: UICollectionReusableView {
    
    var activityIndicator: CustomActivityIndicator!
    
    func setUp(animate: Bool) {
        
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: 30))
        self.addSubview(activityIndicator)
        
        if animate {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

///https://stackoverflow.com/questions/26542035/create-uiimage-with-solid-color-in-swift
public extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

class CircleView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(index: Int) {
        layer.borderWidth = 1.25
        isUserInteractionEnabled = false
        layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.85).cgColor
        layer.cornerRadius = bounds.width/2
        
        if index > 0 {
            
            backgroundColor = UIColor(red: 0.03, green: 0.604, blue: 0.604, alpha: 0.8)
            
            let minY: CGFloat = bounds.height > 25 ? 5.5 : 4
            let number = UILabel(frame: CGRect(x: 0, y: minY, width: bounds.width, height: 15))
            number.text = String(index)
            number.textColor = .white
            number.font = UIFont(name: "SFCamera-Semibold", size: 14)
            number.textAlignment = .center
            addSubview(number)
            
        } else { backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15) }
    }
}

class GalleryPreviewView: UIView {
    
    var imageView: UIImageView!
    var imageMask: UIView!
    var selectButton: UIButton!
    var aliveToggle: UIButton!
    
    var circleView: CircleView!
    var object: ImageObject!
    var selectedIndex = 0
    var galleryIndex = 0
    
    unowned var picker: PhotoGalleryPicker!
    unowned var cluster: ClusterPickerController!
    
    func setUp(object: ImageObject, selectedIndex: Int, galleryIndex: Int) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        layer.cornerRadius = 9
        layer.masksToBounds = true
        
        self.selectedIndex = selectedIndex
        self.object = object
        self.galleryIndex = galleryIndex
                
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll() }
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height))
        imageView.layer.cornerRadius = 9
        
        let images = !object.gifMode ? [object.stillImage] : object.animationImages
        let aspect = images.first!.size.height / images.first!.size.width
        imageView.contentMode = aspect > 1.3 ? .scaleAspectFill : .scaleAspectFit
        addSubview(imageView)

        if !object.gifMode {
            imageView.image = images.first!
        } else {
            imageView.animationImages = images
            /// only animate for active index
            if frame.minX == 25 { imageView.animateGIF(directionUp: true, counter: 0, frames: images.count) } else { imageView.image = images.first! }
        }
        
        if aspect > 1.1 { imageView.addTopMask() }

        if selectButton != nil { selectButton.setTitle("", for: .normal) }
        selectButton = UIButton(frame: CGRect(x: bounds.width - 150, y: 18, width: 100, height: 20))
        let title = selectedIndex > 0 ? "Selected" : "Select"
        selectButton.setTitle(title, for: .normal)
        selectButton.contentHorizontalAlignment = .right
        selectButton.contentVerticalAlignment = .center
        selectButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(selectButton)
        
        if circleView != nil { for sub in circleView.subviews { sub.removeFromSuperview()}; circleView = CircleView() }
        circleView = CircleView(frame: CGRect(x: bounds.width - 41, y: 15, width: 26, height: 26))
        let index = selectedIndex
        circleView.setUp(index: index)
        addSubview(circleView)
        
        let circleButton = UIButton(frame: CGRect(x: bounds.width - 46, y: 10, width: 36, height: 36))
        circleButton.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
        addSubview(circleButton)
        
        if !object.animationImages.isEmpty {
            if aliveToggle != nil { aliveToggle.setImage(UIImage(), for: .normal) }
            aliveToggle = UIButton(frame: CGRect(x: self.bounds.width - 86, y: self.bounds.height - 49, width: 81, height: 44))
            aliveToggle.setImage(UIImage(named: "AliveToggle"), for: .normal)
            aliveToggle.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            aliveToggle.alpha = object.gifMode ? 1.0 : 0.5
            aliveToggle.addTarget(self, action: #selector(toggleAlive(_:)), for: .touchUpInside)
            addSubview(aliveToggle)
        }
    }
    
    @objc func circleTap(_ sender: UIButton) {

        
        let selected = selectedIndex == 0
        let text = selected ? "Selected" : "Select"
        selectButton.setTitle(text, for: .normal)
        
        if picker != nil, let container = picker.parent as? PhotosContainerController {
            selected ? picker.select(index: galleryIndex, circleTap: true) : picker.deselect(index: galleryIndex, circleTap: true)
            selectedIndex = selected ? container.selectedObjects.count : 0
        } else if cluster != nil {
            selected ? cluster.select(index: galleryIndex, circleTap: true) : cluster.deselect(index: galleryIndex, circleTap: true)
            selectedIndex = selected ? cluster.selectedObjects.count : 0
        }
                
        for sub in circleView.subviews { sub.removeFromSuperview() }
        circleView.setUp(index: selectedIndex)
        addSubview(circleView)
    }
    
    @objc func toggleAlive(_ sender: UIButton) {
                
        object.gifMode = !object.gifMode
        aliveToggle.alpha = object.gifMode ? 1.0 : 0.5
        
        if object.gifMode {
            /// animate with gif images
            imageView.animationImages = object.animationImages
            imageView.animateGIF(directionUp: true, counter: 0, frames: object.animationImages.count)
        } else {
            /// remove to stop animation and set to still image
            imageView.isHidden = true
            imageView.image = object.stillImage
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak self] in
                guard let self = self else { return }
                self.imageView.isHidden = false
            }
        }
        
        if picker != nil, let container = picker.parent as? PhotosContainerController {
            picker.imageObjects[galleryIndex].gifMode = object.gifMode
            if selectedIndex > 0 { container.selectedObjects[selectedIndex - 1].object.gifMode = object.gifMode } /// adjust selected objects if object was selected
            
        } else if cluster != nil {
            cluster.imageObjects[galleryIndex].gifMode = object.gifMode
            if selectedIndex > 0 { cluster.selectedObjects[selectedIndex - 1].object.gifMode = object.gifMode } /// adjust selected objects if object was selected
        }
    }
}
