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
    
    lazy var segmentedControl = PhotosSegmentedControl()
    lazy var selectedObjects: [(object: ImageObject, index: Int)] = []
    
    var assetsFull: PHFetchResult<PHAsset>!
    var baseSize: CGSize!
    var activityIndicator: CustomActivityIndicator!
    var segView: UIImageView!
    
    var galleryAssetChange = false
    var extraAssets = 0
        
    deinit {
        print("container deinit")
    }
    
    private lazy var firstViewController: PhotoGalleryPicker = {
        // Load Storyboard
        // Instantiate View Controller
        var viewController = storyboard!.instantiateViewController(withIdentifier: "PhotoGallery") as! PhotoGalleryPicker
        // Add View Controller as Child View Controller
        self.addChild(viewController)
        return viewController
    }()
    
    private lazy var secondViewController: MapPickerController = {
        // Instantiate View Controller
        var viewController = storyboard!.instantiateViewController(withIdentifier: "MapPicker") as! MapPickerController
        // Add View Controller as Child View Controller
        self.addChild(viewController)
        return viewController
    }()
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
        setUpViews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // set mapView to nil on return to main mapVC
        if mapView != nil && isMovingFromParent {
            mapView.delegate = nil
            mapView.removeFromSuperview()
            mapView.removeAnnotations(mapView.annotations)
            mapView = nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if segView != nil {
            setUpNavBar()
        }
    }
    
    func setUpViews() {
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 150, width: UIScreen.main.bounds.width, height: 30))
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        segView = UIImageView(image: UIImage(named: "PhotoGallerySelected"))
        segView.layer.borderColor = UIColor.clear.cgColor
        segView.isUserInteractionEnabled = true
        segmentedControl.addSubview(segView)
        
        let im0 = UIImage()
        let im1 = UIImage()
        
        segmentedControl.isUserInteractionEnabled = false
        segmentedControl.insertSegment(with: im0, at: 0, animated: true)
        segmentedControl.insertSegment(with: im1, at: 1, animated: true)
        segmentedControl.selectedSegmentTintColor = UIColor.clear
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        let im = UIColor.clear.image(CGSize(width: 40, height: 140))
        segmentedControl.setBackgroundImage(im, for: .normal, barMetrics: .default)
        segmentedControl.layer.borderColor = UIColor.clear.cgColor
        segmentedControl.tintColor = UIColor.clear
        segmentedControl.setDividerImage(UIImage(), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setWidth(85, forSegmentAt: 0)
        segmentedControl.setWidth(85, forSegmentAt: 1)
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged(_:)), for: .valueChanged)
        
        setUpNavBar()
        self.add(asChildViewController: self.firstViewController)
    }
    
    func setUpNavBar() {
        
        self.navigationItem.titleView = segmentedControl
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.navigationBar.tintColor = .white
        self.navigationController?.navigationBar.barTintColor = UIColor(named: "SpotBlack")
        self.navigationController?.navigationBar.isTranslucent = false
                
        if !selectedObjects.isEmpty {
            self.addNextButton()
        }
    }
    
    
    func assetsFetched() {
        self.secondViewController.loaded = true
        self.segmentedControl.isUserInteractionEnabled = true
    }

    func addToFrontOfGallery() {
        var index = 0
        ///extra assets tracks assets already appended to the front of the gallery -> patch fix to avoid extra images that aren't selected getting appended to front of gallery
        while self.extraAssets != 0 {
            firstViewController.imageObjects.remove(at: self.extraAssets - 1)
            self.extraAssets -= 1
        }
        ///gallery asset change
        for obj in selectedObjects {
            firstViewController.imageObjects.insert(obj.object, at: index)
            index += 1
        }
        
        firstViewController.collectionView.reloadData()
        extraAssets = selectedObjects.count
        galleryAssetChange = false
    }
    
    @objc func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        if segmentedControl.selectedSegmentIndex == 0 {
            segView.image = UIImage(named: "PhotoGallerySelected")
            remove(asChildViewController: secondViewController)
            if self.galleryAssetChange { self.addToFrontOfGallery() }
            add(asChildViewController: firstViewController)
        } else {
            segView.image = UIImage(named: "MapPickerSelected")
            remove(asChildViewController: firstViewController)
            add(asChildViewController: secondViewController)
        }
    }
    
    private func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
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
            let infoPass = ["image": selectedObjects.map({$0.object.image}).first ?? UIImage()] as [String : Any]
            NotificationCenter.default.post(name: NSNotification.Name("ImageChange"), object: nil, userInfo: infoPass)
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            vc.galleryLocation = selectedObjects.first?.object.rawLocation ?? CLLocation()
            vc.selectedImages = selectedObjects.map({$0.object.image})
            vc.spotObject = self.spotObject
            vc.mapVC = self.mapVC
            vc.containerVC = self
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func removeNextButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem()
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

class PhotosSegmentedControl: UISegmentedControl {
    // scroll to top of gallery on tap
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        let previousIndex = self.selectedSegmentIndex
        if previousIndex == 0 && self.selectedSegmentIndex == 0 {
            NotificationCenter.default.post(Notification(name: Notification.Name("ScrollGallery"), object: nil))
        }
    }
}
