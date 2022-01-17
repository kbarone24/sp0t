
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

class PhotoGalleryPicker: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver {
    
    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    lazy var imageManager = PHCachingImageManager()
    
    var baseSize: CGSize!
    let options = PHImageRequestOptions()
    
    var editSpotCount = 0
    var offset: CGFloat = 0
    var maxOffset: CGFloat = (UIScreen.main.bounds.width/4 * 75)
    
    var fullGallery = false
    var refreshes = 0
    
    var imagePreview: ImagePreviewView!
    
    var downloadCircle: UIActivityIndicatorView!
    var cancelOnDismiss = false
    
    lazy var imageFetcher = ImageFetcher()
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        navigationItem.title = "Photo gallery"
        cancelOnDismiss = false
    }
    
    deinit {
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ScrollGallery"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "galleryCell")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        
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
        collectionView.scrollsToTop = false
        view.addSubview(collectionView)
                
        NotificationCenter.default.addObserver(self, selector: #selector(scrollToTop(_:)), name: NSNotification.Name("ScrollGallery"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(removePreview(_:)), name: NSNotification.Name("PreviewRemove"), object: nil)
        
        if !UploadImageModel.shared.imageObjects.isEmpty { refreshTable() } /// eventually need exemption handling for reloading once != 0
        
        if UploadImageModel.shared.galleryAccess == .limited {
            PHPhotoLibrary.shared().register(self) /// eventually probably want to do this after
            showLimitedAlert()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        /// reset nav bar colors (only set if limited picker was shown)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)
        
        cancelOnDismiss = true
        removePreviews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhotoGalleryOpen")
    }
    
    @objc func scrollToTop(_ sender: NSNotification) {
        collectionView.setContentOffset(CGPoint(x: 0, y: 10), animated: true)
    }
        
    func refreshTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.collectionView.reloadData()
        }
    }
    
    func showLimitedAlert() {
        
        let alert = UIAlertController(title: "You've allowed access to a limited number of photos", message: "", preferredStyle: .alert)
        
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
    
    func removePreviews() {
                
        /// remove saved images from image objects to avoid memory pile up
        if imagePreview != nil && imagePreview.selectedIndex == 0 {
            if let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.0.id == imagePreview.imageObjects.first?.id}) {
                UploadImageModel.shared.imageObjects[i].0.animationImages.removeAll()
                UploadImageModel.shared.imageObjects[i].0.stillImage = UIImage()
            }
        }
        
        if imagePreview != nil { for sub in imagePreview.subviews { sub.removeFromSuperview()}; imagePreview.removeFromSuperview(); imagePreview = nil }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let maxImages = (refreshes + 1) * 1000
        let imageCount = UploadImageModel.shared.imageObjects.count
        return min(maxImages, imageCount)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "galleryCell", for: indexPath) as! GalleryCell
        
        if let imageObject = UploadImageModel.shared.imageObjects[safe: indexPath.row] {
            
            var index = 0
            if let trueIndex = UploadImageModel.shared.selectedObjects.lastIndex(where: {$0.id == imageObject.0.id}) { index = trueIndex + 1 }
            cell.setUp(asset: imageObject.0.asset, row: indexPath.row, index: index, editSpot: false, id: imageObject.0.id, cameraImage: imageObject.0.stillImage)
            
            /// set cellImage from here -> processes weren't consistently offloading with deinit 
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                cell.requestID = self.imageManager.requestImage(for: imageObject.0.asset, targetSize: self.baseSize, contentMode: .aspectFill, options: self.options) { (result, info) in
                    DispatchQueue.main.async { if result != nil { cell.image.image = result! } }
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
        
        let imageObject = UploadImageModel.shared.imageObjects[indexPath.row]
        
        if UploadImageModel.shared.selectedObjects.contains(where: {$0.id == imageObject.image.id}) {
            deselect(index: indexPath.row, circleTap: false)
            
        } else {
            select(index: indexPath.row, circleTap: false)
        }
    }
    
    func deselect(index: Int, circleTap: Bool) {
        
        let paths = getSelectedPaths(newRow: index)
        guard let selectedObject = UploadImageModel.shared.imageObjects[safe: index]?.image else { return }
        
        if !circleTap {
            self.addPreviewView(object: selectedObject, galleryIndex: index)
            
        } else {
            Mixpanel.mainInstance().track(event: "GallerySelectImage", properties: ["selected": false])
            UploadImageModel.shared.selectObject(imageObject: selectedObject, selected: false)
            DispatchQueue.main.async { self.collectionView.reloadItems(at: paths)
            }
        }
    }
    
    func select(index: Int, circleTap: Bool) {
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        guard let selectedObject = UploadImageModel.shared.imageObjects[safe: index]?.image else { return }
        if UploadImageModel.shared.selectedObjects.count > 4 { showMaxImagesAlert(); return }
        if parentVC.editSpotMode && UploadImageModel.shared.selectedObjects.count > 0 { return }
        
        let paths = getSelectedPaths(newRow: index)
        
        if selectedObject.stillImage != UIImage() {
            
            if !circleTap {
                self.addPreviewView(object: selectedObject, galleryIndex: index)
                
            } else {
                
                Mixpanel.mainInstance().track(event: "GallerySelectImage", properties: ["selected": true])
                UploadImageModel.shared.selectObject(imageObject: selectedObject, selected: true)
                DispatchQueue.main.async { self.collectionView.reloadItems(at: paths) }
            }
            
        } else {
            
            if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell {
                
                let currentAsset = UploadImageModel.shared.imageObjects[index].image.asset
                
                /// this cell is fetching, cancel fetch and return
                if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: index); return  }
                
                if imageFetcher.isFetching { cancelFetchForRowAt(index: imageFetcher.fetchingIndex) } /// another cell is fetching cancel that fetch
                cell.addActivityIndicator()
                
                imageFetcher.fetchImage(currentAsset: currentAsset, item: index) { [weak self] stillImage, failed  in
                    
                    guard let self = self else { return }
                    cell.removeActivityIndicator()
                    
                    if self.cancelOnDismiss { return }
                    ///return on download fail
                    if failed { self.showFailedDownloadAlert(); return }
                    if stillImage == UIImage() { return } /// canceled
                    
                    ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                    UploadImageModel.shared.imageObjects[index].image.stillImage = stillImage
                    
                    if UploadImageModel.shared.selectedObjects.count < 5 {
                        
                        /// append new image object with fetched image
                        
                        cell.removeActivityIndicator()
                        
                        if !circleTap {
                            self.addPreviewView(object: UploadImageModel.shared.imageObjects[index].image, galleryIndex: index)
                            
                        } else {
                            Mixpanel.mainInstance().track(event: "GalleryCircleTap", properties: ["selected": true])
                            UploadImageModel.shared.selectObject(imageObject: UploadImageModel.shared.imageObjects[index].image, selected: true)
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
    
    func cancelFetchForRowAt(index: Int) {
        
        Mixpanel.mainInstance().track(event: "GalleryCancelImageFetch")
        
        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell else { return }
        guard let currentObject = UploadImageModel.shared.imageObjects[safe: index]?.image else { return }
        let currentAsset = currentObject.asset
        
        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }
    
    func getSelectedPaths(newRow: Int) -> [IndexPath] {
        
        var selectedPaths: [IndexPath] = []
        for object in UploadImageModel.shared.selectedObjects {
            if let index = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == object.id}) {
                selectedPaths.append(IndexPath(item: Int(index), section: 0))
            }
        }
        
        let newPath = IndexPath(item: newRow, section: 0)
        if !selectedPaths.contains(where: {$0 == newPath}) { selectedPaths.append(newPath) }
        return selectedPaths
    }
    
    func addPreviewView(object: ImageObject, galleryIndex: Int) {
        
        guard let cell = collectionView.cellForItem(at: IndexPath(row: galleryIndex, section: 0)) as? GalleryCell else { return }
                        
        imagePreview = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        imagePreview.alpha = 0.0
        imagePreview.galleryCollection = collectionView
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(imagePreview)
                
        let frame = cell.superview?.convert(cell.frame, to: nil) ?? CGRect()
        imagePreview.imageExpand(originalFrame: frame, selectedIndex: 0, galleryIndex: galleryIndex, imageObjects: [object])
    }
    
    func showMaxImagesAlert() {
        
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 200, width: UIScreen.main.bounds.width, height: 32))
        let errorLabel = UILabel(frame: CGRect(x: 23, y: 6, width: UIScreen.main.bounds.width - 46, height: 18))
        
        errorBox.backgroundColor = UIColor.lightGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = "5 photos max"
        errorLabel.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        
        view.addSubview(errorBox)
        errorBox.addSubview(errorLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            errorLabel.removeFromSuperview()
            errorBox.removeFromSuperview()
        }
    }
    
    func showFailedDownloadAlert() {
        let alert = UIAlertController(title: "Unable to download image from iCloud", message: "\n Your iPhone storage may be full", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //max offset is the value at which the tableview should reload data -> starting point is after 700 of the first 1000 pictures
        offset = scrollView.contentOffset.y
        
        if offset > maxOffset {
            //refresh after 900 posts past the 1000x mark
            self.maxOffset = (UIScreen.main.bounds.width/4 * 225) + UIScreen.main.bounds.width/4 * (250 * CGFloat(self.refreshes))
            if (refreshes + 1) * 1000 < UploadImageModel.shared.imageObjects.count {
                self.refreshes = self.refreshes + 1
                self.refreshTable()
            }
        }
    }
    
    // for .limited photoGallery access
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        DispatchQueue.main.async {
            
            if changeInstance.changeDetails(for: UploadImageModel.shared.assetsFull) != nil {
                /// couldn't get change handler to work so just reload everything for now
                UploadImageModel.shared.imageObjects.removeAll()
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc func removePreview(_ sender: NSNotification) {
        if imagePreview != nil {
            imagePreview.removeFromSuperview()
            imagePreview = nil
        }
    }
}


class GalleryCell: UICollectionViewCell {
    
    var image: UIImageView!
    var imageMask: UIView!
    var circleView: CircleView!
    lazy var activityIndicator = UIActivityIndicatorView()
    
    var globalRow: Int!
    var asset: PHAsset!
    var id: String!
    var thumbnailSize: CGSize!
    lazy var requestID: Int32 = 1
    var liveIndicator: UIImageView!
    
    func setUp(asset: PHAsset, row: Int, index: Int, editSpot: Bool, id: String, cameraImage: UIImage) {
        
        self.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        self.asset = asset
        self.globalRow = row
        self.id = id
        
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
        
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        activityIndicator.color = .white
        activityIndicator.transform = CGAffineTransform(scaleX: 1.7, y: 1.7)
        activityIndicator.isHidden = true
        addSubview(activityIndicator)
        
        /// add mask for selected images
        if index != 0 { addImageMask() }
        
        if asset.mediaSubtypes.contains(.photoLive) && !editSpot {
            liveIndicator = UIImageView(frame: CGRect(x: self.bounds.midX - 9, y: self.bounds.midY - 9, width: 18, height: 18))
            liveIndicator.image = UIImage(named: "PreviewGif")
            addSubview(liveIndicator)
        }
        
        addCircle(index: index)
        if cameraImage != UIImage() { image.image = cameraImage; return } /// image from camera, set to image and return

    }
    
    private func addImageMask() {
        
        imageMask = UIView(frame: self.bounds)
        imageMask.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
        
        let layer = CAGradientLayer()
        layer.frame = imageMask.bounds
        layer.colors = [
            UIColor(red: 0.098, green: 0.783, blue: 0.701, alpha: 0.13).cgColor,
            UIColor(red: 0.098, green: 0.784, blue: 0.702, alpha: 0.03).cgColor,
            UIColor(red: 0.098, green: 0.784, blue: 0.702, alpha: 0.1).cgColor,
            UIColor(red: 0.098, green: 0.783, blue: 0.701, alpha: 0.33).cgColor
        ]
        layer.locations = [0, 0.3, 0.66, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        imageMask.layer.addSublayer(layer)
        
        addSubview(imageMask)
    }
    
    private func setUpThumbnailSize() {
        let scale = UIScreen.main.bounds.width * 1/4
        thumbnailSize = CGSize(width: scale, height: scale)
    }
    
    ///https://stackoverflow.com/questions/40226949/ios-phimagemanager-cancelimagerequest-not-working
    
    
    func addActivityIndicator() {
        bringSubviewToFront(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicator.stopAnimating()
        image.image = nil
        if imageMask != nil { for layer in imageMask.layer.sublayers ?? [] { layer.removeFromSuperlayer() } }
        if let galleryVC = viewContainingController() as? PhotoGalleryPicker {
            galleryVC.imageManager.cancelImageRequest(requestID)
        }
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
        UploadImageModel.shared.selectedObjects.contains(where: {$0.id == id}) ? picker.deselect(index: globalRow, circleTap: true) : picker.select(index: globalRow, circleTap: true)
    }
    
    func pickFromCluster() {
        
        guard let cluster = viewContainingController() as? ClusterPickerController else { return }
        UploadImageModel.shared.selectedObjects.contains(where: {$0.id == id}) ? cluster.deselect(index: globalRow, circleTap: true) : cluster.select(index: globalRow, circleTap: true)
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

