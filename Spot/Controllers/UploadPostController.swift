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
import FirebaseFunctions

struct postType {
    
}

class UploadPostController: UIViewController {
    
    var scrollObjects: [ImageObject] = []
    
    unowned var mapVC: MapViewController!
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var passedSpot: MapSpot!
    var spotObject: MapSpot!
    var postObject: MapPost!
    
    var tableView: UITableView!
    var maskView: UIView!
    var previewView: GalleryPreviewView!
    var progressView: UIProgressView!
    
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
    
    var privacyView: UploadPrivacyPicker!
    var showOnFeed: UploadShowOnFeedView!
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCurrentLocation(_:)), name: Notification.Name("UpdateLocation"), object: nil)
        
        
        setUpPost()
        setUpTable()
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
        let alpha: CGFloat = spotObject == nil && newSpotName == "" ? 0.3 : 1.0
        let postImage = UIImage(named: "PostButton")?.alpha(alpha).withRenderingMode(.alwaysOriginal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: postImage, style: .plain, target: self, action: #selector(postTap(_:)))
    }
    
    func setUpPost() {
        /// add currentLocation == nil check
        postObject = MapPost(id: UUID().uuidString, caption: "", postLat: UserDataModel.shared.currentLocation.coordinate.latitude, postLong: UserDataModel.shared.currentLocation.coordinate.longitude, posterID: uid, timestamp: Timestamp(date: Date()), actualTimestamp: Timestamp(date: Date()), userInfo: UserDataModel.shared.userInfo, spotID: spotObject == nil ? UUID().uuidString : spotObject.id, city: "", frameIndexes: [], aspectRatios: [], imageURLs: [], postImage: [], seconds: 0, selectedImageIndex: 0, postScore: 0, commentList: [], likers: [], taggedUsers: [], captionHeight: 0, imageHeight: 0, cellHeight: 0, spotName: spotObject == nil ? "" : spotObject.spotName, spotLat: spotObject == nil ? 0 : spotObject.spotLat, spotLong: spotObject == nil ? 0 : spotObject.spotLong, privacyLevel: spotObject == nil ? "friends" : spotObject.privacyLevel, spotPrivacy: spotObject == nil ? "" : spotObject.privacyLevel, createdBy: spotObject == nil ? uid : spotObject.founderID, inviteList: [], friendsList: [], hideFromFeed: false, gif: false, addedUsers: [], addedUserProfiles: [], tag: "")
        setPostCity()
    }
    
    func setUpTable() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
        (self.navigationController?.navigationBar.frame.height ?? 44.0)
        
        
        tableView = UITableView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight))
        tableView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isUserInteractionEnabled = true
        tableView.allowsSelection = false
        tableView.isScrollEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.register(UploadOverviewCell.self, forCellReuseIdentifier: "UploadOverview")
        tableView.register(UploadChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
        tableView.register(UploadImagesCell.self, forCellReuseIdentifier: "UploadImages")
        tableView.register(UploadPrivacyCell.self, forCellReuseIdentifier: "Privacy")
        view.addSubview(tableView)
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.tag = 5
        let maskTap = UITapGestureRecognizer(target: self, action: #selector(maskTap(_:)))
        maskTap.delegate = self
        maskView.addGestureRecognizer(maskTap)
        maskView.isUserInteractionEnabled = true
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        
        progressView = UIProgressView(frame: CGRect(x: 50, y: UIScreen.main.bounds.height - 160, width: UIScreen.main.bounds.width - 100, height: 15))
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 2.3)
        progressView.layer.cornerRadius = 3
        progressView.layer.sublayers![1].cornerRadius = 3
        progressView.subviews[1].clipsToBounds = true
        progressView.clipsToBounds = true
        progressView.progressTintColor = UIColor(named: "SpotGreen")
        progressView.progress = 0.0
    }
    
    /*
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
    } */
    
    func fetchAssets() {
        if UploadImageModel.shared.galleryAccess != .authorized { askForGallery(first: true) }
        fetchFullAssets()
    }
        
    func fetchFullAssets() {
        
        /// fetch the first 5 assets and show them in the image scroll, fetch next 10000 for gallery/photo map/proximity-to-spot pics
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 10000
        
        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }
        
        let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)

        let indexSet = assetsFull.count > 10000 ? IndexSet(0...9999) : IndexSet(0...assetsFull.count - 1)
        UploadImageModel.shared.assetsFull = assetsFull

        DispatchQueue.global(qos: .default).async { assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, count, stop) in
            
            guard let self = self else { return }
            
            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            let imageObj = (ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], gifMode: false, creationDate: creationDate, fromCamera: false), false)
            UploadImageModel.shared.imageObjects.append(imageObj)
            
            print("ct", UploadImageModel.shared.imageObjects.count)
            if UploadImageModel.shared.imageObjects.count == assetsFull.count {
                
                /// don't sort if photos container already added
                if !(self.navigationController?.viewControllers.contains(where: {$0 is PhotosContainerController}) ?? false) { UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected}) }
                guard let imagesCell = self.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
                imagesCell.setImages()
            }
        }}
    }
    
    @objc func notifyCurrentLocation(_ sender: NSNotification) {
        if postObject.postLat == 0.0 && postObject.postLong == 0.0 {
            postObject.postLat = UserDataModel.shared.currentLocation.coordinate.latitude
            postObject.postLong = UserDataModel.shared.currentLocation.coordinate.longitude
            setPostCity()
        }
    }
    
    @objc func notifyUserLoad(_ sender: NSNotification) {
        
        postObject.userInfo = UserDataModel.shared.userInfo
        
        /// reload for loaded user profile pic
        if tableView != nil { DispatchQueue.main.async { self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none) } }
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
        
        /// remove if no spot selected
        if spotObject == nil && newSpotName.trimmingCharacters(in: .whitespacesAndNewlines) == "" { showError(); return }
        
        /// disable post button
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        if cell.captionView != nil { cell.captionView.resignFirstResponder() }
        mapVC.removeTable()
        
        view.addSubview(maskView)
        
        maskView.addSubview(progressView)
        progressView.setProgress(0.1, animated: true)
        
        /// get post images and frame indexes from selected scrollObjects
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        
        for obj in scrollObjects {
            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height/selectedImages[frameCounter].size.width)
            
            frameCounter += images.count
        }
        
        self.postObject.frameIndexes = frameIndexes
        self.postObject.aspectRatios = aspectRatios
        
        var uploadSpot = self.spotObject
        
        if uploadSpot == nil {
            let adjustedPrivacy = self.postObject.privacyLevel == "public" ? "friends" : self.postObject.privacyLevel /// submit public are friends spots as default until being approved
            self.postObject.privacyLevel = adjustedPrivacy
            uploadSpot = MapSpot(spotDescription: self.postObject.caption, spotName: self.newSpotName, spotLat: self.postObject.postLat, spotLong: self.postObject.postLong, founderID: self.uid, privacyLevel: adjustedPrivacy!, imageURL: self.postObject.imageURLs.first ?? "")
            uploadSpot!.id = UUID().uuidString
            if adjustedPrivacy == "invite" {
                uploadSpot!.inviteList = self.postObject.addedUsers
                uploadSpot!.inviteList!.append(uid)
            }
            
        } else {
            /// poiCategory will be nil for nonPOI
            if uploadSpot!.poiCategory != nil { self.postType = .postToPOI }
        }
        
        /// set post level spot info. spotObject will be nil only for a new spot
        self.postObject.createdBy = uploadSpot!.founderID
        self.postObject.spotID = uploadSpot!.id!
        self.postObject.spotLat = uploadSpot!.spotLat
        self.postObject.spotLong = uploadSpot!.spotLong
        self.postObject.spotPrivacy = uploadSpot!.privacyLevel
        self.postObject.inviteList = uploadSpot!.inviteList ?? []
        
        /// set timestamp to original post date or current date
        let actualTimestamp = self.scrollObjects.first!.creationDate
        
        var taggedProfiles: [UserProfile] = []
        
        ///for tagging users on comment post
        let word = self.postObject.caption.split(separator: " ")
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    self.postObject.taggedUsers!.append(username)
                    self.postObject.taggedUserIDs.append(f.id!)
                    taggedProfiles.append(f)
                }
            }
        }
        
        var postFriends = self.postObject.hideFromFeed! ? [] : self.postObject.privacyLevel == "invite" ? uploadSpot!.inviteList!.filter(UserDataModel.shared.friendIDs.contains) : UserDataModel.shared.friendIDs
        if !postFriends.contains(self.uid) && !self.postObject.hideFromFeed! { postFriends.append(self.uid) }
        self.postObject.friendsList = postFriends
        self.postObject.isFirst = (self.postType == .newSpot || self.postType == .postToPOI)
        
        /// 1. upload post image
        uploadPostImage(selectedImages, postID: postObject.id!, progressView: progressView) { [weak self] (imageURLs, failed) in
            
            guard let self = self else { return }
            if imageURLs.isEmpty && failed {
                self.runFailedUpload(spot: uploadSpot!, post: self.postObject, selectedImages: selectedImages, actualTimestamp: actualTimestamp)
                return
            }
            
            self.postObject.imageURLs = imageURLs
            uploadSpot!.imageURL = imageURLs.first ?? ""
            
            /// 2. set post values, pass post notification to feed and other VC's
            self.uploadPost(post: self.postObject, actualTimestamp: actualTimestamp)
            self.uploadSpot(post: self.postObject, spot: uploadSpot!, postType: self.postType, submitPublic: self.submitPublic)
            self.transitionToMap(postID: self.postObject.id!, spotID: uploadSpot!.id!)
        }
    }
    
    func transitionToMap(postID: String, spotID: String) {
        
        DispatchQueue.main.async {
            
            /// if not transitioning right to spot page prepare for transition
            if (self.postType == .postToSpot && self.mapVC.spotViewController != nil) {
                self.mapVC.spotViewController.newPostReset(tags: [])
                /// go to spot page
            } else {
                self.mapVC.customTabBar.tabBar.isHidden = false
                self.postObject.hideFromFeed! && postID != "" ? self.mapVC.profileUploadReset(spotID: spotID, postID: postID, tags: []) : self.mapVC.feedUploadReset()
            }
            
            self.navigationController?.popViewController(animated: true)
            
        }
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
                    if UploadImageModel.shared.nearbySpots.contains(where: {$0.spotName == name || ($0.phone ?? "" == phone && phone != "")}) { index += 1; if index == response.mapItems.count { self.endQuery() }; continue }
                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    spotInfo.phone = phone
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
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
                    if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                        UploadImageModel.shared.nearbySpots[i] = spotInfo
                        UploadImageModel.shared.nearbySpots[i].poiCategory = nil
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
            postType = postObject.createdBy == "" ? .postToPOI : .postToSpot
            UploadImageModel.shared.nearbySpots[index].selected = true
            postObject.spotName = UploadImageModel.shared.nearbySpots[index].spotName
            selectedLocation = CLLocation(latitude: UploadImageModel.shared.nearbySpots[index].spotLat, longitude: UploadImageModel.shared.nearbySpots[index].spotLong)
            spotObject = UploadImageModel.shared.nearbySpots[index]
        }
        
        let spotPrivacy = spotObject != nil ? spotObject.privacyLevel : submitPublic ? "public" : "friends"
        postObject.privacyLevel = spotPrivacy == "invite" ? "invite" : spotPrivacy == "friends" ? "friends" : postObject.privacyLevel == "invite" ? "friends" : spotPrivacy
        
        resetImages(newLocation: selectedLocation)
        if select { setPostLocation() }
        reloadChooseSpot(resort: fromMap)
        addPostButton() /// set postButtonAlpha based on if spot selected
    }
    
    func reloadChooseSpot(resort: Bool) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
            self.reloadOverviewDetail()

            if self.spotObject != nil || self.newSpotName != "" {
                self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .fade)
                return
            }
                    
            guard let chooseCell = self.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? UploadChooseSpotCell else { return }
            
            /// sort by spotscore the first time through
            if !chooseCell.loaded {
                UploadImageModel.shared.nearbySpots.sort(by: {$0.spotScore > $1.spotScore})
                chooseCell.loaded = true
            }
            
            chooseCell.chooseSpotCollection.performBatchUpdates {
                
                if resort {
                    /// put selected spot first if sorting from map
                    if !UploadImageModel.shared.nearbySpots.isEmpty {
                        for i in 0...UploadImageModel.shared.nearbySpots.count - 1 {
                            let spot = UploadImageModel.shared.nearbySpots[i]
                            UploadImageModel.shared.nearbySpots[i].spotScore = self.getSpotRank(spot: spot, location: CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong))
                            
                        }
                        
                        UploadImageModel.shared.nearbySpots.sort(by: { !$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected! })
                        if chooseCell.chooseSpotCollection.numberOfItems(inSection: 0) > 0 {
                            chooseCell.chooseSpotCollection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: true)
                        }
                    }
                }
                
                chooseCell.chooseSpotCollection.reloadSections(IndexSet(0...0))
            }
        }
    }
    
    func resetImages(newLocation: CLLocation) {
        guard let imagesCell = tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
        imagesCell.sortAndReload(location: newLocation)
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
    
    func presentTagPicker() {
        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
                
        let tagView = UploadChooseTagView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 300, width: UIScreen.main.bounds.width, height: 300))
        tagView.setUp(tag: postObject.tag ?? "")
        tagView.delegate = self
        maskView.addSubview(tagView)
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
            vc.delegate = self
            
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func pushInviteFriends() {
        
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            var friends = UserDataModel.shared.friendsList
            friends.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
            
            /// add selected friends to show in header, remove from table friendslist
            for friend in postObject.addedUserProfiles {
                inviteVC.selectedFriends.append(friend)
                friends.removeAll(where: {$0.id == friend.id})
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
        postObject.privacyLevel = "friends"
        
        DispatchQueue.main.async {
            self.reloadOverviewDetail()
            self.addPostButton()
        }
    }
    
    func locationsClose(coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> Bool {
        /// run to ensure that this is actually the same spot and not just one with the same name
        if abs(coordinate1.latitude - coordinate2.latitude) + abs(coordinate1.longitude - coordinate2.longitude) < 0.01 { return true }
        return false
    }
        
    /// reload detail view to show "is ___" + spotName
    func reloadOverviewDetail() {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        cell.loadDetailView(post: postObject)
    }
    
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
    }
    
    func removePreviews() {
        
        for sub in maskView.subviews { sub.removeFromSuperview() }
        maskView.removeFromSuperview()
        
        if previewView != nil { for sub in previewView.subviews { sub.removeFromSuperview()}; previewView.removeFromSuperview(); previewView = nil }
    }
    
    func runFailedUpload(spot: MapSpot, post: MapPost, selectedImages: [UIImage], actualTimestamp: Date) {
        saveToDrafts(spot: spot, post: post, selectedImages: selectedImages, actualTimestamp: actualTimestamp)
        showFailAlert()
    }
    
    func saveToDrafts(spot: MapSpot, post: MapPost, selectedImages: [UIImage], actualTimestamp: Date) {
        
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else { return }
        
        let managedContext =
        appDelegate.persistentContainer.viewContext
        
        var imageObjects : [ImageModel] = []
        
        var index: Int16 = 0
        for image in selectedImages {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.5)
            im.position = index
            imageObjects.append(im)
            index += 1
        }
        
        var aspectRatios: [Float] = []
        for aspect in post.aspectRatios ?? [] { aspectRatios.append(Float(aspect)) }
        
        switch postType {
            
        case .newSpot, .postToPOI:
            
            let spotObject = SpotDraft(context: managedContext)
            
            spotObject.spotName = spot.spotName
            spotObject.spotDescription = spot.spotDescription
            spotObject.tags = [post.tag ?? ""]
            spotObject.taggedUsernames = post.taggedUsers!
            spotObject.taggedIDs = post.taggedUserIDs
            spotObject.postLat = post.postLat
            spotObject.postLong = post.postLong
            spotObject.spotLat = spot.spotLat
            spotObject.spotLong = spot.spotLong
            spotObject.images = NSSet(array: imageObjects)
            spotObject.spotID = UUID().uuidString
            spotObject.privacyLevel = spot.privacyLevel
            spotObject.inviteList = spot.inviteList ?? []
            spotObject.uid = uid
            spotObject.phone = postType == .postToPOI ? spot.phone : ""
            spotObject.submitPublic = submitPublic
            spotObject.postToPOI = postType == .postToPOI
            spotObject.hideFromFeed = post.hideFromFeed ?? false
            spotObject.frameIndexes = post.frameIndexes
            spotObject.aspectRatios = aspectRatios
            spotObject.gif = post.gif ?? false
            spotObject.friendsList = post.friendsList
            spotObject.city = post.city ?? ""
            
            let timestamp = actualTimestamp.timeIntervalSince1970
            let seconds = Int64(timestamp)
            spotObject.timestamp = seconds
            
        default:
            
            let postObject = PostDraft(context: managedContext)
            postObject.caption = post.caption
            postObject.city = post.city ?? ""
            postObject.createdBy = post.createdBy
            postObject.privacyLevel = post.privacyLevel
            postObject.spotPrivacy = spot.privacyLevel
            postObject.spotID = spot.id!
            postObject.inviteList = spot.inviteList ?? []
            postObject.postLat = post.postLat
            postObject.postLong = post.postLong
            postObject.spotLat = spot.spotLat
            postObject.spotLong = spot.spotLong
            postObject.spotName = spot.spotName
            postObject.taggedUsers = post.taggedUsers
            postObject.taggedUserIDs = post.taggedUserIDs
            postObject.images = NSSet(array: imageObjects)
            postObject.uid = uid
            postObject.isFirst = false
            postObject.visitorList = spot.visitorList
            postObject.hideFromFeed = post.hideFromFeed ?? false
            postObject.frameIndexes = post.frameIndexes ?? []
            postObject.aspectRatios = aspectRatios
            postObject.gif = post.gif ?? false
            postObject.friendsList = post.friendsList
            
            let timestamp = actualTimestamp.timeIntervalSince1970
            let seconds = Int64(timestamp)
            postObject.timestamp = seconds
        }
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func showFailAlert() {
        let alert = UIAlertController(title: "Upload failed", message: "Spot saved to your drafts", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
            case .default:
                self.transitionToMap(postID: "", spotID: "")
            case .cancel:
                self.transitionToMap(postID: "", spotID: "")
            case .destructive:
                self.transitionToMap(postID: "", spotID: "")
            @unknown default:
                fatalError()
            }}))
        present(alert, animated: true, completion: nil)
    }
}

// image methods
extension UploadPostController: GIFPreviewDelegate, DraftsDelegate, NewSpotNameDelegate, LocationPickerDelegate, InviteFriendsDelegate, ChooseTagDelegate, PrivacyPickerDelegate, ShowOnFeedDelegate {
    
    func finishPassingLocationPicker(spot: MapSpot) {
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.id == spot.id}) { selectSpot(index: i, select: true, fromMap: true) } else {
            UploadImageModel.shared.nearbySpots.append(spot)
            selectSpot(index: UploadImageModel.shared.nearbySpots.count - 1, select: true, fromMap: true)
        }
    }
    
    func finishPassingPrivacy(tag: Int) {

        switch tag {
        case 0:
            if postType == .newSpot {
                launchSubmitPublic()
                return
                
            } else {
                postObject.privacyLevel = "public"
                privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", postType: postType)
            }
            
        case 1:
            postObject.privacyLevel = "friends"
            privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", postType: postType)
            
        default:
            postObject.privacyLevel = "invite"
            pushInviteFriends()
        }
    }
    
    func finishPassingVisibility(hide: Bool) {
        postObject.hideFromFeed = hide
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
            self.addPostButton()
        }
    }
    
    func finishPassingTag(tag: Tag) {
        print("select tag")
        postObject.tag = tag.selected ? tag.name : ""
        
        DispatchQueue.main.async {
            self.removePreviews()
            self.reloadOverviewDetail()
        }
    }
    
    func finishPassingSelectedFriends(selected: [UserProfile]) {
        
        postObject.addedUsers = selected.map({$0.id ?? ""})
        postObject.addedUserProfiles = selected
                
        DispatchQueue.main.async {
            self.reloadOverviewDetail()
        }
    }
    
    func finishPassingFromDrafts(images: [UIImage], date: Date, location: CLLocation) {
        /*
        let gifMode = images.count > 1
        let object = ScrollObject(imageObject: ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: location, stillImage: images.first ?? UIImage(), animationImages: gifMode ? images : [], gifMode: gifMode, creationDate: date))
        scrollObjects.append(object)
        
        let index = UploadImageModel.shared.selectedObjects.count
        UploadImageModel.shared.imageObjects.insert((image: object, selected: true), at: index)
        UploadImageModel.shared.selectedObjects.append(object)
        sortAndReloadImages(newSelection: true)
        */
    }
    
    
    func finishPassingFromCamera(images: [UIImage]) {
        
        let gifMode = images.count > 1
        let object = ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: UserDataModel.shared.currentLocation, stillImage: images.first ?? UIImage(), animationImages: gifMode ? images : [], gifMode: gifMode, creationDate: Date(), fromCamera: true)
        scrollObjects.append(object)
        
        let index = UploadImageModel.shared.selectedObjects.count
        UploadImageModel.shared.imageObjects.insert((image: object, selected: true), at: index)
        UploadImageModel.shared.selectedObjects.append(object)
        sortAndReloadImages(newSelection: true, fromGallery: false)
    }
    
    /// not a delegate method because just notifying to check selected images on select tap
    func finishPassingFromGallery() {
        
        scrollObjects.removeAll()
        for object in UploadImageModel.shared.selectedObjects {
            scrollObjects.append(object)
        }
        
        sortAndReloadImages(newSelection: true, fromGallery: true)
    }
    
    func cancelFromGallery() {
        
        /// reset selectedImages and imageObjects
        UploadImageModel.shared.selectedObjects.removeAll()
        while let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.selected}) {
            UploadImageModel.shared.imageObjects[i].selected = false
        }
        
        for object in scrollObjects {
            UploadImageModel.shared.selectedObjects.append(object)
            if let index = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == object.id}) {
                UploadImageModel.shared.imageObjects[index].selected = true
            }
        }
        
        sortAndReloadImages(newSelection: false, fromGallery: true)
    }
    
    func selectImage(cellIndex: Int, galleryIndex: Int, circleTap: Bool) {
        
        if UploadImageModel.shared.selectedObjects.count > 4 { return } /// show error alert
        guard let selectedObject = UploadImageModel.shared.imageObjects[safe: galleryIndex] else { return }
        
        if selectedObject.image.stillImage != UIImage() {
            Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": true])
            setCircleTapAt(index: galleryIndex, selected: true)
            
        } else {
            guard let imagesCell = tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
            guard let cell = imagesCell.imagesCollection.cellForItem(at: IndexPath(row: cellIndex, section: 0)) as? ImagePreviewCell else { return }
            
            /// this cell is fetching, cancel fetch and return
            if cell.activityIndicator.isAnimating { cancelFetchForRowAt(index: cellIndex); return  }
            
            if imageFetcher.isFetching { cancelFetchForRowAt(index: imageFetcher.fetchingIndex) } /// another cell is fetching cancel that fetch
            cell.addActivityIndicator()
            
            let asset = UploadImageModel.shared.imageObjects[galleryIndex].image.asset
            imageFetcher.fetchImage(currentAsset: asset, item: galleryIndex) { [weak self] stillImage, failed  in
                
                guard let self = self else { return }
                cell.removeActivityIndicator()
                
                if self.cancelOnDismiss { return }
                if failed { self.showFailedDownloadAlert(); return }
                if stillImage == UIImage() { return } /// canceled
                
                UploadImageModel.shared.imageObjects[galleryIndex].image.stillImage = stillImage
                
                ///fetch image is async so need to make sure another image wasn't appended while this one was being fetched
                if UploadImageModel.shared.selectedObjects.count < 5 {
                    /// append new image object with fetched image
                    cell.removeActivityIndicator()
                    
                    Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": true])
                    self.setCircleTapAt(index: galleryIndex, selected: true)
                }
            }
        }
    }
    
    func setCircleTapAt(index: Int, selected: Bool) {
        
        /// add/remove image to scroll objects and selected images
        let imageObject = UploadImageModel.shared.imageObjects[index].image
        selected ? scrollObjects.append(imageObject) : scrollObjects.removeAll(where: {$0.asset == imageObject.asset})
        /// update image model
        UploadImageModel.shared.selectObject(imageObject: imageObject, selected: selected)
        /// reload cells 0 & 2
        sortAndReloadImages(newSelection: selected, fromGallery: false)
    }
    
    func sortAndReloadImages(newSelection: Bool, fromGallery: Bool) {
        
        if cancelOnDismiss { return }
       // UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected})
        
        if newSelection { setPostLocation() }
        
        guard let overviewCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        overviewCell.scrollObjects = scrollObjects
        
        guard let imageCell = tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
        imageCell.setImages()

        DispatchQueue.main.async {
                        
            /// if removing or adding the collection, reload everything. otherwise reload the collection
            if (self.scrollObjects.count == 0) || (self.scrollObjects.count == 1 && newSelection) || (fromGallery) {
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
            }
            overviewCell.selectedCollection.performBatchUpdates {
                overviewCell.selectedCollection.reloadSections(IndexSet(0...0))
            } completion: { [weak self] complete in
                guard let self = self else { return }
                /// scroll to selected item if newSelection
                if complete && newSelection { overviewCell.selectedCollection.scrollToItem(at: IndexPath(row: self.scrollObjects.count - 1, section: 0), at: .right, animated: true) }
            }

        }
    }
    
    func setPostLocation() {
        
        /// update post location, if this is a new post in post #1, re-run choose spot fetch with new location
        let previousLong = postObject.postLong
        var runFetch = false
        
        if !scrollObjects.isEmpty {
            
            /// default: postLocation = user's current location
            var postLocation = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)
            
            /// 1. if theres a selected image with location, use that location
            if !scrollObjects.isEmpty && scrollObjects.first!.rawLocation.coordinate.longitude != 0 && scrollObjects.first!.rawLocation.coordinate.latitude != 0 {
                postLocation = scrollObjects.first!.rawLocation.coordinate
                
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
            
            /// get a new batch of nearby spots if selecting an image
            if postObject.postLong != previousLong {
                setPostCity() /// set post city with every location change
                if runFetch { runChooseSpotFetch() }
            }
        }
    }
    
    func setPostCity() {
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)) { [weak self] (city) in
            guard let self = self else { return }
            self.postObject.city = city
        }
    }
    
    func deselectImage(index: Int, circleTap: Bool) {
        Mixpanel.mainInstance().track(event: "UploadCircleTap", properties: ["selected": false])
        setCircleTapAt(index: index, selected: false)
    }
    
    func cancelFetchForRowAt(index: Int) {
        
        Mixpanel.mainInstance().track(event: "UploadCancelImageFetch")
        
        guard let imageCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadImagesCell else { return }
        guard let cell = imageCell.imagesCollection.cellForItem(at: IndexPath(row: index + 1, section: 0)) as? ImagePreviewCell else { return }
        
        guard let currentObject = scrollObjects[safe: index] else { return }
        let currentAsset = currentObject.asset
        
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
    
    func showError() {
        
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        
        let errorText = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorText.lineBreakMode = .byWordWrapping
        errorText.numberOfLines = 0
        errorText.textColor = UIColor.white
        errorText.textAlignment = .center
        errorText.text = "Choose a spot before posting"
        errorText.font = UIFont(name: "SFCamera-Regular", size: 14)!
        errorBox.addSubview(errorText)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            errorBox.removeFromSuperview()
        }
    }
}


extension UploadPostController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        // only close view on touch outside of textView
        if (touch.view!.isKind(of: UploadChooseTagView.self) || touch.view!.isKind(of: UICollectionView.self) || touch.view!.isKind(of: UploadTagCell.self)) { return false }
        if touch.view!.isKind(of: UITextView.self) { return false } /// for keyboard close
        
        return true
    }
    
}

extension UploadPostController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
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
            cell.clipsToBounds = true
            return cell
            
        case 2:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImages") as? UploadImagesCell else { return UITableViewCell() }
            cell.setUp()
            return cell
            
        case 3:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Privacy") as? UploadPrivacyCell else { return UITableViewCell() }
            cell.setUp()
            return cell
            
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
       // case 0: return UserDataModel.shared.screenSize == 0 ? scrollObjects.isEmpty ? 160 : 360 : UserDataModel.shared.screenSize == 1 ? scrollObjects.isEmpty ? 190 : 390 : scrollObjects.isEmpty ? 220 : 420
        case 0: return scrollObjects.isEmpty ? 220 : 420
        case 1: return spotObject == nil && newSpotName == "" ? 96 : 0
        case 2: return 236
        case 3: return 48
        default: return 0
        }
    }
}
