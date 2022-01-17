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
    
    var spotObject: MapSpot!
    
    lazy var imageObjects: [(image: ImageObject, selected:Bool)] = []
    lazy var imageManager = PHCachingImageManager()
    
    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    var baseSize: CGSize!
    let options = PHImageRequestOptions()
    
    var maskView: UIView!
    var imagePreview: ImagePreviewView!
    
    var zoomLevel = ""
    lazy var tappedLocation = CLLocation()
    
    var single = false
    var editSpotMode = true
    
    var downloadCircle: UIActivityIndicatorView!
    var cancelOnDismiss = false
    lazy var imageFetcher = ImageFetcher()
    
    deinit {
        imageManager.stopCachingImagesForAllAssets()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviewRemove"), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        cancelOnDismiss = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ClusterPickerOpen")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cancelOnDismiss = true
    }
    
    override func viewDidLoad() {
                
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        view.backgroundColor = UIColor(named: "SpotBlack")

        collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        collectionView.backgroundColor = UIColor(named: "SpotBlack")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "galleryCell")
                
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(removePreview(_:)), name: NSNotification.Name("PreviewRemove"), object: nil)
    }
    
    
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
        maskView.removeFromSuperview()
    }
    
    func setUpNavBar() {
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        let nextBtn = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTap(_:)))
        nextBtn.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCompactText-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
        self.navigationItem.setRightBarButton(nextBtn, animated: true)
        self.navigationItem.rightBarButtonItem?.tintColor = nil
                
        let backButton = UIBarButtonItem(image: UIImage(named: "BackArrow"), style: .plain, target: self, action: #selector(backTap(_:)))
        navigationItem.setLeftBarButton(backButton, animated: false)
        self.navigationItem.leftBarButtonItem?.tintColor = nil
    }
    
    @objc func backTap(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func nextTap(_ sender: UIBarButtonItem) {
        if let uploadVC = navigationController?.viewControllers.first(where: {$0 is UploadPostController}) as? UploadPostController {
            uploadVC.finishPassingFromGallery()
            navigationController?.popToViewController(uploadVC, animated: false)
        }
    }
    
    func removePreviews() {
        
        /// remove saved images from image objects to avoid memory pile up
        if imagePreview != nil && !(UploadImageModel.shared.selectedObjects.contains(where: {$0.id == imagePreview.imageObjects.first?.id ?? ""})) {
            if let i = imageObjects.firstIndex(where: {$0.0.id == imagePreview.imageObjects.first?.id ?? ""}) {
                imageObjects[i].0.animationImages.removeAll()
                imageObjects[i].0.stillImage = UIImage()
            }
        }
        
        if imagePreview != nil { for sub in imagePreview.subviews { sub.removeFromSuperview()}; imagePreview.removeFromSuperview() }
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
            if let trueIndex = UploadImageModel.shared.selectedObjects.lastIndex(where: {$0.id == imageObject.0.id}) { index = trueIndex + 1 }
            cell.setUp(asset: imageObject.0.asset, row: indexPath.row, index: index, editSpot: editSpotMode, id: imageObject.0.id, cameraImage: imageObject.0.stillImage)
            
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
        
        let imageObject = imageObjects[indexPath.row]
        
        if UploadImageModel.shared.selectedObjects.contains(where: {$0.id == imageObject.image.id}) {
            deselect(index: indexPath.row, circleTap: false)
            
        } else {
            select(index: indexPath.row, circleTap: false)
        }
    }
    
    func deselect(index: Int, circleTap: Bool) {
        
        let paths = getSelectedPaths(newRow: index)
        guard let selectedObject = imageObjects[safe: index] else { return }
        
        if !circleTap {
            self.addPreviewView(object: selectedObject.0, galleryIndex: index)
            
        } else {
            Mixpanel.mainInstance().track(event: "ClusterSelectImage", properties: ["selected": false])
            UploadImageModel.shared.selectObject(imageObject: selectedObject.0, selected: false)
            DispatchQueue.main.async { self.collectionView.reloadItems(at: paths)
            }
        }
    }
    
    func select(index: Int, circleTap: Bool) {
        
        guard let selectedObject = imageObjects[safe: index]?.0 else { return }
        if UploadImageModel.shared.selectedObjects.count > 4 { showMaxImagesAlert(); return }
        if editSpotMode && UploadImageModel.shared.selectedObjects.count > 0 { return }
        
        let paths = getSelectedPaths(newRow: index)
        
        if selectedObject.stillImage != UIImage() {
            
            if !circleTap {
                self.addPreviewView(object: selectedObject, galleryIndex: index)
                
            } else {
                Mixpanel.mainInstance().track(event: "ClusterSelectImage", properties: ["selected": true])
                UploadImageModel.shared.selectObject(imageObject: selectedObject, selected: true)
                DispatchQueue.main.async { self.collectionView.reloadItems(at: paths) }
            }
            
        } else {
            
            if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell {
                
                let currentAsset = self.imageObjects[index].0.asset
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
                    
                    self.imageObjects[index].image.stillImage = stillImage
                    
                    
                    ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                    if UploadImageModel.shared.selectedObjects.count < 5 {
                        
                        cell.removeActivityIndicator()
                        
                        if !circleTap {
                            self.addPreviewView(object: self.imageObjects[index].image, galleryIndex: index)
                            
                        } else {
                            UploadImageModel.shared.selectObject(imageObject: self.imageObjects[index].image, selected: true)
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
        
        Mixpanel.mainInstance().track(event: "ClusterPickerCancelFetch")
        
        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? GalleryCell else { return }
        guard let currentObject = imageObjects[safe: index]?.0 else { return }
        let currentAsset = currentObject.asset
        
        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }
    
    func getSelectedPaths(newRow: Int) -> [IndexPath] {
        
        var selectedPaths: [IndexPath] = []
        for object in UploadImageModel.shared.selectedObjects {
            if let index = imageObjects.firstIndex(where: {$0.0.id == object.id}) {
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
    
    @objc func removePreview(_ sender: NSNotification) {
        if imagePreview != nil {
            imagePreview.removeFromSuperview()
            imagePreview = nil
        }
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
