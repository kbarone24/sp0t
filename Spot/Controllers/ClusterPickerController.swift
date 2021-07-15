//
//  ClusterPickerController.swift
//  Spot
//
//  Created by kbarone on 4/17/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Photos
import Mixpanel

class ClusterPickerController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout  {
    
    unowned var mapVC: MapViewController!
    weak var containerVC: PhotosContainerController!
    var spotObject: MapSpot!
    
    lazy var imageObjects: [ImageObject] = []
    lazy var selectedObjects: [(object: ImageObject, index: Int)] = []
    lazy var imageManager = PHCachingImageManager()

    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    var baseSize: CGSize!
    var maskView: UIView!
    var previewView: GalleryPreviewView!
    
    var zoomLevel = ""
    lazy var tappedLocation = CLLocation()
    
    var single = false
    var isFetching = false
    var fetchingIndex = -1
    var cancelOnDismiss = false
    var editSpotMode = true
    
    var context: PHLivePhotoEditingContext!
    var requestID: Int32 = 1
    var contentRequestID: Int = 1
    
    var downloadCircle: UIActivityIndicatorView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        cancelOnDismiss = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        cancelOnDismiss = true

        if self.isMovingFromParent {
            let controllers = self.navigationController?.viewControllers
            if let container = controllers![controllers!.count - 1] as? PhotosContainerController {
                container.selectedObjects.removeAll()
                container.galleryAssetChange = true
                var index = 0
                for obj in self.selectedObjects {
                    container.selectedObjects.append(obj)
                    index += 1
                }
            }
        }
    }
    
    override func viewDidLoad() {
        Mixpanel.mainInstance().track(event: "ClusterPickerOpen")
        
        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "galleryCell")
        
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        
        layout.scrollDirection = .vertical
        layout.itemSize = baseSize
        layout.minimumLineSpacing = 0.1
        layout.minimumInteritemSpacing = 0.1
        layout.estimatedItemSize = baseSize
        
        collectionView.isUserInteractionEnabled = true
        collectionView.delegate = self
        collectionView.dataSource = self
        self.collectionView.allowsSelection = true
        collectionView.setCollectionViewLayout(layout, animated: false)
        view.addSubview(collectionView)
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maskTap(_:))))
        maskView.isUserInteractionEnabled = true
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)

        if single { collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width/4, height: UIScreen.main.bounds.height/4)}
        collectionView.reloadData()
        
        getTitle()
        
        if !selectedObjects.isEmpty { addNextButton() }
    }
    
    deinit {
        imageManager.stopCachingImagesForAllAssets()
    }

    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
        maskView.removeFromSuperview()
    }
    
    func removePreviews() {
        
        /// remove saved images from image objects to avoid memory pile up
        if previewView != nil && previewView.selectedIndex == 0 {
            if let i = imageObjects.firstIndex(where: {$0.asset == previewView.object.asset}) {
                imageObjects[i].animationImages.removeAll()
                imageObjects[i].stillImage = UIImage()
            }
        }

        if previewView != nil { for sub in previewView.subviews { sub.removeFromSuperview()}; previewView.removeFromSuperview() }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = baseSize!
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if imageObjects.isEmpty { return 0 }
        else {
            return imageObjects.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 300, right: 0)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "galleryCell", for: indexPath) as! GalleryCell
        
        if self.imageObjects.isEmpty { return cell }
        
        if let imageObject = imageObjects[safe: indexPath.row] {
            var index = 0
            if let trueIndex = selectedObjects.lastIndex(where: {$0.index == indexPath.row}) { index = trueIndex + 1 }
            cell.setUp(asset: imageObject.asset, row: indexPath.row, index: index, editSpot: editSpotMode)
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
                        
        if selectedObjects.contains(where: {$0.index == indexPath.row}) {
            deselect(index: indexPath.row, circleTap: false)
            
        } else {
            select(index: indexPath.row, circleTap: false)
        }
    }
    
    func deselect(index: Int, circleTap: Bool) {
                
        let paths = getSelectedPaths(newRow: index)
        guard let selectedObject = imageObjects[safe: index] else { return }

        if !circleTap {
            var selectedIndex = 0
            if let trueIndex = selectedObjects.lastIndex(where: {$0.index == index}) { selectedIndex = trueIndex + 1 }
            self.addPreviewView(object: selectedObject, selectedIndex: selectedIndex, galleryIndex: index)
            
        } else {
            Mixpanel.mainInstance().track(event: "ClusterPickerCircleTap", properties: ["selected": false])
            selectedObjects.removeAll(where: {$0.index == index})
            if selectedObjects.count == 0 { removeNextButton() }
            DispatchQueue.main.async { self.collectionView.reloadItems(at: paths) }
        }
    }
    
    func select(index: Int, circleTap: Bool) {
        
        guard let selectedObject = imageObjects[safe: index] else { return }
        if selectedObjects.count > 4 { showMaxImagesAlert(); return }
        if editSpotMode && selectedObjects.count > 0 { return }
        
        let paths = getSelectedPaths(newRow: index)

        if selectedObject.stillImage != UIImage() {
            
            if !circleTap {
                self.addPreviewView(object: selectedObject, selectedIndex: 0, galleryIndex: index)
                
            } else {
                Mixpanel.mainInstance().track(event: "ClusterPickerCircleTap", properties: ["selected": true])
                selectedObjects.append((selectedObject, index))
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
                if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: index); return  }
                
                if isFetching { cancelFetchForRowAt(index: fetchingIndex) } /// another cell is fetching cancel that fetch
                cell.addActivityIndicator()
                
                isFetching = true
                fetchingIndex = index
                
                if imageObjects[index].asset.mediaSubtypes.contains(.photoLive) && !editSpotMode {
                    
                    fetchLivePhoto(item: index, isLocal: local, selected: false) { [weak self] animationImages, stillImage, failed in
                        
                        guard let self = self else { return }
                        
                        self.isFetching = false
                        self.fetchingIndex = -1
                        cell.removeActivityIndicator()
                        
                        if self.cancelOnDismiss { return }
                        if failed { self.showFailedDownloadAlert(); return }
                        if stillImage == UIImage() { return } /// canceled
                        
                        self.imageObjects[index] = (ImageObject(asset: self.imageObjects[index].asset, rawLocation: self.imageObjects[index].rawLocation, stillImage: stillImage, animationImages: animationImages, gifMode: true, creationDate: self.imageObjects[index].creationDate))

                        ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                        if self.selectedObjects.count < 5 {
                            
                            let newObject = (ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, stillImage: stillImage, animationImages: animationImages, gifMode: true, creationDate: selectedObject.creationDate), index)
                            
                            if !circleTap {
                                self.addPreviewView(object: newObject.0, selectedIndex: 0, galleryIndex: index)
                                
                            } else {
                                Mixpanel.mainInstance().track(event: "ClusterPickerCircleTap", properties: ["selected": true])
                                self.selectedObjects.append(newObject)
                                self.checkForNext()
                                DispatchQueue.main.async {
                                    if self.cancelOnDismiss { return }
                                    self.collectionView.reloadItems(at: paths)
                                }
                            }
                        }
                    }
                    
                } else {
                    
                    self.fetchImage(item: index, isLocal: local, selected: true, livePhoto: false) { [weak self] result, failed  in
                        
                        guard let self = self else { return }
                        self.isFetching = false
                        self.fetchingIndex = -1
                        cell.removeActivityIndicator()
                        
                        if self.cancelOnDismiss { return }
                        ///return on download fail
                        if failed { self.showFailedDownloadAlert(); return }
                        if result == UIImage() { return } /// canceled
                        
                        ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                        if self.selectedObjects.count < 5 {
                            
                            /// append new image object with fetched image
                            let newObject = (ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, stillImage: result, animationImages: [], gifMode: false, creationDate: selectedObject.creationDate), index)
                            cell.removeActivityIndicator()
                            
                            if !circleTap {
                                self.addPreviewView(object: newObject.0, selectedIndex: 0, galleryIndex: index)
                            } else {
                                self.selectedObjects.append(newObject)
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
    
    func cancelFetchForRowAt(index: Int) {
        
        Mixpanel.mainInstance().track(event: "ClusterPickerCancelFetch")
        
        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell else { return }
        guard let currentObject = imageObjects[safe: index] else { return }
        let currentAsset = currentObject.asset

        cell.activityIndicator.stopAnimating()
        currentAsset.cancelContentEditingInputRequest(contentRequestID)
        if context != nil { context.cancel() }
        imageManager.cancelImageRequest(requestID)
        
        isFetching = false
        fetchingIndex = -1
    }
    
    func getSelectedPaths(newRow: Int) -> [IndexPath] {
        
        var selectedPaths: [IndexPath] = []
        let selectedRows = selectedObjects.map({$0.index})
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
        previewView.cluster = self
        previewView.setUp(object: object, selectedIndex: selectedIndex, galleryIndex: galleryIndex)
        maskView.addSubview(previewView)
    }

    func checkForNext() {
        if self.selectedObjects.count == 1 {
            self.addNextButton()
            let controllers = self.navigationController?.viewControllers
            if let container = controllers?.first(where: {$0.isKind(of: PhotosContainerController.self)}) as? PhotosContainerController {
                container.addNextButton()
            }
        }
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
                        
                        
                        let distanceBetweenFrames: Double = 2
                        let rawFrames = Double(frameImages.count) / distanceBetweenFrames
                        let numberOfFrames: Double = rawFrames > 11 ? 9 : rawFrames > 7 ? max(7, rawFrames - 2) : rawFrames
                        let rawOffsest = max((rawFrames - numberOfFrames) * distanceBetweenFrames/2, 2) /// offset on beginning and ending of the frames
                        let offset = Int(rawOffsest)
                        
                        let aspect = frameImages[0].size.height / frameImages[0].size.width
                        let size = CGSize(width: min(frameImages[0].size.width, UIScreen.main.bounds.width * 1.5), height: min(frameImages[0].size.height, aspect * UIScreen.main.bounds.width * 1.5))
                        
                        let image0 = self.ResizeImage(with: frameImages[offset], scaledToFill: size)
                        animationImages.append(image0 ?? UIImage())
                        
                        /// add middle frames, trimming first couple and last couple
                        let intMultiplier = (frameImages.count - offset * 2)/Int(numberOfFrames)
                        for i in 1...Int(numberOfFrames) {
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
            self.fetchImage(item: item, isLocal: isLocal, selected: selected, livePhoto: true) { result, failed in
                
                if failed || result == UIImage() { completion([UIImage()], UIImage(), false); return }
                stillImage = result
                
                downloadCount += 1
                if downloadCount == 2 { DispatchQueue.main.async { completion(animationImages, stillImage, false) } }
            }
        }
    }

    func fetchImage(item: Int, isLocal: Bool, selected: Bool, livePhoto: Bool, completion: @escaping(_ result: UIImage, _ failed: Bool) -> Void) {
        
        let currentAsset = imageObjects[item].asset
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
                        
        DispatchQueue.global(qos: .userInitiated).async {
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
                    if !livePhoto { self.imageObjects[item] = (ImageObject(asset: self.imageObjects[item].asset, rawLocation: self.imageObjects[item].rawLocation, stillImage: resizedImage ?? UIImage(), animationImages: [], gifMode: false, creationDate: self.imageObjects[item].creationDate)) }
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
    
    
    func addNextButton() {
        let nextBtn = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTapped(_:)))
        nextBtn.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
        self.navigationItem.setRightBarButton(nextBtn, animated: true)
        self.navigationItem.rightBarButtonItem?.tintColor = nil
    }
    
    /// should consolidate next button functions
    func removeNextButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem()
        let controllers = self.navigationController?.viewControllers
        if let container = controllers![controllers!.count - 2] as? PhotosContainerController {
            container.removeNextButton()
        }
    }
    
    @objc func nextTapped(_ sender: UIButton) {
        //pop to add overview
       
        if editSpotMode {
            let infoPass = ["image": selectedObjects.map({$0.object.stillImage}).first ?? UIImage()] as [String : Any]
            NotificationCenter.default.post(name: NSNotification.Name("EditImageChange"), object: nil, userInfo: infoPass)
            guard let controllers = self.navigationController?.viewControllers else { return }
            self.navigationController?.popToViewController(controllers[controllers.count - 3], animated: true)
            return
        }

        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            vc.galleryLocation = selectedObjects.first?.object.rawLocation ?? CLLocation()
            vc.postDate = selectedObjects.first?.object.creationDate ?? Date()
            vc.selectedImages = getSelectedImages()
            vc.frameIndexes = getSelectedIndexes()
            vc.mapVC = self.mapVC
            vc.containerVC = self.containerVC
            vc.spotObject = self.spotObject
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func getSelectedImages() -> [UIImage] {
        var images: [UIImage] = []
        for obj in selectedObjects { obj.object.gifMode ? images.append(contentsOf: obj.object.animationImages) : images.append(obj.object.stillImage) }
        return images
    }
    
    func getSelectedIndexes() -> [Int] {
        
        var indexes: [Int] = []
        indexes.append(0)
        if selectedObjects.count == 1 { return indexes }
        
        for i in 0...selectedObjects.count - 1 {
            if i == 0 { continue }
            let object = selectedObjects[i - 1].object
            object.gifMode ? indexes.append(indexes.last! + object.animationImages.count) : indexes.append(indexes.last! + 1)
        }
        
        return indexes
    }

    func getTitle() {
        /// set the title of the cluster picker based on how far zoomed in the map was when user selected from map picker
        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(tappedLocation, preferredLocale: locale) { placemarks, error in // 6
            
            guard let placemark = placemarks?.first else { return    }
            
            if self.zoomLevel == "country" {
                if placemark.country != nil {
                    self.navigationItem.title = placemark.country!
                }
                
            } else if self.zoomLevel == "state" {
                if placemark.country != nil {
                    if placemark.country! == "United States" {
                        if placemark.administrativeArea != nil {
                            self.navigationItem.title = self.stateTransformer(initial: placemark.administrativeArea!, abbr: true)
                        }
                        
                    } else {
                        if placemark.country != nil {
                            self.navigationItem.title = placemark.country!
                        }
                    }
                }
                
            } else {
                var title = ""
                if placemark.locality != nil {
                    title = placemark.locality!
                }
                if placemark.administrativeArea != nil {
                    if title != "" { title = title + ", "}
                    title = title + placemark.administrativeArea!
                    self.navigationItem.title = title
                }
            }
        }
    }
    
    func stateTransformer(initial: String, abbr: Bool) -> String {
        let stateCodes = ["AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX","UT","VT","VA","WA","WV","WI","WY"]
        let fullStateNames = ["Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut","Delaware","District of Columbia","Florida","Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana","Maine","Maryland","Massachusetts","Michigan","Minnesota","Mississippi","Missouri","Montana","Nebraska","Nevada","New Hampshire","New Jersey","New Mexico","New York","North Carolina","North Dakota","Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina","South Dakota","Tennessee","Texas","Utah","Vermont","Virginia","Washington","West Virginia","Wisconsin","Wyoming"]
        if abbr {
            let index = stateCodes.firstIndex(where: {$0.lowercased() == initial.lowercased()})
            return fullStateNames[index ?? 0]
        }
        let index = fullStateNames.firstIndex(where: {$0.lowercased() == initial.lowercased()})
        return stateCodes[index ?? 0]
    }
    
}
