//
//  AddOverviewController.swift
//  Spot
//
//  Created by kbarone on 12/5/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import RSKImageCropper
import CoreLocation
import Firebase
import Geofirestore
import CoreData

class AddOverviewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var selectedImagesFromPicker: [(UIImage, Int, CLLocation)] = []
    
    var spotLocationRaw: CLLocation!
    var imageFromCamera = false
    var currentLocation: CLLocation!
    let locationManager : CLLocationManager = CLLocationManager()
    
    var selectedImages: [UIImage] = []
    
    var selectedImageView: UIImageView!
    var nextImageView: UIImageView!
    var previousImageView: UIImageView!
    var selectedImageIndex = 0
    
    var mainScroll: UIScrollView!
    let nearbyScroll: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    var nearbySpots: [(SpotSimple, CLLocationDistance)] = []
    var querySpots: [ResultSpot] = []
    
    var listener1, listener2, listener3: ListenerRegistration!
    var circleQuery: GFSCircleQuery?
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var nearbyIndex = 0
    var friendsList: [String] = []
    var openedCamera = false
    
    var nearbyLabel: UILabel!
    var dotView: UIView!
    var gifMode = false
    
    var createNewButton: UIButton!
    
    var searchBar: UISearchBar!
    var searchBarContainer: UIView!
    var resultsView: UITableView!
    var searchTextGlobal = ""
    var searchIndicator: CustomActivityIndicator!
    var cancelButton: UIButton!
    
    var draftID: Int64!
    
    override func viewDidLoad() {
        getCurrentLocation()
        setUpViews()
        //  toLowercase()
    }
    /*
     func toLowercase() {
     self.db.collection("spots").getDocuments { (snap, err) in
     for spot in snap!.documents {
     if let spotName = spot.get("spotName") as? String {
     self.db.collection("spots").document(spot.documentID).updateData(["lowercaseName" : spotName.lowercased()])
     }
     }
     }
     }*/
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        
        if listener1 != nil {self.listener1.remove()}
        if listener2 != nil {self.listener2.remove()}
        
    }
    
    func save(images: [UIImage]) {
        
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        let imagesArrayObject = ImagesArray(context: managedContext)
        var imageObjects : [ImageModel] = []
        
        var index: Int16 = 0
        for image in images {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.7)
            im.position = index
            imageObjects.append(im)
            index += 1
        }
        
        let timestamp = NSDate().timeIntervalSince1970
        let seconds = Int64(timestamp)
        
        imagesArrayObject.id = seconds
        imagesArrayObject.images = NSSet(array: imageObjects)
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func getCurrentLocation() {
        if CLLocationManager.locationServicesEnabled() == true{
            if CLLocationManager.authorizationStatus() == .restricted ||
                CLLocationManager.authorizationStatus() == .denied ||
                CLLocationManager.authorizationStatus() == .notDetermined{
                
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.desiredAccuracy = 1.0
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
            
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    
    func setUpViews() {
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        mainScroll = UIScrollView(frame: view.frame)
        mainScroll.backgroundColor = UIColor(named: "SpotBlack")
        mainScroll.isScrollEnabled = true
        mainScroll.isUserInteractionEnabled = true
        mainScroll.showsVerticalScrollIndicator = false
        view.addSubview(mainScroll)
        
        selectedImageView = UIImageView(frame: CGRect(x: 15, y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.isUserInteractionEnabled = true
        
        mainScroll.addSubview(selectedImageView)
        
        nextImageView = UIImageView(frame: CGRect(x: 15 + UIScreen.main.bounds.width, y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        nextImageView.contentMode = .scaleAspectFit
        nextImageView.isUserInteractionEnabled = true
        mainScroll.addSubview(nextImageView)
        
        previousImageView = UIImageView(frame: CGRect(x: -(15 + UIScreen.main.bounds.width), y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3))
        previousImageView.contentMode = .scaleAspectFit
        previousImageView.isUserInteractionEnabled = true
        mainScroll.addSubview(previousImageView)
        
        let divider = UIImageView(frame: CGRect(x: 0, y: selectedImageView.frame.maxY + 50, width: UIScreen.main.bounds.width, height: 5))
        divider.image = UIImage(named: "OverviewDivider")
        mainScroll.addSubview(divider)
        
        nearbyLabel = UILabel(frame: CGRect(x: 15, y: selectedImageView.frame.maxY + 69, width: 50, height: 15))
        nearbyLabel.text = "Post to an existing spot:"
        nearbyLabel.font = UIFont(name: "SFCamera-Semibold", size: 16)
        nearbyLabel.textColor = UIColor(red:0.54, green:0.54, blue:0.54, alpha:1.0)
        nearbyLabel.sizeToFit()
        mainScroll.addSubview(nearbyLabel)
        
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 250)
        
        nearbyScroll.setCollectionViewLayout(layout, animated: true)
        nearbyScroll.delegate = self
        nearbyScroll.dataSource = self
        nearbyScroll.frame = CGRect(x: 0, y: nearbyLabel.frame.maxY + 50, width: UIScreen.main.bounds.width, height: 250)
        nearbyScroll.showsHorizontalScrollIndicator = false
        nearbyScroll.backgroundColor = nil
        mainScroll.addSubview(nearbyScroll)
        nearbyScroll.register(SpotSimpleCell.self, forCellWithReuseIdentifier: "spotSimpleCell")
        
        self.mainScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: nearbyScroll.frame.maxY + 150)
        
        let createNewImage = UIImage(named: "CreateNewSpotButton")?.withRenderingMode(.alwaysOriginal)
        createNewButton = UIButton(frame: CGRect(x: 0, y: 0, width: 111, height: 27))
        createNewButton.imageView?.contentMode = .scaleAspectFit
        createNewButton.setBackgroundImage(createNewImage, for: .normal)
        createNewButton.addTarget(self, action: #selector(createNewTap(_:)), for: .touchUpInside)
        createNewButton.isHidden = true
        createNewButton.transform = CGAffineTransform(translationX: 0, y: 0)
        
        let barButtonContainer = UIView(frame: createNewButton.frame)
        barButtonContainer.addSubview(createNewButton)
        let buttonItem = UIBarButtonItem(customView: barButtonContainer)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "CreateNewSpotButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(createNewTap(_:)))
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
        
        if self.selectedImages.count != 0 {
            setUpSelectedImages()
        }
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: nearbyLabel.frame.maxY + 2, width: UIScreen.main.bounds.width, height: 45))
        searchBarContainer.backgroundColor = nil
        mainScroll.addSubview(searchBarContainer)
        
        searchBar = UISearchBar(frame: CGRect(x: 10, y: 0, width: UIScreen.main.bounds.width - 80, height: 30))
        searchBar.placeholder = "Search spots"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 65, y: 10.5, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
        searchBar.sizeToFit()
        
        resultsView = UITableView(frame: CGRect(x: 0, y: 15, width: UIScreen.main.bounds.width, height: 300))
        resultsView.dataSource = self
        resultsView.delegate = self
        resultsView.backgroundColor = UIColor(named: "SpotBlack")
        resultsView.separatorStyle = .none
        resultsView.isHidden = true
        resultsView.register(SpotSearchCell.self, forCellReuseIdentifier: "SpotSearch")
        view.addSubview(resultsView)
        
        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 40))
        resultsView.addSubview(searchIndicator)
        
    }
    func setUpSelectedImages() {
        selectedImageView.image = self.selectedImages[0]
        selectedImageView.roundCornersForAspectFit(radius: 8)
        setImageViewBounds()
        createNewButton.isHidden = false
        if gifMode {
            self.selectedImageView.animateGIF(directionUp: true, counter: 0, photos: self.selectedImages)
        } else {
            if self.selectedImages.count > 1 {
                self.nextImageView.image = self.selectedImages[1]
                self.nextImageView.roundCornersForAspectFit(radius: 8)
                self.setUpDotView(count: self.selectedImages.count)
                if !gifMode {
                    let swipe = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
                    swipe.cancelsTouchesInView = false
                    self.selectedImageView.addGestureRecognizer(swipe)
                }
            }
        }
        
        if !selectedImagesFromPicker.isEmpty {
            spotLocationRaw = selectedImagesFromPicker[0].2
        } else if spotLocationRaw == nil && currentLocation != nil {
            spotLocationRaw = currentLocation
        }
        if self.spotLocationRaw != nil && self.spotLocationRaw.coordinate.latitude != 0.0 {
            getNearbySpots(location: self.spotLocationRaw)
        }
    }
    
    func setUpDotView(count: Int) {
        if count < 2 { return }
        if dotView != nil {self.dotView.removeFromSuperview()}
        let dotY = self.selectedImageView.frame.maxY + 5
        dotView = UIView(frame: CGRect(x: 0, y: dotY, width: UIScreen.main.bounds.width, height: 10))
        dotView.backgroundColor = nil
        self.view.addSubview(dotView)
        
        var i = 1.0
        var xOffset = CGFloat(3.5 + (Double(count - 1) * 5.5))
        while i <= Double(count) {
            let view = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - xOffset, y: 0, width: 7, height: 7))
            view.layer.cornerRadius = 3.5
            
            if i == Double(self.selectedImageIndex + 1) {
                view.image = UIImage(named: "ElipsesFilled")
            } else {
                view.image = UIImage(named: "ElipsesUnfilled")
            }
            dotView.addSubview(view)
            
            i = i + 1.0
            xOffset = xOffset - 11
        }
    }
    
    @objc func imageSwipe(_ gesture: UIGestureRecognizer) {
        if let swipe = gesture as? UIPanGestureRecognizer {
            let direction = swipe.velocity(in: view)
            let translation = swipe.translation(in: self.view)
            
            if abs(translation.y) > abs(translation.x) {
                return
            }
            
            if direction.x < 0 || translation.x < 0 {
                if self.selectedImageIndex != self.selectedImages.count - 1 {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: 15, width: selectedImageView.frame.width, height: selectedImageView.frame.height)
                    selectedImageView.frame = frame0
                    
                    let frame1 = CGRect(x: selectedImageView.frame.minX + 30 + selectedImageView.frame.width, y: 15, width: nextImageView.frame.width, height: nextImageView.frame.height)
                    nextImageView.frame = frame1
                    
                    if swipe.state == .ended {
                        
                        if frame1.minX + direction.x < UIScreen.main.bounds.width/2 {
                            UIView.animate(withDuration: 0.2, animations: { (self.nextImageView.frame = CGRect(x: 15, y: 15, width: self.nextImageView.frame.width, height: self.nextImageView.frame.height))
                                self.selectedImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: 15, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                            })
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                
                                self.selectedImageIndex = self.selectedImageIndex + 1
                                self.setUpDotView(count: self.selectedImages.count)
                                
                                self.selectedImageView.image = self.selectedImages[self.selectedImageIndex]
                                if self.selectedImageIndex == self.selectedImages.count - 1 {
                                    if self.selectedImageView.image == UIImage(named: "AddMultipleButton") {
                                        
                                        self.selectedImageView.isUserInteractionEnabled = true
                                    }
                                }
                                
                                self.previousImageView.image = self.selectedImages[self.selectedImageIndex - 1]
                                self.selectedImageView.roundCornersForAspectFit(radius: 8)
                                self.previousImageView.roundCornersForAspectFit(radius: 8)
                                
                                self.setImageViewBounds()
                                
                                if self.selectedImageIndex != self.selectedImages.count - 1 {
                                    
                                    self.nextImageView.image = self.selectedImages[self.selectedImageIndex + 1]
                                    self.nextImageView.roundCornersForAspectFit(radius: 8)
                                    
                                }
                                
                                
                            }
                            
                        } else {
                            print("not less than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })
                            
                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                            //    self.tableView.reloadData()
                        }
                    }
                } else {
                    
                    let frame0 = CGRect(x: 0 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    if swipe.state == .ended {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            } else {
                if self.selectedImageIndex != 0 {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: 15, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    let frame1 = CGRect(x: self.selectedImageView.frame.minX - self.selectedImageView.frame.width - 30, y: 15, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height)
                    self.previousImageView.frame = frame1
                    
                    if swipe.state == .ended {
                        if frame1.maxX + direction.x > UIScreen.main.bounds.width/2 {
                            UIView.animate(withDuration: 0.2, animations: { (self.previousImageView.frame = CGRect(x: 15, y: 15, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height))
                                
                                self.selectedImageView.frame = CGRect(x: UIScreen.main.bounds.width + 15, y: 15, width: self.selectedImageView.bounds.width, height: self.selectedImageView.bounds.height)
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.selectedImageIndex = self.selectedImageIndex - 1
                                self.setUpDotView(count: self.selectedImages.count)
                                
                                self.selectedImageView.image = self.selectedImages[self.selectedImageIndex]
                                
                                self.nextImageView.image = self.selectedImages[self.selectedImageIndex + 1]
                                
                                self.selectedImageView.roundCornersForAspectFit(radius: 8)
                                
                                self.nextImageView.roundCornersForAspectFit(radius: 8)
                                
                                self.setImageViewBounds()
                                
                                if self.selectedImageIndex != 0 {
                                    self.previousImageView.image = self.selectedImages[self.selectedImageIndex - 1]
                                    self.previousImageView.roundCornersForAspectFit(radius: 8)
                                    
                                }
                                
                            }
                        } else {
                            print("not greater than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })
                            
                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                        }
                        
                    }
                } else {
                    
                    let frame0 = CGRect(x: 15 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0
                    
                    if swipe.state == .ended {
                        
                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            }
        }
    }
    
    
    @objc func createNewTap(_ sender: UIBarButtonItem) {
        
        let storyboard = UIStoryboard(name: "AddSpot", bundle: Bundle.main)
        if let viewController = storyboard.instantiateViewController(withIdentifier: "AddSpot") as? AddSpotViewController {
            viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: self, action: nil)
            var passImages: [UIImage] = []
            passImages = self.selectedImages
            viewController.passedSpotImages = passImages
            viewController.passedLocation = self.spotLocationRaw
            viewController.gifMode = self.gifMode
            //     viewController.animateGIF(directionUp: true, counter: 0)
            viewController.imageFromCamera = self.imageFromCamera
            if self.draftID != nil {viewController.draftID = self.draftID}
            self.navigationController?.pushViewController(viewController, animated: false)
        }
        
    }
    
    
    func getNearbySpots(location: CLLocation) {
        //clear horinzontal scroll
        self.listener2 = self.db.collection("users").document(self.uid).addSnapshotListener({ (userSnap, err) in
            self.friendsList = userSnap!.get("friendsList") as! [String]
            self.listener2.remove()
            self.nearbySpots.removeAll()
            for view in self.nearbyScroll.subviews {
                view.removeFromSuperview()
            }
            self.circleQuery = self.geoFirestore.query(withCenter: GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), radius: 0.5)
            
            let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)
        })
    }
    
    func loadSpotFromDB(key: String?, location: CLLocation?) {
        if let spotKey = key {
            
            self.listener1 = self.db.collection("spots").document(spotKey).addSnapshotListener({ (spotSnap, err) in
                
                if let privacyLevel = spotSnap!.get("privacyLevel") as? String {
                    
                    let distanceFromImage =
                        self.spotLocationRaw.distance(from: location!)
                    let founderID = spotSnap!.get("createdBy") as! String
                    let lat = location!.coordinate.latitude as Double
                    let long = location!.coordinate.longitude as Double
                    let id = spotSnap!.documentID
                    let spotName = spotSnap!.get("spotName") as! String
                    if let imageURL = spotSnap!.get("imageURL") as? String {
                        
                        switch privacyLevel {
                        case "invite":
                            let inviteList = spotSnap!.get("inviteList") as! [String]
                            if !inviteList.contains(self.uid) {
                                return
                            }
                        case "friends":
                            if !self.friendsList.isEmpty {
                                if (!self.friendsList.contains(founderID) && founderID != self.uid) {
                                    return
                                }
                            } else {
                                print("friend list empty")
                                return
                            }
                        default:
                            print("public")
                        }
                        
                        let tempSpot = SpotSimple(spotID: id, spotName: spotName, spotPicURL: imageURL, spotImage: UIImage(), spotLat: lat, spotLong: long, time: 0, userPostID: "", founderID: founderID, privacyLevel: privacyLevel)
                        if !self.nearbySpots.contains(where: {$0.0.spotID == id}) {
                            self.nearbySpots.append((tempSpot, distanceFromImage))
                            self.nearbySpots = self.nearbySpots.sorted(by: {$0.1 < $1.1})
                            self.nearbyScroll.reloadData()
                            
                            var image = UIImage()
                            
                            let gsRef = Storage.storage().reference(forURL: imageURL)
                            
                            gsRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
                                if (error != nil) {
                                    print("error occured in getting image from storage")
                                } else {
                                    image = UIImage(data: data!)!
                                    if let temp = self.nearbySpots.last(where: {$0.0.spotID == id}) {
                                        temp.0.spotImage = image
                                        self.nearbyScroll.reloadData()
                                    }
                                }
                            }
                        }
                    }
                }
            })
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return(CGSize(width: 125, height: 220))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.init(top: 0, left: 15, bottom: 5, right: 10)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if (!nearbySpots.isEmpty) {
            if nearbySpots.count < 5 {
                return nearbySpots.count
            } else {
                return 5
            }
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "spotSimpleCell", for: indexPath) as! SpotSimpleCell
        
        if (self.nearbySpots.isEmpty) {
            return cell
        }
        //initialize new spot cell
        cell.setUp(spot: nearbySpots[indexPath.row].0)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped(gesture:)))
        tapGesture.accessibilityHint = String(indexPath.row)
        cell.addGestureRecognizer(tapGesture)
        
        cell.backgroundColor = UIColor(named: "SpotBlack")
        
        return(cell)
        
    }
    
    @objc func imageTapped(gesture: UITapGestureRecognizer) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "CreatePost") as? CreatePostViewController {
            vc.navigationItem.backBarButtonItem?.title = ""
                        
            let hint = gesture.accessibilityHint!
            let position: Int? = Int(hint)
            let tappedSpot = nearbySpots[position!]
            
            vc.spotObject = ((id: tappedSpot.0.spotID, name: tappedSpot.0.spotName, tappedSpot.0.founderID))
            vc.gifMode = self.gifMode
            
            vc.passedImages = true
            vc.selectedImages = self.selectedImages
            if self.draftID != nil {vc.draftID = self.draftID}
            
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
    func setImageViewBounds() {
        
        if self.previousImageView != nil {
            self.previousImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
        
        if self.selectedImageView != nil {
            self.selectedImageView.frame = CGRect(x: 15, y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
        
        if self.nextImageView != nil {
            self.nextImageView.frame = CGRect(x: 15 + UIScreen.main.bounds.width, y: 15, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1/3)
        }
        
    }
    
}

extension AddOverviewController: UINavigationControllerDelegate, CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            currentLocation = locations[0]
            if self.spotLocationRaw == nil || self.spotLocationRaw.coordinate.longitude == 0.0 {
                self.spotLocationRaw = currentLocation
                self.getNearbySpots(location: currentLocation)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error){
        print("Unable to access your current location")
    }
}
extension AddOverviewController: UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.2) {
            self.searchBarContainer.removeFromSuperview()
            self.navigationController?.isNavigationBarHidden = true
            var offset: CGFloat = 0
            if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
                offset = 30
            }
            self.mainScroll.isHidden = true
            self.searchBarContainer.frame = CGRect(x: self.searchBarContainer.frame.minX, y: 20 + offset, width: self.searchBarContainer.frame.width, height: self.searchBarContainer.frame.height)
            self.searchIndicator.isHidden = true
            self.view.addSubview(self.searchBarContainer)
            self.cancelButton.isHidden = false
            self.view.bringSubviewToFront(self.resultsView)
            self.resultsView.isHidden = false
            self.resultsView.frame = CGRect(x: 0, y: self.searchBarContainer.frame.maxY + 20, width: UIScreen.main.bounds.width, height: 300)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            searchBar.becomeFirstResponder()
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        cancelSearch()
    }
    
    @objc func searchCancelTap(_ sender: UIButton) {
        cancelSearch()
        self.searchBar.endEditing(true)
    }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print(searchText)
        if searchBar.text?.count == 0 {
            if !self.querySpots.isEmpty {
                self.querySpots.removeAll()
                self.resultsView.reloadData()
            }
        } else {
            self.runQuery(searchText: searchText)
        }
    }
    
    func runQuery(searchText: String) {
        self.searchTextGlobal = searchText
        
        self.querySpots.removeAll()
        if !self.searchIndicator.isAnimating() { self.searchIndicator.startAnimating() }
        
        self.resultsView.reloadData()
        
        let spotsRef = db.collection("spots")
        let maxVal = "\(searchText.lowercased())uf8ff"
        
        let spotsQuery = spotsRef.whereField("lowercaseName", isGreaterThanOrEqualTo: searchText.lowercased()).whereField("lowercaseName", isLessThanOrEqualTo: maxVal as Any)
        
        listener3 = spotsQuery.addSnapshotListener({ (snap, err) in
            guard let docs = snap?.documents else {
                return
            }
            for doc in docs {
                do {
                    let spotInfo = try doc.data(as: ResultSpot.self)
                    var info = spotInfo!
                    info.spotLat = spotInfo!.l[0] as Double
                    info.spotLong = spotInfo!.l[1] as Double
                    
                    if self.hasAccess(creatorID: spotInfo!.founderID, privacyLevel: spotInfo!.privacyLevel, inviteList: spotInfo!.inviteList ?? []) {
                        if self.querySpots.count < 6 {
                            if !self.querySpots.contains(where: {$0.id == info.id}) && self.searchTextGlobal == searchText {
                                self.searchIndicator.stopAnimating()
                                self.querySpots.append(info)
                                self.resultsView.reloadData()
                                self.updateQueryImage(spot: info)
                            }
                        } else {
                            return
                        }
                    }
                } catch {
                    return
                }
            }
        })
        
    }
    
    func updateQueryImage(spot: ResultSpot) {
        let gsRef = Storage.storage().reference(forURL: spot.imageURL)
        
        gsRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
            if (error != nil) {
                print("error occured in getting image from storage")
            } else {
                let image = UIImage(data: data!)!
                 if let i = self.querySpots.lastIndex(where: {$0.id == spot.id}) {
                    self.querySpots[i].spotImage = image
                    self.resultsView.reloadData()
                }
            }
        }
    }
    
    func hasAccess(creatorID: String, privacyLevel: String, inviteList: [String]) -> Bool {
        if privacyLevel == "friends" {
            if !self.friendsList.contains(where: {$0 == creatorID}) {
                if self.uid != creatorID {
                    return false
                }
            }
        } else if privacyLevel == "invite" {
            if !inviteList.contains(where: {$0 == self.uid}) {
                return false
            }
        }
        return true
    }
    
    func cancelSearch() {
        UIView.animate(withDuration: 0.2) {
            self.cancelButton.isHidden = true
            self.searchBar.text = ""
            self.searchBarContainer.removeFromSuperview()
            self.mainScroll.addSubview(self.searchBarContainer)
            self.resultsView.isHidden = true
            self.mainScroll.isHidden = false
            self.searchBarContainer.frame = CGRect(x: self.searchBarContainer.frame.minX, y: self.nearbyLabel.frame.maxY + 2, width: self.searchBarContainer.frame.width, height: self.searchBarContainer.frame.height)
            self.navigationController?.isNavigationBarHidden = false
            self.querySpots.removeAll()
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return querySpots.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpotSearch") as! SpotSearchCell
        if self.querySpots.count > indexPath.row {
            cell.setUpSpot(spot: self.querySpots[indexPath.row])
        }
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "CreatePost") as? CreatePostViewController {
            vc.navigationItem.backBarButtonItem?.title = ""
                        
            if querySpots.count > indexPath.row {
                let tappedSpot = querySpots[indexPath.row]
                
                vc.spotObject = ((id: tappedSpot.id!, name: tappedSpot.spotName, tappedSpot.founderID))
                vc.gifMode = self.gifMode
                
                vc.passedImages = true
                vc.selectedImages = self.selectedImages
                if self.draftID != nil {vc.draftID = self.draftID}
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
}


class SpotSimpleCell: UICollectionViewCell {
    var spotName: UILabel!
    var spotImage: UIImageView!
    var plusIcon: UIImageView!
    
    func setUp(spot: SpotSimple) {
        spotImage = UIImageView(frame: CGRect(x: 0, y: 0, width: 118, height: 176))
        spotImage.image = (spot.spotImage as! UIImage)
        spotImage.layer.cornerRadius = 8
        spotImage.contentMode = .scaleAspectFill
        spotImage.clipsToBounds = true
        self.addSubview(spotImage)
        
        spotName = UILabel(frame: CGRect(x: 2, y: 180, width: 118, height: 30))
        spotName.font = UIFont(name: "SFCamera-Semibold", size : 14)
        spotName.textColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.0)
        spotName.lineBreakMode = .byWordWrapping
        spotName.numberOfLines = 0
        spotName.text = spot.spotName
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        spotName.sizeToFit()
        self.addSubview(spotName)
        
        plusIcon = UIImageView(frame: CGRect(x: spotImage.bounds.width/2 - 17, y: spotImage.bounds.height/2 - 17, width: 34, height: 34))
        plusIcon.image = UIImage(named: "AddToExistingIcon")
        spotImage.addSubview(plusIcon)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func prepareForReuse() {
        spotImage.image = UIImage()
        spotName.text = ""
        plusIcon.image = UIImage()
    }
    
}
