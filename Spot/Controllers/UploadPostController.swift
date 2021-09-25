//
//  UploadPostController.swift
//  Spot
//
//  Created by kbarone on 9/17/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Photos
import CoreLocation
import Geofirestore
import Mixpanel
import CoreData
import FirebaseUI
import MapKit

class UploadPostController: UIViewController {
    
    var scrollObjects: [ScrollObject] = []
    
    unowned var mapVC: MapViewController!
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))

    var spotObject: MapSpot!
    var postObject: MapPost!
    
    var tableView: UITableView!
    var maskView: UIView!
    var previewView: GalleryPreviewView!
    
    var tapToClose: UITapGestureRecognizer!
    var navBarHeight: CGFloat!
    
    lazy var imageFetcher = ImageFetcher()
    var cancelOnDismiss = false
    var editedLocation = false
    var newSpotName = ""
    
    var circleQuery: GFSCircleQuery?
    var search: MKLocalSearch!
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]
    
    var queryReady = false
    
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyRefreshCount = 0
    
    var postType: PostType = .none
    var submitPublic = false
    var privacyCloseTap: UITapGestureRecognizer!

    enum PostType {
        case none
        case postToPOI
        case postToSpot
        case newSpot
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "UploadPostOpen")
        
        
        tapToClose = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard(_:)))
        tapToClose.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name("InitialUserLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name("InitialFriendsLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCurrentLocation(_:)), name: Notification.Name("UpdateLocation"), object: nil)


        setUpPost()
        setUpTable()
        getTopFriends()
        fetchAssets()
        
        if spotObject == nil { DispatchQueue.global().async {
            self.runChooseSpotFetch()
        }}
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setUpNavBar()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
      //  cancelOnDismiss = true
    }
    
    deinit {
        print("deinit")
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("InitialUserLoad"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("UpdateLocation"), object: nil)
        UploadImageModel.shared.destroy()
    }
    
    func setUpNavBar() {
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.removeShadow()
        navigationController?.navigationBar.addBlackBackground()
        navigationItem.titleView = nil
        
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTap(_:)))
        cancelButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCamera-Regular", size: 14.5) as Any, NSAttributedString.Key.foregroundColor: UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1) as Any], for: .normal)
        navigationItem.leftBarButtonItem = cancelButton
        
        addPostButton()
    }
    
    func addPostButton() {
        let alpha: CGFloat = spotObject == nil ? 0.3 : 1.0
        let postImage = UIImage(named: "PostButton")?.alpha(alpha).withRenderingMode(.alwaysOriginal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: postImage, style: .plain, target: self, action: #selector(postTap(_:)))
    }
    
    func setUpPost() {
        /// add currentLocation == nil check
        postObject = MapPost(id: UUID().uuidString, caption: "", postLat: UserDataModel.shared.currentLocation.coordinate.latitude, postLong: UserDataModel.shared.currentLocation.coordinate.longitude, posterID: uid, timestamp: Timestamp(date: Date()), actualTimestamp: Timestamp(date: Date()), userInfo: UserDataModel.shared.userInfo, spotID: spotObject == nil ? UUID().uuidString : spotObject.id, city: "", frameIndexes: [], aspectRatios: [], imageURLs: [], postImage: [], seconds: 0, selectedImageIndex: 0, postScore: 0, commentList: [], likers: [], taggedUsers: [], captionHeight: 0, imageHeight: 0, cellHeight: 0, spotName: spotObject == nil ? "" : spotObject.spotName, spotLat: spotObject == nil ? 0 : spotObject.spotLat, spotLong: spotObject == nil ? 0 : spotObject.spotLong, privacyLevel: spotObject == nil ? "friends" : spotObject.privacyLevel, spotPrivacy: spotObject == nil ? "" : spotObject.privacyLevel, createdBy: spotObject == nil ? uid : spotObject.founderID, inviteList: [], friendsList: [], isFirst: false, hideFromFeed: false, gif: false, addedUsers: [], addedUserProfiles: [], tag: "")
    }
    
    func setUpTable() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
            (self.navigationController?.navigationBar.frame.height ?? 44.0)
        
        
        tableView = UITableView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight))
        tableView.backgroundColor = UIColor(red: 0.008, green: 0.008, blue: 0.008, alpha: 1)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = false
        tableView.isScrollEnabled = UserDataModel.shared.screenSize == 0 /// scroll only needed for smaller screens
        tableView.showsVerticalScrollIndicator = false
        tableView.register(UploadOverviewCell.self, forCellReuseIdentifier: "UploadOverview")
        tableView.register(UploadChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
        tableView.register(UploadChooseTagCell.self, forCellReuseIdentifier: "ChooseTag")
        tableView.register(UploadAddFriendsCell.self, forCellReuseIdentifier: "AddFriends")
        tableView.register(UploadShowOnFeedCell.self, forCellReuseIdentifier: "ShowOnFeed")
        tableView.register(UploadPrivacyCell.self, forCellReuseIdentifier: "Privacy")
        view.addSubview(tableView)
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maskTap(_:))))
        maskView.isUserInteractionEnabled = true
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
    }
    
    func getTopFriends() {
        
        UploadImageModel.shared.friendObjects.removeAll()
        
        // kind of messy
        var sortedFriends = UserDataModel.shared.userInfo.topFriends.sorted(by: {$0.value > $1.value})
        sortedFriends.removeAll(where: {$0.value < 1})
        let topFriends = Array(sortedFriends.map({$0.key}).prefix(7))
        
        for friend in topFriends { if let friendObject = UserDataModel.shared.friendsList.first(where: {$0.id == friend}) {
            UploadImageModel.shared.friendObjects.append(friendObject)
        }}
        
        /// if not enough top friends, append first friends from regular friendslist 
        if UploadImageModel.shared.friendObjects.count < 7 {
            for friend in UserDataModel.shared.friendsList {
                if UploadImageModel.shared.friendObjects.count < 7 && !UploadImageModel.shared.friendObjects.contains(where: {$0.id == friend.id}) { UploadImageModel.shared.friendObjects.append(friend) }
            }
        }
    }
    
    func fetchAssets() {
        if UploadImageModel.shared.galleryAccess != .authorized { askForGallery(first: true) }
        fetchInitialAssets()
        fetchFullAssets()
    }
    
    func fetchInitialAssets() {
                
        // fetch first 5 photos for initial load
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 5
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        let assets = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        if assets.count == 0 { return }
        let indexSet = assets.count > 5 ? IndexSet(0...4) : IndexSet(0...assets.count - 1)
        
        
        DispatchQueue.global(qos: .userInitiated).async { assets.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            guard let self = self else { return }
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            let imageObj = ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], gifMode: false, creationDate: creationDate)
            self.scrollObjects.append(ScrollObject(imageObject: imageObj, selected: false, fromCamera: false))
            UploadImageModel.shared.imageObjects.append((imageObj, false))
            
            if self.scrollObjects.count == assets.count {
                self.scrollObjects.sort(by: {$0.imageObject.creationDate > $1.imageObject.creationDate})
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }}
    }
    
    func fetchFullAssets() {
        
        /// fetch the first 5 assets and show them in the image scroll, fetch next 10000 for gallery/photo map/proximity-to-spot pics
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 10000
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        if assetsFull.count < 6 { return }
        
        let indexSet = assetsFull.count > 10000 ? IndexSet(4...9999) : IndexSet(4...assetsFull.count - 1)
        UploadImageModel.shared.assetsFull = assetsFull
        
      //  var localObjects: [(ImageObject, Bool)] = []
        
        DispatchQueue.global(qos: .default).async { assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            
            guard let self = self else { return }
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
                let imageObj = (ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], gifMode: false, creationDate: creationDate), false)
                UploadImageModel.shared.imageObjects.append(imageObj)
                
                if UploadImageModel.shared.imageObjects.count % 1000 == 0 ||  UploadImageModel.shared.imageObjects.count == assetsFull.count {
                    
                    /// don't sort if photos container already added
                    if !(self.navigationController?.viewControllers.contains(where: {$0 is PhotosContainerController}) ?? false) { UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected}) }
                }
            }
        }
    }
    
    @objc func notifyCurrentLocation(_ sender: NSNotification) {
        if postObject.postLat == 0.0 && postObject.postLong == 0.0 {
            postObject.postLat = UserDataModel.shared.currentLocation.coordinate.latitude
            postObject.postLong = UserDataModel.shared.currentLocation.coordinate.longitude
        }
    }
    
    @objc func notifyUserLoad(_ sender: NSNotification) {
        
        postObject.userInfo = UserDataModel.shared.userInfo

        /// reload for loaded user profile pic
        if tableView != nil { DispatchQueue.main.async { self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none) } }
    }
    
    @objc func notifyFriendsLoad(_ sender: NSNotification) {
        ///rerun getTopFriends search if not fully loaded on initial open
        getTopFriends()
        guard let cell = tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? UploadAddFriendsCell else { return }
        DispatchQueue.main.async { cell.addFriendsCollection.reloadData() }
    }
    
    @objc func tagSelect(_ sender: NSNotification) {
        
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let username = infoPass["username"] as? String else { return }
        guard let tag = infoPass["tag"] as? Int else { return }
        if tag != 2 { return } /// tag 2 for upload tag. This notification should only come through if tag = 2 because upload will always be topmost VC
        guard let uploadOverviewCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        
        let cursorPosition = uploadOverviewCell.captionView.getCursorPosition()
        let tagText = addTaggedUserTo(text: postObject.caption, username: username, cursorPosition: cursorPosition)
        postObject.caption = tagText
        uploadOverviewCell.captionView.text = tagText
    }
    
    @objc func closeKeyboard(_ sender: UITapGestureRecognizer) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        if cell.captionView != nil { cell.captionView.resignFirstResponder() }
    }
    
    @objc func cancelTap(_ sender: UIButton) {
        
        let controllers = self.navigationController?.viewControllers
        
        if controllers?.count == 2 {
            self.popToMap()
        } else {
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    @objc func postTap(_ sender: UIButton) {
        
    }
    
    func popToMap() {
        
        mapVC.customTabBar.tabBar.isHidden = false
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromBottom
        
        DispatchQueue.main.async {
            self.navigationController?.view.layer.add(transition, forKey:kCATransition)
            self.navigationController?.popViewController(animated: false)
        }
    }
    
    func runChooseSpotFetch() {
        /// called initially and also after an image is selected
        if !UploadImageModel.shared.nearbySpots.isEmpty { UploadImageModel.shared.nearbySpots.removeAll(where: {!$0.selected!}) }
                
        queryReady = false
        nearbyEnteredCount = 0
        noAccessCount = 0
        nearbyRefreshCount = 0

        getNearbySpots()
        getNearbyPOIs()
    }
    
    func getNearbyPOIs() {
        
        let searchRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: postObject.postLat, longitude: postObject.postLong), radius: 200)
        
        /// these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
        let filters = MKPointOfInterestFilter(including: searchFilters)
        searchRequest.pointOfInterestFilter = filters
        
        runPOIFetch(request: searchRequest)
    }
    
    /// recursive func called with an increasing radius -> Ensure always fetching the closest POI's since max limit is 25
    func runPOIFetch(request: MKLocalPointsOfInterestRequest) {
            
        if search != nil { search.cancel() }
        search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in

            guard let self = self else { return }
            
            let newRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: self.postObject.postLat, longitude: self.postObject.postLong), radius: request.radius * 2)
            newRequest.pointOfInterestFilter = request.pointOfInterestFilter
            
            /// if the new radius won't be greater than about 1.5 miles then run poi fetch to get more nearby stuff
            guard let response = response else {
                /// error usually means no results found
                newRequest.radius < 3000 ? self.runPOIFetch(request: newRequest) : self.endQuery()
                return
            }
            
            /// > 10 poi's should be enough for the table, otherwise re-run fetch
            if response.mapItems.count < 10 && newRequest.radius < 3000 {   self.runPOIFetch(request: newRequest); return }
            
            var index = 0
            
            for item in response.mapItems {

                if item.pointOfInterestCategory != nil && item.name != nil {

                    let phone = item.phoneNumber ?? ""
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                    
                    /// check for spot duplicate
                    if UploadImageModel.shared.nearbySpots.contains(where: {$0.spotName == name || $0.phone == phone}) { index += 1; if index == response.mapItems.count { self.endQuery() }; continue }
                                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    spotInfo.phone = phone
                    spotInfo.id = UUID().uuidString
                    
                    let postLocation = CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong)
                    spotInfo.spotScore = self.getSpotRank(spot: spotInfo, location: postLocation)

                    self.nearbyEnteredCount += 1 /// only need to increment here to keep values consistent for the nearby spot access escape
                    UploadImageModel.shared.nearbySpots.append(spotInfo)
                    
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                    
                } else {
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                }
            }
        }
    }

    
    func getNearbySpots() {

        circleQuery = geoFirestore.query(withCenter: GeoPoint(latitude: postObject.postLat, longitude: postObject.postLong), radius: 0.5)
        let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)

        let _ = circleQuery?.observeReady { [weak self] in
            
            guard let self = self else { return }
            self.queryReady = true
            
            if self.nearbyEnteredCount == 0 {
                self.endQuery()
                
            } else if self.noAccessCount + UploadImageModel.shared.nearbySpots.count == self.nearbyEnteredCount {
                self.endQuery()
            }
            
            self.circleQuery?.removeAllObservers()
        }
    }
    
    func loadSpotFromDB(key: String?, location: CLLocation?) {

        if UploadImageModel.shared.nearbySpots.contains(where: {$0.id == key}) { accessEscape(); return }
        guard let spotKey = key else { accessEscape(); return }
        guard let coordinate = location?.coordinate else { accessEscape(); return }
        
        nearbyEnteredCount += 1

        let ref = db.collection("spots").document(spotKey)
         ref.getDocument { [weak self] (doc, err) in
            
            guard let self = self else { return }

            do {
                
                let unwrappedInfo = try doc?.data(as: MapSpot.self)
                guard var spotInfo = unwrappedInfo else { self.noAccessCount += 1; self.accessEscape(); return }

                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                spotInfo.spotDescription = "" /// remove spotdescription, no use for it here, will either be replaced with POI description or username
                                
                if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                    

                    let postLocation = CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong)
                    spotInfo.spotScore = self.getSpotRank(spot: spotInfo, location: postLocation)
                    
                    if spotInfo.privacyLevel != "public" {
                        spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                        
                    } else {
                        spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                    }
                    
                    /// replace POI with actual spot object
                    if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.spotName == spotInfo.spotName || $0.phone == spotInfo.phone ?? ""}) {
                        UploadImageModel.shared.nearbySpots[i] = spotInfo
                        self.noAccessCount += 1; self.accessEscape(); return
                    }
                    
                    UploadImageModel.shared.nearbySpots.append(spotInfo)
                    self.accessEscape()
                    
                } else { self.noAccessCount += 1; self.accessEscape(); return }
            } catch { self.noAccessCount += 1; self.accessEscape(); return }
         }
    }
    
    
    func accessEscape() {
        if noAccessCount + UploadImageModel.shared.nearbySpots.count == nearbyEnteredCount && queryReady { endQuery() }
    }
    
    func endQuery() {
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        reloadChooseSpot(resort: true)
    }
    
    func selectSpot(index: Int, select: Bool, fromMap: Bool) {
        
        /// deselect spot,, select new if applicable
        
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.selected!}) { UploadImageModel.shared.nearbySpots[i].selected = false }
        postObject.spotName = ""
        spotObject = nil
        
        var selectedLocation = CLLocation(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)

        if select {
            UploadImageModel.shared.nearbySpots[index].selected = true
            postObject.spotName = UploadImageModel.shared.nearbySpots[index].spotName
            selectedLocation = CLLocation(latitude: UploadImageModel.shared.nearbySpots[index].spotLat, longitude: UploadImageModel.shared.nearbySpots[index].spotLong)
            spotObject = UploadImageModel.shared.nearbySpots[index]
        }
            
        resetImages(newLocation: selectedLocation)
        sortAndReloadImages(newSelection: false)
        if select { setPostLocation() } 
        reloadChooseSpot(resort: fromMap)
        addPostButton() /// set postButtonAlpha based on if spot selected
    }
    
    func reloadChooseSpot(resort: Bool) {
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let chooseCell = self.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? UploadChooseSpotCell else { return }
            
            /// sort by spotscore the first time through
            if !chooseCell.loaded {
                UploadImageModel.shared.nearbySpots.sort(by: {$0.spotScore > $1.spotScore})
                chooseCell.loaded = true
            }
            
            chooseCell.chooseSpotCollection.performBatchUpdates {
                
                if resort {
                    /// put selected spot first if sorting from map
                
                    for i in 0...UploadImageModel.shared.nearbySpots.count - 1 {
                        let spot = UploadImageModel.shared.nearbySpots[i]
                        UploadImageModel.shared.nearbySpots[i].spotScore = self.getSpotRank(spot: spot, location: CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong))
                    }
                    
                    UploadImageModel.shared.nearbySpots.sort(by: { !$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected! })
                    print(UploadImageModel.shared.nearbySpots.map({$0.spotName}), UploadImageModel.shared.nearbySpots.map({$0.spotScore}))
                    chooseCell.chooseSpotCollection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
                }
                
                chooseCell.chooseSpotCollection.reloadSections(IndexSet(0...0))
            }
            
            self.reloadOverviewDetail()
        }
    }
    
    func resetImages(newLocation: CLLocation) {
        
        scrollObjects.removeAll(where: {!$0.selected && !$0.fromCamera})
        
        var tempObjects = UploadImageModel.shared.imageObjects
        
        /// sort by recency if current location used
        if newLocation.coordinate.latitude == UserDataModel.shared.currentLocation.coordinate.latitude && newLocation.coordinate.longitude == UserDataModel.shared.currentLocation.coordinate.longitude {
        
            /// sort by location if spot location being used
        } else {
            tempObjects.sort(by: { !$0.selected && !$1.selected ? $0.image.rawLocation.distance(from: newLocation) < $1.image.rawLocation.distance(from: newLocation) : !$0.selected && $1.selected })
        }
        
        for object in tempObjects.prefix(5) {
            scrollObjects.append(ScrollObject(imageObject: object.image, selected: false, fromCamera: false))
        }
    }
    
    func presentAddNew() {
        
        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)

        let newView = NewSpotNameView(frame: CGRect(x: 32, y: view.bounds.height/3, width: view.bounds.width - 64, height: 98))
        newView.delegate = self
        maskView.addSubview(newView)
        
        newView.textField.becomeFirstResponder()
    }
    
    func openCamera() {
                
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func openGallery() {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "PhotosContainer") as? PhotosContainerController {
            
            vc.spotObject = spotObject
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited { vc.limited = true }
            
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func pushLocationPicker() {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "LocationPicker") as? LocationPickerController {
            
            vc.passedLocation = CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)
            vc.spotObject = spotObject
            vc.delegate = self
            
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func pushInviteFriends() {
        
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            var friends = UserDataModel.shared.friendsList
            friends.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
                        
            /// add selected friends to show in header, remove from table friendslist
            for obj in UploadImageModel.shared.friendObjects {
                if obj.selected {
                    inviteVC.selectedFriends.append(obj)
                    friends.removeAll(where: {$0.id == obj.id})
                }
            }
            
            inviteVC.friendsList = friends
            inviteVC.queryFriends = friends
            inviteVC.delegate = self
            
            navigationController?.pushViewController(inviteVC, animated: true)
        }
    }
    
    func exitNewSpot() {
        
        postType = .none
        newSpotName = ""
        postObject.spotName = ""
        
        var rows = [IndexPath(row: 1, section: 0)]
        /// reload privacy view if necessary - can only have invite-only for a new spot. for public - want user to be notified that they're submitting
        if postObject.privacyLevel != "friends" { postObject.privacyLevel = "friends"; rows.append(IndexPath(row: 5, section: 0)) }
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: rows, with: .none)
            self.reloadOverviewDetail()
        }
    }
    
    func locationsClose(coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> Bool {
        /// run to ensure that this is actually the same spot and not just one with the same name
        if abs(coordinate1.latitude - coordinate2.latitude) + abs(coordinate1.longitude - coordinate2.longitude) < 0.01 { return true }
        return false
    }
    
    func selectTag(tag: Tag) {
        
        /// reloading entire table resetting collection content offsets so just reloading where needed
        
        postObject.tag = tag.selected ? tag.name : ""
        
        /// reload choose tag to show highlighted tag
        guard let cell = tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadChooseTagCell else { return }
        for i in 0...cell.tags.count - 1 { cell.tags[i].selected = cell.tags[i].name == postObject.tag }
        
        DispatchQueue.main.async {
            cell.chooseTagCollection.reloadSections(IndexSet(0...0))
            self.reloadOverviewDetail()
        }
    }
    
    func selectUser(index: Int) {
        
        UploadImageModel.shared.friendObjects[index].selected = !UploadImageModel.shared.friendObjects[index].selected
        
        let friend = UploadImageModel.shared.friendObjects[index]
        if friend.selected {
            postObject.addedUsers!.append(friend.id!)
            postObject.addedUserProfiles.append(friend)
        } else {
            postObject.addedUsers?.removeAll(where: {$0 == friend.id!})
            postObject.addedUserProfiles.removeAll(where: {$0.id == friend.id})
        }
        
        guard let cell = tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? UploadAddFriendsCell else { return }
        
        DispatchQueue.main.async {
            cell.addFriendsCollection.reloadSections(IndexSet(0...0))
            self.reloadOverviewDetail()
        }
    }
    
    /// reload detail view to show "is ___" + spotName
    func reloadOverviewDetail() {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        if cell.usernameDetail != nil { for sub in cell.usernameDetail.subviews { sub.removeFromSuperview() } }
        if cell.spotLabel != nil { cell.spotLabel.text = "" }
        cell.addDetail(post: postObject)
    }
    
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
    }
    
    func removePreviews() {
        
        for sub in maskView.subviews { sub.removeFromSuperview() }
        maskView.removeFromSuperview()
        
        if previewView != nil { for sub in previewView.subviews { sub.removeFromSuperview()}; previewView.removeFromSuperview(); previewView = nil }
    }
}

// image methods
extension UploadPostController: GIFPreviewDelegate, DraftsDelegate, NewSpotNameDelegate, LocationPickerDelegate, InviteFriendsDelegate {
    
    func finishPassingLocationPicker(spot: MapSpot) {
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.id == spot.id}) { selectSpot(index: i, select: true, fromMap: true) } else {
            UploadImageModel.shared.nearbySpots.append(spot)
            selectSpot(index: UploadImageModel.shared.nearbySpots.count - 1, select: true, fromMap: true)
        }
    }
    
    func finishPassingName(name: String) {
        
        if !UploadImageModel.shared.nearbySpots.isEmpty { UploadImageModel.shared.nearbySpots[0].selected = false } /// set spot in position 0 to not selected
        newSpotName = name
        postObject.spotName = name
        postType = .newSpot
        removePreviews()
        
        DispatchQueue.main.async {
            self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
            self.reloadOverviewDetail()
        }
    }
    
    func finishPassingSelectedFriends(selected: [UserProfile]) {
        
        var addedNewUser = false /// if adding a new user, scroll to row 1 to show the user they were selected
        
        for user in selected {
            
            if user.selected { continue }
            /// select from topFriends if user isn't already selected
            if let i = UploadImageModel.shared.friendObjects.firstIndex(where: {$0.id == user.id}) {
                selectUser(index: i)
                
            ///append new user object
            } else {
                UploadImageModel.shared.friendObjects.insert(user, at: 0)
                selectUser(index: 0)
                addedNewUser = true
            }
        }
        
        /// deselect users that were deselected from search (not contained in selected)
        for i in 0...UploadImageModel.shared.friendObjects.count - 1 {
            let user = UploadImageModel.shared.friendObjects[i]
            if user.selected && !selected.contains(where: {$0.id == user.id}) {
                selectUser(index: i)
            }
        }
        
        if addedNewUser {
            DispatchQueue.main.async {
                guard let cell = self.tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? UploadAddFriendsCell else { return }
                cell.addFriendsCollection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .right, animated: false)
            }
        }
    }

    func finishPassingFromDrafts(images: [UIImage], date: Date, location: CLLocation) {
        let gifMode = images.count > 1
        let object = ScrollObject(imageObject: ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: location, stillImage: images.first ?? UIImage(), animationImages: gifMode ? images : [], gifMode: gifMode, creationDate: date), selected: true, fromCamera: false)
        scrollObjects.append(object)
        
        let index = UploadImageModel.shared.selectedObjects.count
        UploadImageModel.shared.imageObjects.insert((image: object.imageObject, selected: true), at: index)
        UploadImageModel.shared.selectedObjects.append(object.imageObject)
        sortAndReloadImages(newSelection: true)
    }
    
    
    func finishPassingFromCamera(images: [UIImage]) {
        let gifMode = images.count > 1
        let object = ScrollObject(imageObject: ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: UserDataModel.shared.currentLocation, stillImage: images.first ?? UIImage(), animationImages: gifMode ? images : [], gifMode: gifMode, creationDate: Date()), selected: true, fromCamera: true)
        scrollObjects.append(object)
        
        let index = UploadImageModel.shared.selectedObjects.count
        UploadImageModel.shared.imageObjects.insert((image: object.imageObject, selected: true), at: index)
        UploadImageModel.shared.selectedObjects.append(object.imageObject)
        sortAndReloadImages(newSelection: true)
    }
    
    /// not a delegate method because just notifying to check selected images on select tap
    func finishPassingFromGallery() {
        
        /// select/deselect existing  scroll objects from selected images
        for i in 0...scrollObjects.count - 1 {
            scrollObjects[i].selected = UploadImageModel.shared.selectedObjects.contains(where: {$0.id == scrollObjects[i].imageObject.id})
        }
         
        for object in UploadImageModel.shared.selectedObjects {
            
            if !scrollObjects.contains(where: {$0.imageObject.id == object.id}) {
                /// add new scroll objects from selected image
                scrollObjects.append(ScrollObject(imageObject: object, selected: true, fromCamera: false))
            }
        }
        
        sortAndReloadImages(newSelection: true)
    }
    
    func cancelFromGallery() {
        
        let gallerySelectedCount = UploadImageModel.shared.selectedObjects.count
            
        /// reset selectedImages to match up with scroll objects
        UploadImageModel.shared.selectedObjects.removeAll()
        for object in scrollObjects { if object.selected { UploadImageModel.shared.selectedObjects.append(object.imageObject) } }
        
        /// reset imageObjects to match up with scroll objects
        
        /// sort first to get all selected objects in front
        UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected})


        /// deselect imageObjects that werent previously selected
        if gallerySelectedCount > 0 { for i in 0...gallerySelectedCount - 1 {
            if let object = scrollObjects.first(where: {$0.imageObject.id == UploadImageModel.shared.imageObjects[i].image.id}) {
                UploadImageModel.shared.imageObjects[i].selected = object.selected
            }
        } }
        
        sortAndReloadImages(newSelection: false)
    }
    
    func selectImage(index: Int, circleTap: Bool) {
        
        if UploadImageModel.shared.selectedObjects.count > 4 { return } /// show error alert
        guard let selectedObject = scrollObjects[safe: index] else { return }
        
        if selectedObject.imageObject.stillImage != UIImage() {
            
            if !circleTap {
                addPreviewView(object: selectedObject, selectedIndex: 0, galleryIndex: index)
                
            } else {
                Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": true])
                setCircleTapAt(index: index, selected: true)
            }
            
        } else {
            
            guard let overviewCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
            guard let cell = overviewCell.cameraCollection.cellForItem(at: IndexPath(row: index + 1, section: 0)) as? UploadImageCell else { return }
            
            /// this cell is fetching, cancel fetch and return
            if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: index); return  }
            
            if imageFetcher.isFetching { cancelFetchForRowAt(index: imageFetcher.fetchingIndex) } /// another cell is fetching cancel that fetch
            cell.addActivityIndicator()
            
            let asset = scrollObjects[index].imageObject.asset
            if asset.mediaSubtypes.contains(.photoLive) {
                
                imageFetcher.fetchLivePhoto(currentAsset: asset, item: index) { [weak self] animationImages, stillImage, failed in
                    
                    guard let self = self else { return }
                    
                    cell.removeActivityIndicator()
                    
                    if self.cancelOnDismiss { return }
                    if failed { self.showFailedDownloadAlert(); return }
                    if stillImage == UIImage() { return } /// canceled
                    
                    self.scrollObjects[index].imageObject.stillImage = stillImage
                    self.scrollObjects[index].imageObject.animationImages = animationImages
                    self.scrollObjects[index].imageObject.gifMode = true
                    
                    ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                    if UploadImageModel.shared.selectedObjects.count < 5 { circleTap ? self.setCircleTapAt(index: index, selected: true) : self.addPreviewView(object: self.scrollObjects[index], selectedIndex: 0, galleryIndex: index) }
                }
                
            } else {
                
                imageFetcher.fetchImage(currentAsset: asset, item: index, livePhoto: false) { [weak self] stillImage, failed  in
                    
                    guard let self = self else { return }
                    cell.removeActivityIndicator()
                    
                    if self.cancelOnDismiss { return }
                    if failed { self.showFailedDownloadAlert(); return }
                    if stillImage == UIImage() { return } /// canceled
                    
                    self.scrollObjects[index].imageObject.stillImage = stillImage
                    
                    ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                    if UploadImageModel.shared.selectedObjects.count < 5 {
                        /// append new image object with fetched image
                        cell.removeActivityIndicator()
                        
                        if !circleTap {
                            self.addPreviewView(object: self.scrollObjects[index], selectedIndex: 0, galleryIndex: index)
                            
                        } else {
                            Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": true])
                            self.setCircleTapAt(index: index, selected: true)
                        }
                    }
                }
            }
        }
    }
    
    func setCircleTapAt(index: Int, selected: Bool) {
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25) {
                guard let overviewCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
                let increment = selected ? 2 : 1 /// move to the last selected slot (will become first unselected) if deselecting, move to the first unselected if selecting
                let selectedIndexPath = IndexPath(item: (self.scrollObjects.lastIndex(where: {$0.selected}) ?? -1) + increment, section: 0)
                overviewCell.cameraCollection.moveItem(at: IndexPath(item: index + 1, section: 0), to: selectedIndexPath)
                
            } completion: { [weak self] _ in
                
                guard let self = self else { return }
                self.scrollObjects[index].selected = selected
                
                let imageObject = self.scrollObjects[index].imageObject
                UploadImageModel.shared.selectObject(imageObject: imageObject, selected: selected)
                
                self.sortAndReloadImages(newSelection: selected)
            }
        }
        
    }
    
    func sortAndReloadImages(newSelection: Bool) {

        if cancelOnDismiss { return }
        scrollObjects.sort(by: {$0.selected && !$1.selected})
        UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected})
                
        if newSelection { setPostLocation() }
            
        guard let overviewCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        overviewCell.scrollObjects = scrollObjects
        
        DispatchQueue.main.async {
            overviewCell.cameraCollection.performBatchUpdates {
                overviewCell.cameraCollection.reloadSections(IndexSet(0...0)) }
        }
        
        if !newSelection { return } /// scroll to last selected item only if selecting a new cell
        let lastSelectedItem = scrollObjects.lastIndex(where: {$0.selected}) ?? 0
        overviewCell.cameraCollection.scrollToItem(at: IndexPath(item: lastSelectedItem, section: 0), at: .left, animated: true)
    }
    
    func setPostLocation() {
        
        /// update post location, if this is a new post in post #1, re-run choose spot fetch with new location
        let previousLong = postObject.postLong
        var runFetch = false

        if !scrollObjects.isEmpty {
            
            /// default: postLocation = user's current location
            var postLocation = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)

            /// 1. if theres a selected image with location, use that location
            if scrollObjects.first!.selected && scrollObjects.first!.imageObject.rawLocation.coordinate.longitude != 0 && scrollObjects.first!.imageObject.rawLocation.coordinate.latitude != 0 {
                postLocation = scrollObjects.first!.imageObject.rawLocation.coordinate
                
            /// 2. use tapped location from map if applicable
            } else if !locationIsEmpty(location: UploadImageModel.shared.tappedLocation) {
                postLocation = CLLocationCoordinate2D(latitude: UploadImageModel.shared.tappedLocation.coordinate.latitude, longitude: UploadImageModel.shared.tappedLocation.coordinate.longitude)
            }
            
            /// 3. use selected spot location
            else if let spot = UploadImageModel.shared.nearbySpots.first(where: {$0.selected!}) {
                postLocation = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
            }
            
            runFetch = !UploadImageModel.shared.nearbySpots.contains(where: {$0.selected!}) /// only run choose spot fetch if spot not selected
            
            postObject.postLat = postLocation.latitude
            postObject.postLong = postLocation.longitude
            
            print("should run fetch", postObject.postLong, previousLong)
            /// get a new batch of nearby spots if selecting an image
            if runFetch && postObject.postLong != previousLong && !UploadImageModel.shared.nearbySpots.contains(where: {$0.selected!}) { print("run fetch"); runChooseSpotFetch() }
        }

    }
    
    func deselectImage(index: Int, circleTap: Bool) {
        
        if !circleTap {
            guard let object = scrollObjects[safe: index] else { return }
            addPreviewView(object: object, selectedIndex: index + 1, galleryIndex: index)
            /// gallery index reflects position in the scroll, selected index is the # selected which is always the images actual index because sorted by selected
            
        } else {
            Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": false])
            setCircleTapAt(index: index, selected: false)
        }
    }
    
    func cancelFetchForRowAt(index: Int) {
        
        Mixpanel.mainInstance().track(event: "UploadCancelImageFetch")
        
        guard let overviewCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        guard let cell = overviewCell.cameraCollection.cellForItem(at: IndexPath(row: index + 1, section: 0)) as? UploadImageCell else { return }
        
        guard let currentObject = scrollObjects[safe: index] else { return }
        let currentAsset = currentObject.imageObject.asset
        
        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }
    
    func askForGallery(first: Bool) {
        
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { _ in self.askForGallery(first: false) }
            
        case .restricted, .denied:
            
            if first {UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return }

            let alert = UIAlertController(title: "Allow gallery access to upload pictures from your camera roll", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil) }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            

        case .authorized, .limited:
            UploadImageModel.shared.galleryAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            fetchAssets()
            
        default: return
        }
    }
    
    
    
    func showFailedDownloadAlert() {
        let alert = UIAlertController(title: "Unable to download image from iCloud", message: "\n Your iPhone storage may be full", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    func addPreviewView(object: ScrollObject, selectedIndex: Int, galleryIndex: Int) {
        
        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
        
        let width = UIScreen.main.bounds.width - 50
        let pY = UIScreen.main.bounds.height/2 - width * 0.667
        
        previewView = GalleryPreviewView(frame: CGRect(x: 25, y: pY, width: width, height: width * 1.3333))
        previewView.isUserInteractionEnabled = true
        previewView.upload
            = self
        previewView.setUp(object: object.imageObject, selectedIndex: selectedIndex, galleryIndex: galleryIndex)
        maskView.addSubview(previewView)
    }
}


extension UploadPostController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        // only close view on touch outside of textView
        if touch.view!.isKind(of: UITextView.self) { return false }
        
        return true
    }
    
}

extension UploadPostController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadOverview") as? UploadOverviewCell else { return UITableViewCell() }
            cell.setUp(post: postObject, scrollObjects: scrollObjects)
            return cell
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpot") as? UploadChooseSpotCell else { return UITableViewCell() }
            cell.setUp(newSpotName: newSpotName, post: postObject)
            return cell
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseTag") as? UploadChooseTagCell else { return UITableViewCell() }
            cell.setUp()
            return cell
            
        case 3:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "AddFriends") as? UploadAddFriendsCell else { return UITableViewCell() }
            cell.setUp(post: postObject)
            return cell
            
        case 4:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ShowOnFeed") as? UploadShowOnFeedCell else { return UITableViewCell() }
            cell.setUp(hide: postObject.hideFromFeed ?? false)
            return cell
            
        case 5:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Privacy") as? UploadPrivacyCell else { return UITableViewCell() }
            cell.setUp(postPrivacy: postObject.privacyLevel ?? "friends", spotPrivacy: spotObject == nil ? "public" : spotObject.privacyLevel)
            return cell
            
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0: return UserDataModel.shared.screenSize == 0 ? 244 : UserDataModel.shared.screenSize == 1 ? 265 : 337
        case 1: return 96
        case 2: return 141
        case 3: return 84
        default: return 48
        }
    }
}
