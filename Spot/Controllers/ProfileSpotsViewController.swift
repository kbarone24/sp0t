
//  ProfileSpotsViewController.swift
//  
//
//  Created by kbarone on 6/27/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.


import Foundation
import UIKit
import Firebase
import CoreLocation
import MapKit
import FirebaseUI
import Mixpanel

class ProfileSpotsViewController: UIViewController {
    
    unowned var mapVC: MapViewController!
    weak var profileVC: ProfileViewController!

    var spotsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    var spotsLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    var spotsIndicator: CustomActivityIndicator!
    
    var listener1, listener2: ListenerRegistration!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    
    lazy var spotsList: [MapSpot] = []
    lazy var cityList: [(city: String, time: Int64)] = []
    lazy var spotAnnotations = [String: CustomSpotAnnotation]()
    
    lazy var active = false
    lazy var loaded = false
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        setUpSpotsCollection()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.profileVC == nil { return }
            self.getSpots()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifySpotOpen(_:)), name: NSNotification.Name("MapSpotOpen"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewSpot(_:)), name: NSNotification.Name("NewSpot"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditSpot(_:)), name: NSNotification.Name("EditSpot"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeleteSpot(_:)), name: NSNotification.Name("DeleteSpot"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeleteSpot(_:)), name: NSNotification.Name("UserListRemove"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        ///pause any active download tasks on switch between controllers or on profileRemove
        super.viewDidDisappear(animated)
        active = false
        mapVC.profileAnnotations.removeAll()
        cancelDownloads()
    }
    
    override func viewDidAppear(_ animated: Bool) {
         
        ///resume any paused download tasks on switch between controllers
        super.viewDidAppear(animated)
        if profileVC.children.contains(where: {$0 is SpotViewController}) { return }
        resetView()
        resumeIndicatorAnimation()
        Mixpanel.mainInstance().track(event: "ProfileSpotsOpen")
    }
    
    func resumeIndicatorAnimation() {
        
        if profileVC == nil || profileVC.userInfo == nil { return }
        if self.spotsIndicator != nil && spotsList.count == 0 {
            if uid == profileVC.userInfo.id && profileVC.userInfo.spotsList.isEmpty { return } /// return on empty state
            DispatchQueue.main.async { self.spotsIndicator.startAnimating() }
        }
    }

    func resetView() {
        active = true
        addAnnotations()
    }
    
    func addAnnotations() {
        
        let annotations = self.mapVC.mapView.annotations
        self.mapVC.mapView.removeAnnotations(annotations)
        self.mapVC.postsList.removeAll()
        
        if !spotAnnotations.isEmpty {
            mapVC.profileAnnotations = spotAnnotations
            for anno in spotAnnotations {
                self.mapVC.mapView.addAnnotation(anno.value) }
            
            /// call reload in case cell images didn't finish loading
            DispatchQueue.main.async { self.spotsCollection.reloadData() }
        }
        
        if profileVC.passedCamera != nil {
            /// passed camera represents where the profile was before entering spot
            mapVC.mapView.setCamera(profileVC.passedCamera, animated: false)
            profileVC.passedCamera = nil
        } else {
            mapVC.animateToProfileLocation(active: uid == profileVC.id, coordinate: CLLocationCoordinate2D())
        }
    }
    
    func cancelDownloads() {
        for cell in spotsCollection.visibleCells {
            guard let spotCell = cell as? SpotCollectionCell else { return }
            spotCell.spotImage.sd_cancelCurrentImageLoad()
        }
    } 
    
    @objc func notifySpotOpen(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        guard let id = userInfo.first?.value as? String else { return }
        if let spot = spotsList.first(where: {$0.id == id}) {
            openSpot(spot: spot)
        }
    }
    
    @objc func notifyNewSpot(_ notification: NSNotification) {
        
        if let newSpot = notification.userInfo?.first?.value as? MapSpot {
            
            profileVC.removeEmptyState()
            spotsList.append(newSpot)
            addSpotCoordinate(spot: newSpot)
            spotsCollection.reloadData()
            let interval = NSDate().timeIntervalSince1970
            
            updateCityList(spot: newSpot, seconds: Int64(interval))
        }
    }
    
    @objc func notifyEditSpot(_ notification: NSNotification) {
        if let editSpot = notification.userInfo?.first?.value as? MapSpot {
            if let index = self.spotsList.firstIndex(where: {$0.id == editSpot.id}) {
                spotsList[index] = editSpot
                spotsCollection.reloadData()
            }
            if let anno = spotAnnotations.first(where: {$0.key == editSpot.id}) {
                anno.value.coordinate = CLLocationCoordinate2D(latitude: editSpot.spotLat, longitude: editSpot.spotLong)
            }
        }
    }
    
    @objc func notifyDeleteSpot(_ notification: NSNotification) {
        
        if let spotID = notification.userInfo?.first?.value as? String {
            if let index = spotsList.firstIndex(where: {$0.id == spotID}) {
                let spotCity = spotsList[index].city
                spotsList.remove(at: index)
                if !spotsList.contains(where: {$0.city == spotCity}) {
                    cityList.removeAll(where: {$0.city == spotCity})
                }
                spotsCollection.reloadData()
            }
            
            if let aIndex = spotAnnotations.firstIndex(where: {$0.key == spotID}) {
                spotAnnotations.remove(at: aIndex)
            }
        }
    }
    
    @objc func notifyWillEnterForeground(_ notification: NSNotification) {
        resumeIndicatorAnimation()
    }
    
    func setUpSpotsCollection() {
        
        let width = (UIScreen.main.bounds.width - 38) / 2
        spotsLayout.minimumInteritemSpacing = 10
        spotsLayout.minimumLineSpacing = 17
        spotsLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 50)
        spotsLayout.itemSize = CGSize(width: width, height: 44)
        spotsLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        
        spotsCollection.frame = view.frame
        spotsCollection.contentInset = UIEdgeInsets(top: 5, left: 14, bottom: 250, right: 14)
        spotsCollection.setCollectionViewLayout(spotsLayout, animated: true)
        spotsCollection.delegate = self
        spotsCollection.dataSource = self
        spotsCollection.backgroundColor = UIColor(named: "SpotBlack")
        spotsCollection.showsVerticalScrollIndicator = false 
        spotsCollection.register(SpotCollectionCell.self, forCellWithReuseIdentifier: "SpotCell")
        spotsCollection.register(CityHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SpotsHeader")
        view.addSubview(spotsCollection)
        
        spotsIndicator = CustomActivityIndicator(frame: CGRect(x: -10, y: 20, width: UIScreen.main.bounds.width, height: 30))
        spotsIndicator.isHidden = true
        spotsCollection.addSubview(spotsIndicator)
    }
    
    func getSpots() {
        
        let query = db.collection("users").document(profileVC.id).collection("spotsList").order(by: "checkInTime", descending: true)
        
        listener1 = query.addSnapshotListener({ [weak self] (snap, err) in

            guard let self = self else { return }
            if self.profileVC == nil { return }
            guard let listDocs = snap?.documents else { return }
            
            if listDocs.count == 0 { self.finishLoad() }
            
            var index = 0
                
            listLoop: for list in listDocs {
                
                self.listener2 = self.db.collection("spots").document(list.documentID).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (doc, err) in
                    
                    guard let self = self else { return }
                    if self.profileVC == nil { return }

                    do {
                        
                        let postInfo = try doc?.data(as: MapSpot.self)
                        guard var info = postInfo else {
                            index += 1; if index == listDocs.count {self.finishLoad()}; return }
                        
                        info.id = list.documentID
                        let timestamp = list.get("checkInTime") as? Timestamp ?? Timestamp()
                        info.checkInTime = timestamp.seconds
                        
                        if info.city == nil {
                            /// set city, try to update city in DB
                            info.city = "City, Earth"
                            if self.uid == self.profileVC.id { self.updateNilCity(spot: info) }
                        }
                        
                        //privacy check
                        if self.hasAccess(spot: info) {
                                                             
                            /// animate map to first spot location if this isn't the active user
                            if index == 0 && self.spotsList.isEmpty && self.uid != self.profileVC.id {
                                self.profileVC.mapVC.animateToProfileLocation(active: false, coordinate: CLLocationCoordinate2D(latitude: info.spotLat, longitude: info.spotLong))
                            }

                            if let index = self.spotsList.firstIndex(where: {$0.id == info.id }) {
                                self.spotsList[index] = info
                            } else {
                                if self.mapVC.deletedSpotIDs.contains(info.id ?? "") {
                                    index += 1
                                    if index == listDocs.count { self.finishLoad() }
                                    return
                                }

                                self.spotsList.append(info)
                                self.addSpotCoordinate(spot: info)
                            }

                            ///get placemark if city returns empty
                            let timestamp = list.get("checkInTime") as? Timestamp ?? Timestamp()
                            let seconds = timestamp.seconds
                            self.updateCityList(spot: info, seconds: seconds)
                            
                        }
                        
                        index += 1
                        if index == listDocs.count { self.finishLoad() }
                    
                    } catch {
                        index += 1
                        if index == listDocs.count { self.finishLoad() }
                    }
                })
                
            }
        })
    }
    
    func finishLoad() {
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            if self.profileVC == nil { return }

            if self.mapVC.customTabBar.view.frame.minY < 200 && self.profileVC.selectedIndex == 0 { self.profileVC.shadowScroll.isScrollEnabled = true }
            
            self.loaded = true
            self.spotsIndicator.stopAnimating()
            
            self.spotsCollection.reloadData()
            self.spotsCollection.performBatchUpdates(nil, completion: { [weak self]
                (result) in
                guard let self = self else { return }
                if self.profileVC.selectedIndex == 0 { self.profileVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.profileVC.sec0Height, self.spotsCollection.contentSize.height + 300)) }
            })
            
            if self.profileVC.userInfo != nil && self.profileVC.userInfo.id == self.uid {
                self.profileVC.userInfo.spotsList = self.spotsList.map({$0.id ?? ""})
                self.mapVC.userInfo.spotsList = self.spotsList.map({$0.id ?? ""})
                if self.spotsList.count > 0 { self.profileVC.removeEmptyState(); self.profileVC.mapVC.checkForTutorial(index: 3) }
                else { self.profileVC.addEmptyState() }
            }
        }
    }
    
    func updateCityList(spot: MapSpot, seconds: Int64) {
        
        let spotCity = spot.city
        if let temp = cityList.last(where: {$0.city == spotCity}) {
            
            if seconds > temp.time {
                cityList.removeAll(where: {$0.city == spotCity})
                cityList.append((city: temp.city, time: seconds))
            }
            
        } else {
            self.cityList.append((spotCity ?? "", seconds))
        }
        
        cityList = cityList.sorted(by: {$0.time > $1.time})
        spotsList.sort(by: {$0.city == $1.city ? $0.checkInTime > $1.checkInTime : $0.city ?? "" > $1.city ?? "" })
    }
    
    func addSpotCoordinate(spot: MapSpot) {
        
        let annotation = CustomSpotAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        annotation.spotInfo = spot
        annotation.title = spot.spotName
        spotAnnotations.updateValue(annotation, forKey: spot.id!)
        
        let rank = mapVC.getSpotRank(spot: spot)
        spotAnnotations[spot.id!]?.rank = rank
        
        if active {
            mapVC.mapView.addAnnotation(annotation)
            mapVC.profileAnnotations = self.spotAnnotations
        }
    }
    
    func hasAccess(spot: MapSpot) -> Bool {
        if uid != profileVC.id {
            switch spot.privacyLevel {
            case "invite":
                if !(spot.inviteList?.contains(where: {$0 == uid}) ?? false) {
                    return false
                }
            case "friends":
                if !mapVC.friendIDs.contains(where: {$0 == spot.founderID}) {
                    return false
                }
            default:
                return true
            }
        }
        return true
    }
    
    func removeListeners() {
        if listener1 != nil { listener1.remove() }
        if listener2 != nil { listener2.remove() }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("MapSpotOpen"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("NewSpot"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditSpot"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeleteSpot"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UserListRemove"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func updateNilCity(spot: MapSpot) {
        /// sometimes CLPlacemark will fail on upload if the user searches for a bunch of spots ahead of upload, it could get throttled. This is a patch fix for that
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { (city) in
            self.db.collection("spots").document(spot.id!).updateData(["city" : city])
        }

    }
}

extension ProfileSpotsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var count = 0
        for spot in spotsList {
            if spot.city == cityList[section].city {
                count = count + 1
            }
        }

        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpotCell", for: indexPath) as! SpotCollectionCell
        
        /// break out spotsList into subsets for each city
        var subset: [MapSpot] = []
        for spot in spotsList {
            if spot.city == cityList[indexPath.section].city {
                subset.append(spot)
            }
        }
        
        if subset.count <= indexPath.row { return cell }
        cell.setUp(spot: subset[indexPath.row])
        return cell
    
    }
        
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return cityList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? SpotCollectionCell else { return }
        cell.spotImage.image = UIImage()
        
        var subset: [MapSpot] = []
        for spot in spotsList {
            if spot.city == cityList[indexPath.section].city {
                subset.append(spot)
            }
        }
        
        guard let spot = subset[safe: indexPath.row] else { return }
        
        if cell.cachedImage.spotID == spot.id! && cell.cachedImage.image != UIImage() {
            cell.spotImage.image = cell.cachedImage.image
            return
        }
        
        let url = spot.imageURL
        
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            cell.spotImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, _, _, _) in
                if image != nil { cell.cachedImage.image = image ?? UIImage() }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? SpotCollectionCell else { return }
        cell.cachedImage.spotID = cell.spotObject.id ?? "" 
        cell.spotImage.sd_cancelCurrentImageLoad()
        cell.spotImage.image = UIImage()
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SpotsHeader", for: indexPath) as! CityHeader
        view.setUp(city: cityList[indexPath.section].city)
        return view
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = spotsCollection.cellForItem(at: indexPath) as? SpotCollectionCell {
            openSpot(spot: cell.spotObject)
        }
    }
    
    func openSpot(spot: MapSpot) {
        
        let infoPass = ["spot": spot as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("OpenSpotFromProfile"), object: nil, userInfo: infoPass)
        
        if let spotVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "SpotPage") as? SpotViewController {
            
            /// cancel sd web downloads
            cancelDownloads()

            // eventually adjust to half screen if closed
            spotVC.spotID = spot.id ?? ""
            spotVC.spotObject = spot
            spotVC.mapVC = mapVC
            
            mapVC.postsList.removeAll()
            mapVC.profileViewController = nil
            
            profileVC.shadowScroll.isScrollEnabled = false
            profileVC.passedCamera = MKMapCamera(lookingAtCenter: mapVC.mapView.centerCoordinate, fromDistance: mapVC.mapView.camera.centerCoordinateDistance, pitch: mapVC.mapView.camera.pitch, heading: mapVC.mapView.camera.heading)
            
            spotVC.view.frame = profileVC.view.frame
            profileVC.addChild(spotVC)
            profileVC.view.addSubview(spotVC.view)
            spotVC.didMove(toParent: profileVC)
            
            self.mapVC.prePanY = self.mapVC.halfScreenY
            DispatchQueue.main.async { self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: self.mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - self.mapVC.halfScreenY) }
        }
    }
}


class SpotCollectionCell: UICollectionViewCell {
    
    var spotObject: MapSpot!
    var spotName: UILabel!
    lazy var spotImage = UIImageView()
    lazy var cachedImage: ((image: UIImage, spotID: String)) = ((UIImage(), ""))

    func setUp(spot: MapSpot) {
        
        self.backgroundColor = nil
        self.spotObject = spot
        
        spotImage.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        spotImage.layer.cornerRadius = 5
        spotImage.layer.masksToBounds = true
        spotImage.clipsToBounds = true
        spotImage.contentMode = .scaleAspectFill
        self.addSubview(spotImage)
        
        if spotName != nil { spotName.text = "" }
        spotName = UILabel(frame: CGRect(x: 52, y: 7, width: self.frame.width - 54, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.clipsToBounds = true
        spotName.textAlignment = .left
        spotName.lineBreakMode = .byTruncatingTail
        spotName.numberOfLines = 2
        spotName.sizeToFit()
        spotName.frame = CGRect(x: 52, y: (44 - spotName.frame.height)/2 - 1, width: spotName.frame.width, height: spotName.frame.height)
        self.addSubview(spotName)
    }
}

class CityHeader: UICollectionReusableView {
    
    var cityLabel: UILabel!
    
    func setUp(city: String) {
        if cityLabel != nil { cityLabel.text = "" }
        cityLabel = UILabel(frame: CGRect(x: 0, y: 14, width: UIScreen.main.bounds.width - 28, height: 16))
        cityLabel.text = city
        cityLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        cityLabel.textColor = UIColor(red: 0.61, green: 0.61, blue: 0.61, alpha: 1.00)
        cityLabel.sizeToFit()
        self.addSubview(cityLabel)
    }
}
