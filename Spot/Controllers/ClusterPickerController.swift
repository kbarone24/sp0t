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

    let collectionView: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    var baseSize: CGSize!
    var maskView: UIView!
    var previewView: UIImageView!
    
    var zoomLevel = ""
    lazy var tappedLocation = CLLocation()
    
    var single = false
    var isFetching = false
    var editSpotMode = true
    
    var downloadCircle: UIActivityIndicatorView!
    
    deinit {
        print("cluster deinit")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
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
        collectionView.allowsMultipleSelection = true
        self.collectionView.allowsSelection = true
        collectionView.setCollectionViewLayout(layout, animated: false)
        view.addSubview(collectionView)
        
        previewView = UIImageView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        maskView = UIView(frame: CGRect(x: 0, y: -100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height + 200))
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        if single { collectionView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width/4, height: UIScreen.main.bounds.height/4)}
        collectionView.reloadData()
        
        getTitle()
        
        if !selectedObjects.isEmpty { addNextButton() }
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
    //    cell.image = nil
        
        if let imageObject = imageObjects[safe: indexPath.row] {
            
            cell.setUp(asset: imageObject.asset, row: indexPath.row)
            
            if self.selectedObjects.contains(where: {$0.index == indexPath.row}) {
                let index = self.selectedObjects.lastIndex(where: {$0.index == indexPath.row})
                cell.addGreenFrame(count: index! + 1)
            } else {
                cell.addBlackFrame()
            }
        }
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressAndHold(_:)))
        press.accessibilityLabel = String(indexPath.row)
        cell.addGestureRecognizer(press)
        return cell
    }
    
    @objc func pressAndHold(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            
            let path = Int(sender.accessibilityLabel ?? "0")
            
            if imageObjects[path ?? 0].image != UIImage() {
                let result = self.imageObjects[path ?? 0].image
                let aspect = result.size.height / result.size.width
                let height = UIScreen.main.bounds.width * aspect
                
                previewView.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: height)
                previewView.layer.cornerRadius = 12
                previewView.clipsToBounds = true
                previewView.image = result
                view.addSubview(previewView)
                
            } else {
                
                downloadCircle = UIActivityIndicatorView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 100, y: 150, width: 200, height: 200))
                downloadCircle.color = .white

                let currentAsset = self.imageObjects[path ?? 0].asset
                var local = false
                let resourceArray = PHAssetResource.assetResources(for: currentAsset)
                if let isLocal = resourceArray.first?.value(forKey: "locallyAvailable") as? Bool {
                    local = isLocal
                }
                
                maskView.addSubview(downloadCircle)
                downloadCircle.startAnimating()
                if isFetching { return }
                
                view.addSubview(maskView)
                
                isFetching = true
                fetchImage(item: path ?? 0, isLocal: local, selected: false) { result  in
                    
                    self.isFetching = false
                    self.downloadCircle.removeFromSuperview()
                    
                    ///return on download fail
                    if result == UIImage() {                                                         self.showFailedDownloadAlert(); return }
                    
                    let aspect = result.size.height / result.size.width
                    let height = UIScreen.main.bounds.width * aspect
                    if self.maskView.superview == nil { return }
                    
                    if aspect > 1 {
                        self.previewView.frame = CGRect(x: 0, y: 10, width:     UIScreen.main.bounds.width, height: height)
                    } else {
                        self.previewView.frame = CGRect(x: 0, y: 50, width:     UIScreen.main.bounds.width, height: height)
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
        
        guard let selectedObject = imageObjects[safe: indexPath.row] else { return }
        
        if let i = self.selectedObjects.firstIndex(where: {$0.index == indexPath.row}) {
            
            self.selectedObjects.remove(at: i)
            
            if selectedObjects.count == 0 {
                self.removeNextButton()
            }
            
            DispatchQueue.main.async {
                DispatchQueue.main.async { collectionView.reloadItems(at: [indexPath]) }
            }
            
        } else {
            if editSpotMode {
                if selectedObjects.count > 0 { return }
            }

            if selectedObjects.count < 5 {
                //existing pic appended to photo gallery on edit spot
               if selectedObject.image != UIImage() {
                
                self.selectedObjects.append((selectedObject, indexPath.row))
                    self.checkForNext()
                
                DispatchQueue.main.async { collectionView.reloadItems(at: [indexPath]) }
                
                } else {
                    if let cell = collectionView.cellForItem(at: indexPath) as? GalleryCell {
                        let currentAsset = self.imageObjects[indexPath.row].asset
                        var local = false
                        let resourceArray = PHAssetResource.assetResources(for: currentAsset)
                        if let isLocal = resourceArray.first?.value(forKey: "locallyAvailable") as? Bool {
                            local = isLocal
                        }
                        
                        if self.isFetching { return }
                        cell.addActivityIndicator()
                        
                        self.isFetching = true
                        self.fetchImage(item: indexPath.row, isLocal: local, selected: true) { result  in
                            self.isFetching = false
                            cell.removeActivityIndicator()
                            ///return on download fail
                            if result == UIImage() { self.showFailedDownloadAlert(); return }
                            //fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                            if self.selectedObjects.count < 5 {
                            
                                /// append new image object with fetched image
                                self.selectedObjects.append((ImageObject(asset: selectedObject.asset, rawLocation: selectedObject.rawLocation, image: result, creationDate: selectedObject.creationDate), indexPath.row))
                                self.checkForNext()
                                DispatchQueue.main.async { collectionView.reloadItems(at: [indexPath]) }
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    func checkForNext() {
        if self.selectedObjects.count == 1 {
            self.addNextButton()
            let controllers = self.navigationController?.viewControllers
            if let container = controllers![controllers!.count - 2] as? PhotosContainerController {
                container.addNextButton()
            }
        }
    }
    
    func fetchImage(item: Int, isLocal: Bool, selected: Bool, completion: @escaping(_ result: UIImage) -> Void) {
        
        var options: PHImageRequestOptions!
        options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
                
        let currentAsset = self.imageObjects[item].asset
        DispatchQueue.global().async { [weak self] in

            PHImageManager.default().requestImage(for: currentAsset,
                                                  targetSize: CGSize(width: currentAsset.pixelWidth, height: currentAsset.pixelHeight),
                                                  contentMode: .aspectFill,
                                                  options: options) { (image, info) in
                                                    
                                                    DispatchQueue.main.async {
                                                        guard let self = self else { return }
                                                        guard let result = image else {                   completion( UIImage() ); return }
                                                            
                                                            self.imageObjects[item] = (ImageObject(asset: self.imageObjects[item].asset, rawLocation: self.imageObjects[item].rawLocation, image: result, creationDate: self.imageObjects[item].creationDate))
                                                            DispatchQueue.main.async {  completion(result) }
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
            let infoPass = ["image": selectedObjects.map({$0.object.image}).first ?? UIImage()] as [String : Any]
            NotificationCenter.default.post(name: NSNotification.Name("ImageChange"), object: nil, userInfo: infoPass)
            guard let controllers = self.navigationController?.viewControllers else { return }
            self.navigationController?.popToViewController(controllers[controllers.count - 3], animated: true)
            return
        }

        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            vc.galleryLocation = selectedObjects.first?.object.rawLocation ?? CLLocation()
            vc.selectedImages = selectedObjects.map({$0.object.image})
            vc.mapVC = self.mapVC
            vc.containerVC = self.containerVC
            vc.spotObject = self.spotObject
            self.navigationController?.pushViewController(vc, animated: false)
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
