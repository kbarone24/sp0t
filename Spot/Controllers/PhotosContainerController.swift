//
//  PhotosContainerController.swift
//  Spot
//
//  Created by kbarone on 4/21/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Photos
import MapKit

class PhotosContainerController: UIViewController {
    
    unowned var mapVC: MapViewController!
    var mapView: MKMapView!
    var spotObject: MapSpot!
    var editSpotMode = false
    var limited = false /// limited gallery access
    
    lazy var selectedObjects: [(object: ImageObject, index: Int)] = []
    
    var assetsFull: PHFetchResult<PHAsset>!
    var baseSize: CGSize!
    var activityIndicator: CustomActivityIndicator!
    var segView: UIView!
    var buttonBar: UIView!
    var selectedIndex = 0
    var recentSeg, mapSeg: UIButton!
    
    var galleryAssetChange = false
    var extraAssets = 0
            
    private lazy var galleryController: PhotoGalleryPicker = {
        var viewController = storyboard!.instantiateViewController(withIdentifier: "PhotoGallery") as! PhotoGalleryPicker
        self.addChild(viewController)
        return viewController
    }()
    
    private lazy var photoMapController: MapPickerController = {
        var viewController = storyboard!.instantiateViewController(withIdentifier: "MapPicker") as! MapPickerController
        self.addChild(viewController)
        return viewController
    }()
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        setUpViews()
        getAssets()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // set mapView to nil on return to main mapVC
        if parent == nil && isMovingFromParent && mapView != nil {
            mapView.delegate = nil
            mapView.removeFromSuperview()
            mapView.removeAnnotations(mapView.annotations)
            mapView = nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if segView != nil {
            setUpNavBar()
        }
    }
    
    func setUpViews() {
        
        /// show photoMap first if posting to a spot
        if spotObject != nil { selectedIndex = 1 }
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        segView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 45))
        segView.isUserInteractionEnabled = true
        segView.backgroundColor = nil
        view.addSubview(segView)
        
        let segWidth: CGFloat = 90
                
        recentSeg = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - segWidth - 40, y: 6, width: segWidth, height: 35))
        recentSeg.titleEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 5)
        recentSeg.setTitle("Recent", for: .normal)
        recentSeg.setTitleColor(.white, for: .normal)
        recentSeg.titleLabel?.alpha = selectedIndex == 0 ? 1.0 : 0.6
        recentSeg.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 15)
        recentSeg.contentHorizontalAlignment = .center
        recentSeg.contentVerticalAlignment = .center
        recentSeg.addTarget(self, action: #selector(recentSegTap(_:)), for: .touchUpInside)
        segView.addSubview(recentSeg)
        
        mapSeg = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 + 40, y: 6, width: segWidth, height: 35))
        mapSeg.titleEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 5)
        mapSeg.setTitle("Photomap", for: .normal)
        mapSeg.setTitleColor(.white, for: .normal)
        mapSeg.titleLabel?.alpha = selectedIndex == 1 ? 1.0 : 0.6
        mapSeg.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 15)
        mapSeg.contentHorizontalAlignment = .center
        mapSeg.contentVerticalAlignment = .center
        mapSeg.addTarget(self, action: #selector(mapSegTap(_:)), for: .touchUpInside)
        segView.addSubview(mapSeg)

        let minX = selectedIndex == 0 ? UIScreen.main.bounds.width/2 - segWidth - 40 : UIScreen.main.bounds.width/2 + 40
        buttonBar = UIView(frame: CGRect(x: minX, y: segView.frame.maxY - 8, width: segWidth, height: 3))
        buttonBar.backgroundColor = .white
        segView.addSubview(buttonBar)

        setUpNavBar()
        selectedIndex == 0 ? add(asChildViewController: galleryController) : add(asChildViewController: photoMapController)
    }
    
    func setUpNavBar() {
        
        navigationItem.title = "Gallery"
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.removeShadow()
        navigationController?.navigationBar.addBackgroundImage(alpha: 1.0)
                
        if !selectedObjects.isEmpty {
            addNextButton()
        }
    }
    
    
    func getAssets() {
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 10000
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }

        ///assets full are for reloads and map gallery
        assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        photoMapController.loaded = true
        
        /// run get images in case map picker lagged behind
        if selectedIndex == 1 && photoMapController.locationObjects.isEmpty {
            print("get images 2")
            photoMapController.getImages()
        }
    }

    func addToFrontOfGallery() {
        var index = 0
        ///extra assets tracks assets already appended to the front of the gallery -> patch fix to avoid extra images that aren't selected getting appended to front of gallery
        while self.extraAssets != 0 {
            galleryController.imageObjects.remove(at: self.extraAssets - 1)
            self.extraAssets -= 1
        }
        ///gallery asset change
        for obj in selectedObjects {
            galleryController.imageObjects.insert(obj.object, at: index)
            index += 1
        }
        
        galleryController.collectionView.reloadData()
        extraAssets = selectedObjects.count
        galleryAssetChange = false
    }
    
    @objc func recentSegTap(_ sender: UIButton) {
        
        if selectedIndex == 1 {
            switchToRecentSeg()
        } else {
            /// scroll to top of gallery
            NotificationCenter.default.post(Notification(name: Notification.Name("ScrollGallery"), object: nil))
        }
    }
    
    func switchToMapSeg() {
        selectedIndex = 1
        animateSegmentSwitch()
        remove(asChildViewController: galleryController)
        add(asChildViewController: photoMapController)
    }
    
    @objc func mapSegTap(_ sender: UIButton) {
        if selectedIndex == 0 { switchToMapSeg() }
    }
    
    func switchToRecentSeg() {
        selectedIndex = 0
        animateSegmentSwitch()
        remove(asChildViewController: photoMapController)
        if self.galleryAssetChange { self.addToFrontOfGallery() }
        add(asChildViewController: galleryController)
    }
    
    func animateSegmentSwitch() {
        
        let segWidth: CGFloat = 90
        let minX = selectedIndex == 0 ? UIScreen.main.bounds.width/2 - segWidth - 40 : UIScreen.main.bounds.width/2 + 40
        UIView.animate(withDuration: 0.2) {
            self.buttonBar.frame = CGRect(x: minX, y: self.buttonBar.frame.minY, width: self.buttonBar.frame.width, height: self.buttonBar.frame.height)
            self.recentSeg.titleLabel?.alpha = self.selectedIndex == 0 ? 1.0 : 0.6
            self.mapSeg.titleLabel?.alpha = self.selectedIndex == 1 ? 1.0 : 0.6
        }
    }

    
    private func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.view.frame = CGRect(x: 0, y: 45, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 45)
        viewController.didMove(toParent: self)
    }
    
    private func remove(asChildViewController viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    func addNextButton() {
        if self.navigationItem.rightBarButtonItem?.title != "Next" {
            let nextBtn = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(nextTapped(_:)))
            nextBtn.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Semibold", size: 15) as Any, NSAttributedString.Key.foregroundColor: UIColor(named: "SpotGreen") as Any], for: .normal)
            self.navigationItem.setRightBarButton(nextBtn, animated: true)
            self.navigationItem.rightBarButtonItem?.tintColor = nil
        }
    }
    
    @objc func nextTapped(_ sender: UIButton) {
        
        if editSpotMode {
            let infoPass = ["image": selectedObjects.map({$0.object.stillImage}).first ?? UIImage()] as [String : Any]
            NotificationCenter.default.post(name: NSNotification.Name("EditImageChange"), object: nil, userInfo: infoPass)
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            vc.galleryLocation = selectedObjects.first?.object.rawLocation ?? CLLocation()
            vc.postDate = selectedObjects.first?.object.creationDate ?? Date()
          ///  vc.selectedImages = selectedObjects.map({$0.object.images.first ?? UIImage()}) /// pass through image + indexes
            /// resolve any differences between selected objects and preview objects
            vc.selectedImages = getSelectedImages()
            vc.frameIndexes = getSelectedIndexes()
            vc.spotObject = self.spotObject
            vc.mapVC = self.mapVC
            vc.containerVC = self
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func removeNextButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem()
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
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
