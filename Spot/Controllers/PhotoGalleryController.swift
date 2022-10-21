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

    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())

    lazy var imageManager = PHCachingImageManager()
    let options = PHImageRequestOptions()

    var editSpotCount = 0
    let thumbnailSize = CGSize(width: UIScreen.main.bounds.width / 4 - 0.1, height: (UIScreen.main.bounds.width / 3))
    var offset: CGFloat = 0
    var maxOffset: CGFloat = (UIScreen.main.bounds.width / 4 * 75) /// reload triggered at 300 images

    var fullGallery = false
    var refreshes = 0

    var imagePreview: ImagePreviewView!

    var downloadCircle: UIActivityIndicatorView!
    var cancelOnDismiss = false

    lazy var imageFetcher = ImageFetcher()

    deinit {
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ScrollGallery"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    override func viewDidLoad() {

        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        addCollectionView()

        NotificationCenter.default.addObserver(self, selector: #selector(removePreview(_:)), name: NSNotification.Name("PreviewRemove"), object: nil)
        /// check for limited gallery access
        print("gallery access", UploadPostModel.shared.galleryAccess == .denied, UploadPostModel.shared.galleryAccess == .limited, UploadPostModel.shared.galleryAccess == .restricted, UploadPostModel.shared.galleryAccess == .authorized, UploadPostModel.shared.galleryAccess == .notDetermined)
        if UploadPostModel.shared.galleryAccess == .limited {
            PHPhotoLibrary.shared().register(self) /// eventually probably want to do this after
            showLimitedAlert()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cancelOnDismiss = false
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PhotoGalleryOpen")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        /// reset nav bar colors (only set if limited picker was shown)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)

        cancelOnDismiss = true
        removePreviews()
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
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let layout = UICollectionViewFlowLayout {
            $0.scrollDirection = .vertical
            $0.minimumLineSpacing = 0.1
            $0.minimumInteritemSpacing = 0.1
            $0.sectionFootersPinToVisibleBounds = true
        }
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "galleryCell")
        collectionView.register(SelectedImagesFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "selectedFooter")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: -50, right: 0)
        collectionView.isUserInteractionEnabled = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsSelection = true
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.scrollsToTop = false
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func refreshTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.collectionView.reloadData()
        }
    }

    func removePreviews() {

        /// remove saved images from image objects to avoid memory pile up
        if imagePreview != nil && imagePreview.selectedIndex == 0 {
            if let i = UploadPostModel.shared.imageObjects.firstIndex(where: { $0.0.id == imagePreview.imageObjects.first?.id }) {
                UploadPostModel.shared.imageObjects[i].0.animationImages.removeAll()
                UploadPostModel.shared.imageObjects[i].0.stillImage = UIImage()
            }
        }

        if imagePreview != nil { for sub in imagePreview.subviews { sub.removeFromSuperview()}; imagePreview.removeFromSuperview(); imagePreview = nil }
    }

    func showLimitedAlert() {

        /// push user to settings to enable full access or to change their limited selection
        let alert = UIAlertController(title: "You've allowed access to a limited number of photos", message: "", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Allow access to all photos", style: .default, handler: { action in
            switch action.style {
            case .default:
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
            default: return
            }}))

        alert.addAction(UIAlertAction(title: "Select more photos", style: .default, handler: { action in
            switch action.style {
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
        // max offset is the value at which the tableview should reload data -> starting point is after 700 of the first 1000 pictures
        offset = scrollView.contentOffset.y

        if offset > maxOffset {
            // refresh after 900 posts past the 1000x mark
            self.maxOffset = (UIScreen.main.bounds.width / 4 * 225) + UIScreen.main.bounds.width / 4 * (250 * CGFloat(self.refreshes))
            if (refreshes + 1) * 1_000 < UploadPostModel.shared.imageObjects.count {
                self.refreshes = self.refreshes + 1
                self.refreshTable()
            }
        }
    }

    // for .limited photoGallery access
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            if changeInstance.changeDetails(for: UploadPostModel.shared.assetsFull) != nil {
                /// couldn't get change handler to work so just reload everything for now
                UploadPostModel.shared.imageObjects.removeAll()
                self.fetchGalleryAssets()
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
        if imagePreview != nil {
            imagePreview.removeFromSuperview()
            imagePreview = nil
        }
    }
}

extension PhotoGalleryController {
    func fetchGalleryAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 10_000

        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
                let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        let indexSet = assetsFull.count > 10_000 ? IndexSet(0...9_999) : IndexSet(0..<assetsFull.count)
        UploadPostModel.shared.assetsFull = assetsFull

        DispatchQueue.global(qos: .default).async { assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in

            guard let self = self else { return }
            if self.cancelOnDismiss { stop.pointee = true } /// cancel on dismiss = true when view is popped

            var location = CLLocation()
            if let l = object.location { location = l }

            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }

            let imageObj = (ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], animationIndex: 0, directionUp: true, gifMode: false, creationDate: creationDate, fromCamera: false), false)
            UploadPostModel.shared.imageObjects.append(imageObj)

            /// sort on final load
            let finalLoad = UploadPostModel.shared.imageObjects.count == assetsFull.count

            if finalLoad {
                UploadPostModel.shared.imageObjects.sort(by: { !$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected })
                DispatchQueue.main.async { self.collectionView.reloadData() }
            }
        }
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

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "galleryCell", for: indexPath) as! GalleryCell

        if let imageObject = UploadPostModel.shared.imageObjects[safe: indexPath.row] {
            let selected = UploadPostModel.shared.selectedObjects.contains(where: { $0.id == imageObject.0.id })
            cell.setUp(asset: imageObject.0.asset, row: indexPath.row, selected: selected, id: imageObject.0.id)

            /// set cellImage from here -> processes weren't consistently offloading with deinit
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                cell.requestID = self.imageManager.requestImage(for: imageObject.0.asset, targetSize: self.thumbnailSize, contentMode: .aspectFill, options: self.options) { (result, info) in
                    if info?["PHImageCancelledKey"] != nil { return }
                    DispatchQueue.main.async { if result != nil { cell.imageView.image = result! } }
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

        /// if image has been downloaded show preview right away
        if imageObject.stillImage != UIImage() {
            addPreviewView(object: imageObject, galleryIndex: indexPath.row)
        } else {
            /// download image to show in preview
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
        return UploadPostModel.shared.selectedObjects.count == 0 ? CGSize(width: UIScreen.main.bounds.width, height: 120) : CGSize(width: UIScreen.main.bounds.width, height: 220)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "selectedFooter", for: indexPath) as? SelectedImagesFooter {
            return footer
        }
        return UICollectionReusableView()
    }

    func downloadImage(index: Int, completion: @escaping (_ stillImage: UIImage) -> Void) {

        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell {

            let currentAsset = UploadPostModel.shared.imageObjects[index].image.asset

            /// this cell is fetching, cancel fetch and return
            if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: index); return  }

            /// fetch image is async so need to make sure another image wasn't appended while this one was being fetched
            if imageFetcher.isFetching { cancelFetchForRowAt(index: imageFetcher.fetchingIndex) } /// another cell is fetching cancel that fetch
            cell.addActivityIndicator()

            imageFetcher.fetchImage(currentAsset: currentAsset, item: index) { [weak self] stillImage, failed  in

                guard let self = self else { return }
                cell.removeActivityIndicator()

                if self.cancelOnDismiss { return }
                /// return on download fail
                if failed { self.showFailedDownloadAlert(); return }
                if stillImage == UIImage() { return } /// canceled

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

        /// deselect image on circle tap
        UploadPostModel.shared.selectObject(imageObject: selectedObject, selected: false)
        reloadItems(paths: paths)
    }

    func select(index: Int) {

        guard let selectedObject = UploadPostModel.shared.imageObjects[safe: index]?.image else { return }
        if UploadPostModel.shared.selectedObjects.count > 4 { return }

        let paths = getSelectedPaths(newRow: index, select: true)

        if selectedObject.stillImage != UIImage() {
            /// select image immediately
            UploadPostModel.shared.selectObject(imageObject: selectedObject, selected: true)
            reloadItems(paths: paths)

        } else {
            /// download image and select
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
        /// reload all visible if going from max / not max selected
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

    func addPreviewView(object: ImageObject, galleryIndex: Int) {
        Mixpanel.mainInstance().track(event: "GalleryPreviewTap")
        /// add ImagePreviewView over top of gallery
        guard let cell = collectionView.cellForItem(at: IndexPath(row: galleryIndex, section: 0)) as? GalleryCell else { return }

        imagePreview = ImagePreviewView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        imagePreview.alpha = 0.0
        imagePreview.delegate = self

        let window = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
        window?.addSubview(imagePreview)

        let frame = cell.superview?.convert(cell.frame, to: nil) ?? CGRect()
        imagePreview.imageExpand(originalFrame: frame, selectedIndex: 0, galleryIndex: galleryIndex, imageObjects: [object])
    }
}

extension PhotoGalleryController: ImagePreviewDelegate {
    func select(galleryIndex: Int) {
        select(index: galleryIndex)
    }

    func deselect(galleryIndex: Int) {
        deselect(index: galleryIndex)
    }
}

class GalleryCell: UICollectionViewCell {
    var imageView: UIImageView!
    lazy var activityIndicator = UIActivityIndicatorView()
    var circleView: CircleView!
    var imageMask: UIView?

    var globalRow: Int!
    var id: String!
    lazy var requestID: Int32 = 1
    var liveIndicator: UIImageView?

    var imageSelected: Bool = false {
        didSet {
            imageMask?.isHidden = !imageSelected
            circleView.selected = imageSelected
        }
    }

    var asset: PHAsset! {
        didSet {
            liveIndicator?.isHidden = !(asset.mediaSubtypes.contains(.photoLive))
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        layer.borderWidth = 1
        layer.borderColor = UIColor(named: "SpotBlack")?.cgColor
        isOpaque = true

        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpView() {
        imageView = UIImageView {
            $0.frame = self.bounds
            $0.image = UIImage(color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isUserInteractionEnabled = true
            contentView.addSubview($0)
        }
        imageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        activityIndicator = UIActivityIndicatorView {
            $0.color = .white
            $0.transform = CGAffineTransform(scaleX: 1.7, y: 1.7)
            $0.isHidden = true
            contentView.addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.height.width.equalTo(30)
            $0.centerX.centerY.equalToSuperview()
        }

        /// live indicator shows playbutton over image to indicate live capability on this image
        liveIndicator = UIImageView {
            $0.image = UIImage(named: "PreviewGif")
            $0.isHidden = true
            contentView.addSubview($0)
        }
        liveIndicator!.snp.makeConstraints {
            $0.width.height.equalTo(18)
            $0.centerX.centerY.equalToSuperview()
        }

        imageMask = UIView {
            $0.backgroundColor = UIColor(named: "SpotBlack")?.withAlphaComponent(0.5)
            contentView.addSubview($0)
        }
        imageMask!.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        circleView = CircleView {
            $0.layer.cornerRadius = 11.5
            contentView.addSubview($0)
        }
        circleView.snp.makeConstraints {
            $0.trailing.equalTo(imageView.snp.trailing).inset(6)
            $0.top.equalTo(imageView.snp.top).offset(6)
            $0.width.height.equalTo(23)
        }

        let circleButton = UIButton {
            $0.addTarget(self, action: #selector(circleTap(_:)), for: .touchUpInside)
            contentView.addSubview($0)
        }
        circleButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.width.height.equalTo(40)
        }
    }

    func setUp(asset: PHAsset, row: Int, selected: Bool, id: String) {
        self.asset = asset
        self.globalRow = row
        self.id = id
        self.imageSelected = selected
    }

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
        if let galleryVC = viewContainingController() as? PhotoGalleryController {
            galleryVC.imageManager.cancelImageRequest(requestID)
        }
    }

    /*
    func resetCell() {
        if imageView != nil { imageView.image = UIImage(); imageView.removeFromSuperview() }
        if circleView != nil { for sub in circleView.subviews {sub.removeFromSuperview()}; circleView = CircleView(); circleView.removeFromSuperview() }
        if liveIndicator != nil { liveIndicator!.image = UIImage(); liveIndicator!.removeFromSuperview() }
        
        if self.gestureRecognizers != nil {
            for gesture in self.gestureRecognizers! {
                self.removeGestureRecognizer(gesture)
            }
        }
    } */

    @objc func circleTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "GalleryCircleTap")
        guard let picker = viewContainingController() as? PhotoGalleryController else { return }
        UploadPostModel.shared.selectedObjects.contains(where: { $0.id == id }) ? picker.deselect(index: globalRow) : picker.select(index: globalRow)
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
