
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
    var assetsFull: PHFetchResult<PHAsset>!
    var assetsFirst: PHFetchResult<PHAsset>!
    
    var refreshSafe = false
    var fullGallery = false 
    var refreshes = 0
    
    var maskView: UIView!
    var previewView: UIImageView!
    
    var downloadCircle: UIActivityIndicatorView!
    var isFetching = false
    
    override func viewWillAppear(_ animated: Bool) {
        navigationItem.title = "Photo gallery"
        guard let parentVC = parent as? PhotosContainerController else { return }
        parentVC.mapVC.customTabBar.tabBar.isHidden = true
    }
    
    
    deinit {
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
        collectionView.allowsMultipleSelection = true
        self.collectionView.allowsSelection = true
        collectionView.setCollectionViewLayout(layout, animated: false)
        view.addSubview(collectionView)
        
        previewView = UIImageView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        maskView = UIView(frame: CGRect(x: 0, y: -100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height + 200))
        maskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maskTap(_:))))
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
    
    @objc func scrollToTop(_ sender: NSNotification) {
        collectionView.setContentOffset(CGPoint(x: 0, y: 10), animated: true)
    }
    
    func getGalleryImages() {
        
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
        
        self.fetchAssets(indexSet: indexSet, first: true)
        
        ///assets full are for reloads and map gallery
        fetchOptions.fetchLimit = 10000
        assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
    }
    
    func fetchAssets(indexSet: IndexSet, first: Bool) {
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        
        var fetchObject: PHFetchResult<PHAsset>!
        if first {
            fetchObject = self.assetsFirst
        } else {
            fetchObject = self.assetsFull
        }
        
        /// try not specifiying queue until reload
        DispatchQueue.global(qos: .userInitiated).async { fetchObject.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            guard let self = self else { return }
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            if self.imageObjects.contains(where: {$0.asset == object}) { return }
            let imageObj = ImageObject(asset: object, rawLocation: location, image: UIImage(), creationDate: creationDate)
            self.imageObjects.append(imageObj)
            
            if self.imageObjects.count == (self.refreshes + 1) * 1000 || (self.assetsFull != nil && self.imageObjects.count == self.assetsFull.count) {
                
                self.imageObjects.sort(by: {$0.creationDate > $1.creationDate})
                
                if first {
                    DispatchQueue.main.async {
                        guard let parentVC = self.parent as? PhotosContainerController else { return }
                        parentVC.assetsFull = self.assetsFull
                        parentVC.assetsFetched()
                    }
                }
                
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    self.refreshSafe = true
                }
            }
        }
        }
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
        self.maskView.removeFromSuperview()
        self.previewView.removeFromSuperview()
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
        let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footerView", for: indexPath) as! galleryActivityIndicator
        if self.assetsFull != nil && self.imageObjects.count == self.assetsFull.count  || fullGallery {
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
        if parentVC.segmentedControl.selectedSegmentIndex == 1 { return cell }
        // cell.image = nil
        
        if let imageObject = imageObjects[safe: indexPath.row] {
            cell.setUp(asset: imageObject.asset, row: indexPath.row)
            
            if parentVC.selectedObjects.contains(where: {$0.index == indexPath.row}) {
                let index = parentVC.selectedObjects.lastIndex(where: {$0.index == indexPath.row})
                cell.addGreenFrame(count: index! + 1)
            } else {
                cell.addBlackFrame()
            }
            
            let press = UILongPressGestureRecognizer(target: self, action: #selector(pressAndHold(_:)))
            press.accessibilityLabel = String(indexPath.row)
            cell.addGestureRecognizer(press)
        }
        
        return cell
    }
    
    @objc func pressAndHold(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let path = Int(sender.accessibilityLabel ?? "0")
            
            /// if the image is already fetched, add it to the preview view right away
            if imageObjects[path ?? 0].image != UIImage() {
                let result = self.imageObjects[path ?? 0].image
                let aspect = result.size.height / result.size.width
                let height = UIScreen.main.bounds.width * aspect
                self.previewView.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: height)
                self.previewView.layer.cornerRadius = 12
                self.previewView.clipsToBounds = true
                self.previewView.image = result
                self.view.addSubview(self.previewView)
                
            } else {
                /// add download view, fetch image
                downloadCircle = UIActivityIndicatorView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 150, width: 200, height: 200))
                downloadCircle.color = .white
                
                let currentAsset = self.imageObjects[path ?? 0].asset
                var local = false
                let resourceArray = PHAssetResource.assetResources(for: currentAsset)
                
                /// isLocal represents whether the image is available locally or needs to be fetched from iCloud
                if let isLocal = resourceArray.first?.value(forKey: "locallyAvailable") as? Bool {
                    local = isLocal
                }
                
                if isFetching { return }
                maskView.addSubview(self.downloadCircle)
                downloadCircle.startAnimating()
                
                view.addSubview(self.maskView)
                
                isFetching = true
                fetchImage(item: path ?? 0, isLocal: local, selected: false) { result, failed in
                    
                    self.isFetching = false
                    self.downloadCircle.stopAnimating()
                    
                    ///return on download fail, show alert to notify user
                    if failed { self.showFailedDownloadAlert(); return }
                    
                    let aspect = result.size.height / result.size.width
                    let height = UIScreen.main.bounds.width * aspect
                    if self.maskView.superview == nil { return }
                    if aspect > 1 {
                        self.previewView.frame = CGRect(x: 0, y: 10, width: UIScreen.main.bounds.width, height: height)
                    } else {
                        self.previewView.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: height)
                    }
                    
                    self.previewView.layer.cornerRadius = 12
                    self.previewView.clipsToBounds = true
                    self.previewView.image = result
                    self.view.addSubview(self.previewView)
                }
            }
        }
        
        if sender.state == .ended || sender.state == .cancelled {
            self.maskView.removeFromSuperview()
            self.previewView.removeFromSuperview()
        }
        
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
        guard let selectedObject = imageObjects[safe: indexPath.row] else { return }
        
        let selectedRows = parentVC.selectedObjects.map({$0.index})
        var selectedPaths: [IndexPath] = []
        for row in selectedRows { selectedPaths.append(IndexPath(item: row, section: 0)) }
        if !selectedPaths.contains(where: {$0 == indexPath}) { selectedPaths.append(indexPath) }
        
        if parentVC.selectedObjects.contains(where: {$0.index == indexPath.row}) {
            
            parentVC.selectedObjects.removeAll(where: {$0.index == indexPath.row})
            
            if parentVC.selectedObjects.count == 0 {
                parentVC.removeNextButton()
            }
            
            DispatchQueue.main.async { collectionView.reloadItems(at: selectedPaths) }
            
        } else {
            
            if parentVC.editSpotMode {
                if parentVC.selectedObjects.count > 0 { return }
            }
            
            if parentVC.selectedObjects.count < 5 {
                //existing pic appended to photo gallery on edit spot
                if editSpotCount > 0 && indexPath.row < editSpotCount {
                    parentVC.selectedObjects.append((selectedObject, indexPath.row))
                    self.checkForNext()
                    
                    DispatchQueue.main.async { collectionView.reloadItems(at: selectedPaths) }
                    //fetch full quality pic
                } else {
                    
                    if selectedObject.image != UIImage() {
                        parentVC.selectedObjects.append((selectedObject, indexPath.row))
                        self.checkForNext()
                        
                        DispatchQueue.main.async { collectionView.reloadItems(at: selectedPaths) }
                        
                    } else {
                        
                        if let cell = collectionView.cellForItem(at: indexPath) as? GalleryCell {
                            let currentAsset = self.imageObjects[indexPath.row].asset
                            var local = true
                            let resourceArray = PHAssetResource.assetResources(for: currentAsset)
                            if let isLocal = resourceArray.first?.value(forKey: "locallyAvailable") as? Bool {
                                local = isLocal
                            }
                            
                            if self.isFetching { return }
                            cell.addActivityIndicator()
                            
                            self.isFetching = true
                            self.fetchImage(item: indexPath.row, isLocal: local, selected: true) { result, failed  in
                                self.isFetching = false
                                cell.removeActivityIndicator()
                                
                                ///return on download fail
                                if failed { self.showFailedDownloadAlert(); return }
                                
                                //fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                                if parentVC.selectedObjects.count < 5 {
                                    
                                    /// append new image object with fetched image
                                    parentVC.selectedObjects.append((ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, image: result, creationDate: selectedObject.creationDate), indexPath.row))
                                    
                                    self.checkForNext()
                                    cell.removeActivityIndicator()
                                    
                                    DispatchQueue.main.async {  collectionView.reloadItems(at: selectedPaths) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkForNext() {
        guard let parentVC = parent as? PhotosContainerController else { return }
        if parentVC.selectedObjects.count == 1 { parentVC.addNextButton() }
    }
    
    func fetchImage(item: Int, isLocal: Bool, selected: Bool, completion: @escaping(_ result: UIImage, _ failed: Bool) -> Void) {
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let currentAsset = self.imageObjects[item].asset
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            PHCachingImageManager.default().requestImage(for: currentAsset,
                                                         targetSize: CGSize(width: currentAsset.pixelWidth, height: currentAsset.pixelHeight),
                                                         contentMode: .aspectFill,
                                                         options: options) { (image, info) in
                
                DispatchQueue.main.async {
                    /// return blank image on error
                    guard let self = self else { completion(UIImage(), true); return}
                    guard let result = image else { completion( UIImage(), true); return }
                    
                    /// update with new image, set thumbnail to false
                    self.imageObjects[item] =  (ImageObject(asset: self.imageObjects[item].asset, rawLocation: self.imageObjects[item].rawLocation, image: result, creationDate: self.imageObjects[item].creationDate))
                    completion(result, false)
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
        offset = scrollView.contentOffset.y
        if offset > maxOffset && refreshSafe {
            //refresh after 900 posts past the 1000x mark
            self.maxOffset = (UIScreen.main.bounds.width/4 * 225) + UIScreen.main.bounds.width/4 * (250 * CGFloat(self.refreshes))
            if self.imageObjects.count < self.assetsFull.count {
                refreshSafe = false
                var indexSet: IndexSet!
                if refreshes > 8 {
                    self.fullGallery = true
                    DispatchQueue.main.async { self.collectionView.reloadData() }
                    return
                }
                self.refreshes = self.refreshes + 1
                if assetsFull.count > (self.refreshes + 1) * 1000 {
                    indexSet =  IndexSet(self.refreshes * 1000 ... ((self.refreshes + 1) * 1000) - 1)
                } else {
                    indexSet = IndexSet(self.refreshes * 1000 ... assetsFull.count - 1)
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
    var line1: UIView!
    var line2: UIView!
    var line3: UIView!
    var line4: UIView!
    var number: UILabel!
    var shadow: UIView!
    var activityIndicator: UIActivityIndicatorView!
    
    var globalRow: Int!
    var thumbnailSize: CGSize!
    lazy var requestID: Int32 = 1
    lazy var imageManager = PHCachingImageManager()
    
    func setUp(asset: PHAsset, row: Int) {
        
        self.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        self.globalRow = row
        
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        isOpaque = true
        
        setUpThumbnailSize()
        resetCell()
        
        image = UIImageView(frame: self.bounds)
        image.image = UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1), size: thumbnailSize)
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = false
        self.addSubview(image)
        
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
    
    func addBlackFrame() {
                
        if number != nil {number.text = ""}
        if shadow != nil {shadow.backgroundColor = nil}
        
        if line1 != nil {line1.backgroundColor = nil}
        line1 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.minY, width: 1, height: self.bounds.height))
        line1.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(line1)
        
        if line2 != nil {line2.backgroundColor = nil}
        line2 = UIView(frame: CGRect(x: self.bounds.maxX - 1, y: self.bounds.minY, width: 1, height: self.bounds.height))
        line2.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(line2)
        
        if line3 != nil {line3.backgroundColor = nil}
        line3 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.minY, width: self.bounds.width, height: 1))
        line3.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(line3)
        
        if line4 != nil {line4.backgroundColor = nil}
        line4 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.maxY - 1, width: self.bounds.width, height: 1))
        line4.backgroundColor = UIColor(named: "SpotBlack")
        self.addSubview(line4)
    }
    
    func addGreenFrame(count: Int) {
        
        if line1 != nil {line1.backgroundColor = nil}
        line1 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.minY, width: 3, height: self.bounds.height))
        line1.backgroundColor = UIColor(named: "SpotGreen")
        self.addSubview(line1)
        
        if line2 != nil {line2.backgroundColor = nil}
        line2 = UIView(frame: CGRect(x: self.bounds.maxX - 3, y: self.bounds.minY, width: 3, height: self.bounds.height))
        line2.backgroundColor = UIColor(named: "SpotGreen")
        self.addSubview(line2)
        
        if line3 != nil {line3.backgroundColor = nil}
        line3 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.minY, width: self.bounds.width, height: 3))
        line3.backgroundColor = UIColor(named: "SpotGreen")
        self.addSubview(line3)
        
        if line4 != nil {line4.backgroundColor = nil}
        line4 = UIView(frame: CGRect(x: self.bounds.minX, y: self.bounds.maxY - 3, width: self.bounds.width, height: 3))
        line4.backgroundColor = UIColor(named: "SpotGreen")
        self.addSubview(line4)
        
        if count != 0 {
            number = UILabel(frame: CGRect(x: self.bounds.width/2 - 8, y: self.bounds.height/2 - 15, width: 16, height: 16))
            number.font = UIFont(name: "SFCamera-Semibold", size: 30)
            number.text = String(count)
            number.textColor = UIColor(named: "SpotGreen")
            number.sizeToFit()
            
            shadow = UIView(frame: CGRect(x: self.bounds.minY + 3, y: self.bounds.minY + 3, width: self.bounds.width - 6, height: self.bounds.height - 6))
            shadow.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            shadow.isUserInteractionEnabled = false
            
            self.addSubview(shadow)
            self.addSubview(number)
            
            self.isUserInteractionEnabled = true
            image.isUserInteractionEnabled = false
        }
    }
    
    func addActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        addSubview(activityIndicator)
    }
    
    func removeActivityIndicator() {
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageManager.cancelImageRequest(requestID)
        image.image = nil
    }
    
    deinit {
        imageManager.cancelImageRequest(requestID)
    }
    
    func resetCell() {
        
        if image != nil {image.image = nil}
        if number != nil {number.text = ""}
        if line1 != nil {line1.backgroundColor = nil}
        if line2 != nil {line2.backgroundColor = nil}
        if line3 != nil {line3.backgroundColor = nil}
        if line4 != nil {line4.backgroundColor = nil}
        if shadow != nil {shadow.backgroundColor = nil}
        
        if self.gestureRecognizers != nil {
            for gesture in self.gestureRecognizers! {
                self.removeGestureRecognizer(gesture)
            }
        }
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
