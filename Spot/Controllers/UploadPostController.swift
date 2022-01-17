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

class UploadPostController: UIViewController {
        
    unowned var mapVC: MapViewController!
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var passedSpot: MapSpot!
    var spotObject: MapSpot!
    var postObject: MapPost!
    
    var mapView: MKMapView!
    var mapGradient: CAGradientLayer!
    var gradientContainer: UIView!
    var uploadTable: UITableView!
    var maskView: UIView!
    var progressBar: UIView!
    var progressFill: UIView!
    var newView: NewSpotNameView!
    
    var searchContainer: UIView!
    var exitButton: UIButton!
    var chooseLabel: UILabel!
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var searchIndicator: CustomActivityIndicator!
    var newSpotButton: UIButton!
    
    lazy var searchTextGlobal = ""
    lazy var searchRefreshCount = 0
    lazy var querySpots: [MapSpot] = []

    var resultsTable: UITableView!
    var nearbyTable: UITableView!
    
    var tapToClose: UITapGestureRecognizer!
    var navBarHeight: CGFloat!
    
    lazy var imageFetcher = ImageFetcher()
    var setUp = false /// whether to delay nav bar set up or not
    var cancelOnDismiss = false /// cancel downloads
    var transitioningToMap = false /// cancels bobbing pin animation on upload
    var chooseSpotMode = false /// true when upload table is collapsed
    
    var newSpotName = ""
    var newSpotID = ""
    
    var circleQuery: GFSCircleQuery?
    var search: MKLocalSearch!
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]
    
    var queryReady = true
    var fetchImmediately = true /// initial load + new spot selection, dont run choose spot fetch on delay
    var shouldUpdateRegion = true /// used on updateVisibleRegion, rerun spot/poi fetch when true
    var shouldCluster = true /// de-cluster variable on zoom in
    
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyRefreshCount = 0
    var appendCount = 0
    
    var postType: PostType = .none
    var submitPublic = false
    var privacyCloseTap: UITapGestureRecognizer!
    
    var privacyView: UploadPrivacyPicker!
    var showOnFeed: UploadShowOnFeedView!
    var privacyMask: UIView!
    
    var postAnnotation = CustomPointAnnotation()
    var nearbyAnnotations = [String: CustomSpotAnnotation]()
    var shadowAnnotation: UIImageView! /// replace post annotation with this on transition
    
    var spotDraft: SpotDraft!
    var postDraft: PostDraft!
        
    enum PostType {
        case none
        case postToPOI
        case postToSpot
        case newSpot
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        Mixpanel.mainInstance().track(event: "UploadPostOpen")
        
        spotObject = passedSpot
        
        tapToClose = UITapGestureRecognizer(target: self, action: #selector(closeKeyboard(_:)))
        tapToClose.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name("InitialUserLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name("InitialFriendsLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCurrentLocation(_:)), name: Notification.Name("UpdateLocation"), object: nil)
                
        addMapView() /// add map and gradient
        setUpPost() /// set beginning postObject
        setUpTable() /// add uploadTable and maskView
        addSearch() /// add search, search container, nearby + results tables
        addProgressBar() /// add progress bar + fill
        fetchAssets() /// fetch image assets and reload
        getTopFriends() /// top friends to show in friend picker
        getFailedUploads() /// show pop up if failed uploads available
        
        if spotObject != nil {
            addSpotAnno(spot: spotObject)
            postType = .postToSpot
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardClosed(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        cancelOnDismiss = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let delay: DispatchTime = !setUp ? .now() + 0.2 : .now()
        DispatchQueue.main.asyncAfter(deadline: delay) { [weak self] in
            guard let self = self else { return }
            self.setUpNavBar()
            self.setUp = true
            
            UIView.animate(withDuration: 0.15) {
                self.navigationController?.navigationBar.alpha = 1.0
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        if isMovingFromParent {
            cancelOnDismiss = true
            circleQuery?.removeAllObservers() /// was causing strong reference so put here instead of deinit
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("InitialUserLoad"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("UpdateLocation"), object: nil)
        UploadImageModel.shared.destroy()
    }
    
    func setUpNavBar() {
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
        navigationItem.titleView = nil
        
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTap(_:)))
        cancelButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "SFCompactText-Regular", size: 14.5) as Any, NSAttributedString.Key.foregroundColor: UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1) as Any], for: .normal)
        navigationItem.leftBarButtonItem = cancelButton
        
        addPostButton()
    }
    
    func addPostButton() {
        /// call on set up and spot select to set alpha
        let alpha: CGFloat = spotObject == nil && newSpotName == "" ? 0.3 : 1.0
        let postImage = UIImage(named: "PostButton")?.alpha(alpha).withRenderingMode(.alwaysOriginal)
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: postImage, style: .plain, target: self, action: #selector(postTap(_:)))
    }
    
    func setUpPost() {
        let coordinate = spotObject == nil ? UserDataModel.shared.currentLocation.coordinate : CLLocationCoordinate2D(latitude: spotObject.spotLat, longitude: spotObject.spotLong)
        postObject = MapPost(id: UUID().uuidString, caption: "", postLat: coordinate.latitude, postLong: coordinate.longitude, posterID: uid, timestamp: Timestamp(date: Date()), actualTimestamp: Timestamp(date: Date()), userInfo: UserDataModel.shared.userInfo, spotID: spotObject == nil ? UUID().uuidString : spotObject.id, city: "", frameIndexes: [], aspectRatios: [], imageURLs: [], postImage: [], seconds: 0, selectedImageIndex: 0, postScore: 0, commentList: [], likers: [], taggedUsers: [], imageHeight: 0, captionHeight: 0, cellHeight: 0, spotName: spotObject == nil ? "" : spotObject.spotName, spotLat: spotObject == nil ? 0 : spotObject.spotLat, spotLong: spotObject == nil ? 0 : spotObject.spotLong, privacyLevel: spotObject == nil ? "friends" : spotObject.privacyLevel, spotPrivacy: spotObject == nil ? "" : spotObject.privacyLevel, createdBy: spotObject == nil ? uid : spotObject.founderID, inviteList: [], friendsList: [], hideFromFeed: false, gif: false, addedUsers: [], addedUserProfiles: [], tag: "")
        setPostCity() /// set with every location change to avoid async lag on upload
        
        if coordinate.longitude != 0.0 || coordinate.latitude != 0.0 {
            setPostAnnotation(first: true, animated: false)
        }
    }
    
    func addMapView() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
        (self.navigationController?.navigationBar.frame.height ?? 44.0)
        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1.00)
        
        mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300))
        mapView.isUserInteractionEnabled = true
        mapView.userLocation.title = ""
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = false
        mapView.userLocation.title = ""
        mapView.tintColor = .systemBlue
        mapView.register(UploadAnnotationView.self, forAnnotationViewWithReuseIdentifier: "Upload")
        self.view.addSubview(self.mapView)

        mapView.delegate = self
        
        let gradientAdjust: CGFloat = UserDataModel.shared.smallScreen ? 10 : -10

        gradientContainer = UIView(frame: CGRect(x: mapView.frame.minX - 35, y: -(150 + gradientAdjust), width: mapView.frame.width + 70, height: navBarHeight + 45.5 + 150 + gradientAdjust)) /// gradient container starts 100 px before
        gradientContainer.backgroundColor = nil
        gradientContainer.isUserInteractionEnabled = false
        mapView.addSubview(gradientContainer)
        
        mapGradient = CAGradientLayer()
        mapGradient.type = .radial
        mapGradient.frame = gradientContainer.bounds
        mapGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        mapGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        mapGradient.colors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.2).cgColor, UIColor.black.withAlphaComponent(0.35).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor, UIColor.black.withAlphaComponent(0.7).cgColor, UIColor.black.withAlphaComponent(0.85).cgColor]
        mapGradient.locations = [0.0, 0.45, 0.6, 0.7, 0.8, 1.0]
        gradientContainer.layer.addSublayer(mapGradient)

        /// map tap will allow user to set the location of the post by tapping the map
        let mapTap = UITapGestureRecognizer(target: self, action: #selector(mapTap(_:)))
        mapTap.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(mapTap)
    }
    
    func addProgressBar() {
        progressBar = UIView(frame: CGRect(x: 50, y: UIScreen.main.bounds.height - 150, width: UIScreen.main.bounds.width - 100, height: 18))
        progressBar.backgroundColor = UIColor(named: "SpotGreen")?.withAlphaComponent(0.22)
        progressBar.layer.cornerRadius = 6
        progressBar.layer.borderWidth = 2
        progressBar.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        progressBar.isHidden = true
        view.addSubview(progressBar)
        
        progressFill = UIView(frame: CGRect(x: 1, y: 1, width: 0, height: 16))
        progressFill.backgroundColor = UIColor(named: "SpotGreen")
        progressFill.layer.cornerRadius = 6
        progressBar.addSubview(progressFill)
    }
    
    func setUpTable() {

        var minY: CGFloat = navBarHeight
        minY += UserDataModel.shared.smallScreen ? 30 : UserDataModel.shared.screenSize == 1 ? 50 : 80
        uploadTable = UITableView(frame: CGRect(x: 0, y: navBarHeight + 45, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight - 45))
        uploadTable.backgroundColor = .clear
        uploadTable.separatorStyle = .none
        uploadTable.delegate = self
        uploadTable.dataSource = self
        uploadTable.isUserInteractionEnabled = true
        uploadTable.allowsSelection = false
        uploadTable.isScrollEnabled = false
        uploadTable.showsVerticalScrollIndicator = false
        uploadTable.tag = 0
        uploadTable.register(UploadOverviewCell.self, forCellReuseIdentifier: "UploadOverview")
        uploadTable.register(UploadChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
        uploadTable.register(UploadImagesCell.self, forCellReuseIdentifier: "UploadImages")
        uploadTable.register(UploadPrivacyCell.self, forCellReuseIdentifier: "Privacy")
        view.addSubview(uploadTable)
        uploadTable.reloadData()
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.tag = 5
        let maskTap = UITapGestureRecognizer(target: self, action: #selector(maskTap(_:)))
        maskTap.delegate = self
        maskView.addGestureRecognizer(maskTap)
        maskView.isUserInteractionEnabled = true
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
    }
    
    func addSearch() {
        
        searchContainer = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight - 150))
        searchContainer.backgroundColor = UIColor(named: "SpotBlack")
        searchContainer.layer.cornerRadius = 8
        searchContainer.layer.cornerCurve = .continuous
        view.addSubview(searchContainer)
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 95))
        searchBarContainer.backgroundColor = nil
        searchBarContainer.layer.cornerRadius = 8
        searchBarContainer.layer.cornerCurve = .continuous
        searchContainer.addSubview(searchBarContainer)
        
        chooseLabel = UILabel(frame: CGRect(x: 16, y: 13, width: 200, height: 20))
        chooseLabel.text = "Choose a spot"
        chooseLabel.font = UIFont(name: "SFCompactText-Bold", size: 17)
        chooseLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        searchContainer.addSubview(chooseLabel)
        
        exitButton = UIButton(frame: CGRect(x: searchContainer.bounds.width - 51, y: 8, width: 43, height: 43))
        exitButton.setImage(UIImage(named: "ChooseSpotExit"), for: .normal)
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exitButton.addTarget(self, action: #selector(exitTap(_:)), for: .touchUpInside)
        searchBarContainer.addSubview(exitButton)

        searchBar = UISearchBar(frame: CGRect(x: 12, y: 46, width: UIScreen.main.bounds.width - 130, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.tintColor = .white
        searchBar.barTintColor = UIColor(red: 0.098, green: 0.098, blue: 0.098, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.098, green: 0.098, blue: 0.098, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = " Find spot"
        searchBar.searchTextField.font = UIFont(name: "SFCompactText-Regular", size: 15)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 70, y: 27, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1), for: .normal)
        cancelButton.alpha = 0.8
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactText-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
            
        /// calculate height for post-animation
        let height: CGFloat = UIScreen.main.bounds.height - navBarHeight - 150
        nearbyTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY, width: UIScreen.main.bounds.width, height: height))
        nearbyTable.backgroundColor = .black
        nearbyTable.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 150, right: 0)
        nearbyTable.showsVerticalScrollIndicator = false
        nearbyTable.separatorStyle = .none
        nearbyTable.dataSource = self
        nearbyTable.delegate = self
        nearbyTable.tag = 1
        nearbyTable.register(LocationPickerSpotCell.self, forCellReuseIdentifier: "ChooseSpotCell")
        self.searchContainer.addSubview(self.nearbyTable)
        
        /// bottom of nearby table - content inset
        newSpotButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 118, y: nearbyTable.frame.height - 98, width: 101, height: 58))
        newSpotButton.backgroundColor = nil
        newSpotButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        newSpotButton.setImage(UIImage(named: "ChooseSpotNew"), for: .normal)
        newSpotButton.addTarget(self, action: #selector(newSpotTap(_:)), for: .touchUpInside)
        searchContainer.addSubview(newSpotButton)
        
        /// results table unhidden when search bar is interacted with - update with keyboard height
        resultsTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY - 15, width: UIScreen.main.bounds.width, height: 400))
        resultsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.backgroundColor = .black
        resultsTable.separatorStyle = .none
        resultsTable.showsVerticalScrollIndicator = false
        resultsTable.isHidden = true
        resultsTable.register(LocationPickerSpotCell.self, forCellReuseIdentifier: "ChooseSpotCell")
        resultsTable.tag = 2
        
        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
        searchContainer.addSubview(resultsTable)
    }
    
    func getTopFriends() {
        
        UploadImageModel.shared.friendObjects.removeAll()
        
        // kind of messy
        var sortedFriends = UserDataModel.shared.userInfo.topFriends.sorted(by: {$0.value > $1.value})
        sortedFriends.removeAll(where: {$0.value < 1})
        let topFriends = Array(sortedFriends.map({$0.key}))
        
        for friend in topFriends {
            /// add any friends not in top friends
            if let object = UserDataModel.shared.friendsList.first(where: {$0.id == friend}) {
                UploadImageModel.shared.friendObjects.append(object)
            }
        }
    }
    
    func fetchAssets() {
        
        if UploadImageModel.shared.galleryAccess == .authorized || UploadImageModel.shared.galleryAccess == .limited {
            fetchFullAssets()
            
        } else {
            askForGallery(first: true)
        }
    }
        
    func fetchFullAssets() {
        
        /// fetch the first 50 assets and show them in the image scroll, fetch next 10000 for gallery/photo map/proximity-to-spot pics
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
            if self.cancelOnDismiss { stop.pointee = true }

            var location = CLLocation()
            if let l = object.location { location = l }
            
            var creationDate = Date()
            if let d = object.creationDate { creationDate = d }
            
            let imageObj = (ImageObject(id: UUID().uuidString, asset: object, rawLocation: location, stillImage: UIImage(), animationImages: [], animationIndex: 0, directionUp: true, gifMode: false, creationDate: creationDate, fromCamera: false), false)
            UploadImageModel.shared.imageObjects.append(imageObj)
            
            /// immediate load to show top images in scroll then reload full assets
            let firstLoad = UploadImageModel.shared.imageObjects.count == 50
            let finalLoad = UploadImageModel.shared.imageObjects.count == assetsFull.count
            
            if firstLoad || finalLoad {
                /// don't sort if photos container already added
                if !(self.navigationController?.viewControllers.contains(where: {$0 is PhotosContainerController}) ?? false) { UploadImageModel.shared.imageObjects.sort(by: {!$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected}) }

                DispatchQueue.main.async {
                    guard let imagesCell = self.uploadTable.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
                    imagesCell.setImages(reload: !firstLoad)
                }
            }
        }}
    }
    
    @objc func notifyCurrentLocation(_ sender: NSNotification) {
        /// if user location not set by location manager before  initial open
        if postObject.postLat == 0.0 && postObject.postLong == 0.0 {
            let coordinate = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)
            postObject.postLat = coordinate.latitude
            postObject.postLong = coordinate.longitude
            
            setPostCity()
            setPostAnnotation(first: true, animated: false)
            mapView.addAnnotation(postAnnotation)
        }
    }
    
    @objc func notifyUserLoad(_ sender: NSNotification) {
        
        postObject.userInfo = UserDataModel.shared.userInfo
        
        /// reload for loaded user profile pic
        if uploadTable != nil { DispatchQueue.main.async { self.uploadTable.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none) } }
    }
    
    @objc func notifyFriendsLoad(_ sender: NSNotification) {
        getTopFriends()
    }
        
    @objc func tagSelect(_ sender: NSNotification) {
        
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let username = infoPass["username"] as? String else { return }
        guard let tag = infoPass["tag"] as? Int else { return }
        if tag != 2 { return } /// tag 2 for upload tag. This notification should only come through if tag = 2 because upload will always be topmost VC
        guard let uploadOverviewCell = uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        
        let cursorPosition = uploadOverviewCell.captionView.getCursorPosition()
        let tagText = addTaggedUserTo(text: postObject.caption, username: username, cursorPosition: cursorPosition)
        postObject.caption = tagText
        uploadOverviewCell.captionView.text = tagText
    }
    
    @objc func keyboardClosed(_ sender: NSNotification) {
        if newView != nil { removePreviews(); newView = nil }
    }
    
    @objc func closeKeyboard(_ sender: UITapGestureRecognizer) {
        /// called on tap of background on newSpotName
        closeKeyboard()
    }
    
    func closeKeyboard() {
        guard let cell = uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
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
        if spotObject == nil && newSpotName.trimmingCharacters(in: .whitespacesAndNewlines) == "" { showError(message: "Choose a spot before posting"); return }
        
        /// get post images and frame indexes from selected scrollObjects
        var selectedImages: [UIImage] = []
        var frameCounter = 0
        var frameIndexes: [Int] = []
        var aspectRatios: [CGFloat] = []
        var imageLocations: [[String: Any]] = []

        let postLocation = CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)
        
        for obj in UploadImageModel.shared.scrollObjects {
            let images = obj.gifMode ? obj.animationImages : [obj.stillImage]
            selectedImages.append(contentsOf: images)
            frameIndexes.append(frameCounter)
            aspectRatios.append(selectedImages[frameCounter].size.height/selectedImages[frameCounter].size.width)
            
            let location = locationIsEmpty(location: obj.rawLocation) ? postLocation : obj.rawLocation
            imageLocations.append(["lat": location.coordinate.latitude, "long": location.coordinate.longitude])
            
            frameCounter += images.count
        }
        
        postObject.frameIndexes = frameIndexes
        postObject.aspectRatios = aspectRatios
        postObject.postImage = selectedImages
        postObject.imageLocations = imageLocations
        
        let actualTimestamp = UploadImageModel.shared.scrollObjects.first?.creationDate ?? Date()
        postObject.actualTimestamp = Timestamp(date: actualTimestamp)
        
        if spotObject == nil {
            let adjustedPrivacy = self.postObject.privacyLevel == "public" ? "friends" : self.postObject.privacyLevel /// submit public are friends spots as default until being approved
            self.postObject.privacyLevel = adjustedPrivacy
            spotObject = MapSpot(spotDescription: self.postObject.caption, spotName: self.newSpotName, spotLat: self.postObject.postLat, spotLong: self.postObject.postLong, founderID: self.uid, privacyLevel: adjustedPrivacy!, imageURL: self.postObject.imageURLs.first ?? "")
            spotObject.id = UUID().uuidString
            if adjustedPrivacy == "invite" {
                spotObject.inviteList = self.postObject.addedUsers
                spotObject.inviteList!.append(uid)
            }
            
        }
        
        /// set post level spot info. spotObject will be nil only for a new spot
        postObject.createdBy = spotObject.founderID
        postObject.spotID = spotObject.id!
        postObject.spotLat = spotObject.spotLat
        postObject.spotLong = spotObject.spotLong
        postObject.spotPrivacy = spotObject.privacyLevel
        postObject.inviteList = spotObject.inviteList ?? []
        
        /// set timestamp to original post date or current date
        var taggedProfiles: [UserProfile] = []
        
        ///for tagging users on comment post
        let word = postObject.caption.split(separator: " ")
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    postObject.taggedUsers!.append(username)
                    postObject.taggedUserIDs.append(f.id!)
                    taggedProfiles.append(f)
                }
            }
        }
        
        var postFriends = postObject.hideFromFeed! ? [] : postObject.privacyLevel == "invite" ? spotObject.inviteList!.filter(UserDataModel.shared.friendIDs.contains) : UserDataModel.shared.friendIDs
        if !postFriends.contains(uid) && !postObject.hideFromFeed! { postFriends.append(uid) }
        postObject.friendsList = postFriends
        postObject.isFirst = (postType == .newSpot || postType == .postToPOI)
        runFailedUpload(spot: spotObject, post: postObject, selectedImages: selectedImages, actualTimestamp: actualTimestamp)
       // uploadPost()
    }
    
    func uploadPost() {
        
        /// disable post button
        navigationItem.rightBarButtonItem? = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        navigationItem.leftBarButtonItem? = UIBarButtonItem(image: UIImage(), style: .plain, target: nil, action: nil)
        
        guard let cell = uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        if cell.captionView != nil { cell.captionView.resignFirstResponder() }
        mapVC.removeTable()
                
        cancelOnDismiss = true /// stop all other methods
        DispatchQueue.main.async { self.animateIntoMapview() }
        
        /// 1. upload post image
        DispatchQueue.global(qos: .userInitiated).async {
            
            self.uploadPostImage(self.postObject.postImage, postID: self.postObject.id!, progressFill: self.progressFill) { [weak self] (imageURLs, failed) in
                
                guard let self = self else { return }
                
                if imageURLs.isEmpty && failed {
                    self.runFailedUpload(spot: self.spotObject!, post: self.postObject, selectedImages: self.postObject.postImage, actualTimestamp: self.postObject.actualTimestamp!.dateValue())
                    return
                }
                
                self.postObject.imageURLs = imageURLs
                self.spotObject.imageURL = imageURLs.first ?? ""
                
                Mixpanel.mainInstance().track(event: "UploadPostSuccessful", properties: nil)
                
                /// 2. set post values, pass post notification to feed and other VC's
                self.uploadPost(post: self.postObject)
                self.uploadSpot(post: self.postObject, spot: self.spotObject, postType: self.postType, submitPublic: self.submitPublic)
                DispatchQueue.main.async { self.transitionAnnotations() }
            }
        }
    }
    
    func animateIntoMapview() {
        
        /// remove spot annotation for upload animation
        if let spotAnnotation = mapView.annotations.first(where: {$0.isKind(of: CustomSpotAnnotation.self)}) {
            mapView.removeAnnotation(spotAnnotation)
        }
        
        /// add uiimageview in place of annotation for easier animations
        shadowAnnotation = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 33, y: UIScreen.main.bounds.height/2 - 150, width: 70, height: 70))
        shadowAnnotation.contentMode = .scaleAspectFill
        shadowAnnotation.image = loadUploadDown().asImage()
        mapView.addSubview(shadowAnnotation)
        mapView.removeAnnotation(postAnnotation)
        
        let coordinate = CLLocationCoordinate2D(latitude: postObject.postLat, longitude: postObject.postLong)
        let adjustedCenter = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.00065, longitude: coordinate.longitude)
        let camera = MKMapCamera(lookingAtCenter: adjustedCenter, fromDistance: 300, pitch: 0, heading: 0)
        mapView.setCamera(camera, animated: false)

        progressBar.isHidden = false
        
        addTempGradient(hide: true)
        UIView.animate(withDuration: 0.15) { self.gradientContainer.alpha = 0.0 }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.progressFill.frame = CGRect(x: self.progressFill.frame.minX, y: self.progressFill.frame.minY, width: (UIScreen.main.bounds.width - 100) * 0.1, height: self.progressFill.frame.height)
            self.mapView.frame = CGRect(x: self.mapView.frame.minX, y: self.mapView.frame.minY, width: self.mapView.frame.width, height: UIScreen.main.bounds.height)
            self.uploadTable.frame = CGRect(x: self.uploadTable.frame.minX, y: UIScreen.main.bounds.height, width: self.uploadTable.frame.width, height: self.uploadTable.frame.height)
            self.nearbyTable.frame = CGRect(x: self.nearbyTable.frame.minX, y: UIScreen.main.bounds.height, width: self.nearbyTable.frame.width, height: self.nearbyTable.frame.height)
        })
    }
    
    func transitionAnnotations() {
        
        /// 0 = up, 1 = middle, 2 = down
        let upload1 = loadUploadMiddle().asImage()
        let upload2 = loadUploadUp().asImage()
        
        let post0 = loadPostUp().asImage()
        let post1 = loadPostMiddle().asImage()
        let post2 = loadPostDown().asImage()
        
        UIView.transition(with: self.shadowAnnotation, duration: 0.1, options: [.transitionCrossDissolve, .curveEaseIn]) {
            self.shadowAnnotation.image = upload1
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            UIView.transition(with: self.shadowAnnotation, duration: 0.1, options: [.transitionCrossDissolve, .curveLinear, .beginFromCurrentState]) {
                self.shadowAnnotation.image = upload2
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIView.transition(with: self.shadowAnnotation, duration: 0.3, options: [.transitionFlipFromLeft, .beginFromCurrentState, .curveEaseIn]) {
                self.shadowAnnotation.image = post0
                
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            UIView.transition(with: self.shadowAnnotation, duration: 0.08, options: [.transitionCrossDissolve, .beginFromCurrentState, .curveLinear]) {
                self.shadowAnnotation.image = post1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.transition(with: self.shadowAnnotation, duration: 0.08, options: [.transitionCrossDissolve, .beginFromCurrentState, .curveEaseOut], animations: {
                self.shadowAnnotation.image = post2
                
            }, completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self = self else { return }
                    self.deletePostDraft(timestampID: self.postObject.actualTimestamp!.seconds, upload: true)
                    self.transitionToMap(postID: self.postObject.id!, spotID: self.spotObject.id!)
                }
            })
        }
    }
    
    func transitionToMap(postID: String, spotID: String) {
        
        let fromSpot = mapVC.spotViewController != nil
        fromSpot ? mapVC.spotViewController.newPostReset(tags: []) : postObject.hideFromFeed! && postID != "" ? mapVC.profileUploadReset(spotID: spotID, postID: postID, tags: []) : mapVC.feedUploadReset()

        DispatchQueue.main.async { self.popToMap() }
    }
        
    func popToMap() {
        
        let fromSpot = mapVC.spotViewController != nil
      ///  mapVC.customTabBar.tabBar.isHidden = fromSpot
        
        let transition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.push
        transition.subtype = CATransitionSubtype.fromBottom
        
        DispatchQueue.main.async {
            self.navigationController?.view.layer.add(transition, forKey:kCATransition)
            self.navigationController?.popViewController(animated: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            fromSpot ? self.mapVC.spotViewController.uploadReset() : self.mapVC.uploadMapReset()
        }
    }
    
    func runChooseSpotFetch() {
        /// called initially and also after an image is selected
        queryReady = false
        nearbyEnteredCount = 0 /// total number of spots in the circle query
        noAccessCount = 0 /// no privacy access ct
        appendCount = 0 /// spots appended on this fetch
        nearbyRefreshCount = 0 /// incremented once with POI load, once with Spot load
        if fetchImmediately { showSpotLoadingState() } /// show loading state if resetting post location
        
        getNearbySpots()
        getNearbyPOIs()
    }
    
    func showSpotLoadingState() {
        /// show empty row during fetch to account for lag beteen location change/spot fetch
        if newSpotName != "" || spotObject != nil { return }
        if let spotCell = uploadTable.cellForRow(at: IndexPath(row: 1, section: 0)) as? UploadChooseSpotCell {
            DispatchQueue.main.async {
                spotCell.loading = true
                spotCell.chooseSpotCollection.reloadData()
            }
        }
    }
    
    func getNearbyPOIs() {
        
        if search != nil { search.cancel() }
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
            if self.cancelOnDismiss { return }
            
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
                    
                    let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                    let postLocation = CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong)
                    
                    spotInfo.distance = postLocation.distance(from: spotLocation)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                    
                    UploadImageModel.shared.nearbySpots.append(spotInfo)
                    
                    /// add spot annotation
                    let annotation = CustomSpotAnnotation()
                    annotation.coordinate = spotLocation.coordinate
                    annotation.rank = 0.01
                    annotation.spotInfo = spotInfo
                    annotation.isHidden = true
                    
                    self.nearbyAnnotations.updateValue(annotation, forKey: spotInfo.id!)
                    
                    if !self.spotFilteredByLocation(mapCoordinates: self.mapView.region.boundingBoxCoordinates, spotCoordinates: spotLocation.coordinate) && self.spotObject == nil && self.newSpotName == "" {
                        self.nearbyAnnotations[spotInfo.id!]?.isHidden = false
                        DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
                    }
                    
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                    
                } else {
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                }
            }
        }
    }
    
    
    func getNearbySpots() {
        
        let radius = self.mapView.currentRadius()
        if locationIsEmpty(location: UserDataModel.shared.currentLocation) || radius == 0 || radius > 6000 { return }

        let fetchRadius: CLLocationDistance = min(max(mapView.currentRadius(), 0.5), 100.0)
        if circleQuery == nil {
            /// radius between 0.5 and 100.0
            circleQuery = geoFirestore.query(withCenter: GeoPoint(latitude: postObject.postLat, longitude: postObject.postLong), radius: fetchRadius)
            let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)
        
        } else {
            /// active listener will account for change
            circleQuery?.center = self.mapView.centerCoordinate.location
            circleQuery?.radius = fetchRadius
            return
        }

        let _ = circleQuery?.observeReady { [weak self] in

            guard let self = self else { return }
            if self.cancelOnDismiss { return }

            self.queryReady = true
            
            /// observe ready is sometimes called after all spots loaded, sometimes before due to async nature. Reload here if no spots entered or load is finished
            if self.nearbyEnteredCount == 0 {
                self.endQuery()
                
            } else if self.noAccessCount + self.appendCount == self.nearbyEnteredCount {
                self.endQuery()
            }
        }
    }
    
    func loadSpotFromDB(key: String?, location: CLLocation?) {
        
        // 1. check that marker isn't already shown on map
        guard let spotKey = key else { accessEscape(); return }
        guard let coordinate = location?.coordinate else { accessEscape(); return }
                
        if self.nearbyAnnotations.contains(where: {$0.key == key}) { accessEscape(); return }
        nearbyEnteredCount += 1

        let ref = db.collection("spots").document(spotKey)
        ref.getDocument { [weak self] (doc, err) in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { return }
            
            do {
                
                let unwrappedInfo = try doc?.data(as: MapSpot.self)
                guard var spotInfo = unwrappedInfo else { self.noAccessCount += 1; self.accessEscape(); return }
                spotInfo.id = ref.documentID
                
                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                spotInfo.spotDescription = "" /// remove spotdescription, no use for it here, will either be replaced with POI description or username
                
                if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                    
                    let postLocation = CLLocation(latitude: self.postObject.postLat, longitude: self.postObject.postLong)
                    let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)

                    spotInfo.distance = spotLocation.distance(from: postLocation)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                    
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
                    
                    self.appendCount += 1
                    UploadImageModel.shared.nearbySpots.append(spotInfo)
                    self.accessEscape()
                    
                    /// add spot to map
                    let annotation = CustomSpotAnnotation()
                    annotation.coordinate = coordinate
                    annotation.spotInfo = spotInfo
                    annotation.title = spotInfo.spotName
                    annotation.rank = self.getMapRank(spot: annotation.spotInfo)
                    annotation.isHidden = true
                    
                    self.nearbyAnnotations.updateValue(annotation, forKey: spotInfo.id!)
                    
                    if !self.spotFilteredByLocation(mapCoordinates: self.mapView.region.boundingBoxCoordinates, spotCoordinates: spotLocation.coordinate) && self.spotObject == nil && self.newSpotName == "" {
                        self.nearbyAnnotations[spotInfo.id!]?.isHidden = false
                        DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
                    }
                    
                    
                } else { self.noAccessCount += 1; self.accessEscape(); return }
            } catch { self.noAccessCount += 1; self.accessEscape(); return }
        }
    }
    
    
    func accessEscape() {
        if noAccessCount + appendCount == nearbyEnteredCount && queryReady { endQuery() }
    }
    
    func endQuery() {
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        reloadChooseSpot(resort: true, spotSelect: false)
    }
    
    func selectSpot(index: Int, select: Bool, fromMap: Bool) {
        
        Mixpanel.mainInstance().track(event: "UploadSpotSelect", properties: ["select": fromMap, "fromMap": fromMap])
        
        /// deselect spot,, select new if applicable
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.selected!}) { UploadImageModel.shared.nearbySpots[i].selected = false }
        postObject.spotName = ""
        spotObject = nil
                
        if select {
            UploadImageModel.shared.nearbySpots[index].selected = true
            postObject.spotName = UploadImageModel.shared.nearbySpots[index].spotName
            spotObject = UploadImageModel.shared.nearbySpots[index]
            postObject.spotPrivacy = spotObject.privacyLevel
            postType = spotObject.founderID == "" ? .postToPOI : .postToSpot
            UploadImageModel.shared.tappedLocation = CLLocation() /// reset tapped location on spot select-> user can choose a new location in relation to the new spot
        }
        
        let spotPrivacy = spotObject != nil ? spotObject.privacyLevel : submitPublic ? "public" : "friends"
        postObject.privacyLevel = spotPrivacy == "invite" ? "invite" : spotPrivacy == "friends" ? "friends" : postObject.privacyLevel == "invite" ? "friends" : spotPrivacy
        postObject.spotPrivacy = spotPrivacy
        
        mapView.removeAnnotations(nearbyAnnotations.map({$0.value})) /// remove all annotations to be safe
        filterSpots() /// filter map before moving map on set post location to get correct hidden values set
                                  ///
        if select { setPostLocation() }
        resetImages() /// resort images by location
        reloadChooseSpot(resort: fromMap, spotSelect: true)
        addPostButton() /// set postButtonAlpha based on if spot selected

        /// show just this spot anno on th
        /// e map
        if !nearbyAnnotations.contains(where: {$0.key == spotObject.id!}) {
            addSpotAnno(spot: spotObject)
        }
    }
    
    func reloadChooseSpot(resort: Bool, spotSelect: Bool) {

        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
            /// spotSelect is true for select AND deselect
            if spotSelect {
                self.reloadOverviewDetail()
                self.uploadTable.performBatchUpdates {
                    if self.spotObject != nil || self.newSpotName != "" { self.uploadTable.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .fade) } else { self.uploadTable.reloadData() } /// smooth animation for new selection, reload whole table to reset on deselect 
                }
                /// only need to show the selected spot / remove the choose spot row if selecting new
                return
            }
                    
            guard let chooseCell = self.uploadTable.cellForRow(at: IndexPath(row: 1, section: 0)) as? UploadChooseSpotCell else { return }
            
            chooseCell.chooseSpotCollection.performBatchUpdates {
                
                if resort {
                    /// if not selecting, resort
                    if !UploadImageModel.shared.nearbySpots.isEmpty {
                        let postCoordinate = CLLocationCoordinate2D(latitude: self.postObject.postLat, longitude: self.postObject.postLong)
                        UploadImageModel.shared.resortSpots(coordinate: postCoordinate)
                    }
                }
                
                chooseCell.loading = false
                chooseCell.chooseSpotCollection.reloadSections(IndexSet(0...0))
            }
        }
    }
    
    func resetImages() {
        guard let imagesCell = uploadTable.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
        imagesCell.sortAndReload(location: CLLocation(latitude: postObject.postLat, longitude: postObject.postLong))
    }
        
    func presentAddNew() {
        
        if maskView != nil && maskView.superview != nil { return }
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
        
        newView = NewSpotNameView(frame: CGRect(x: 32, y: view.bounds.height/3, width: view.bounds.width - 64, height: 120))
        newView.delegate = self
        newView.textField.text = newSpotName
        maskView.addSubview(newView)
        
        newView.textField.becomeFirstResponder()
    }
    
    func presentTagPicker() {
        
        if maskView != nil && maskView.superview != nil { return }
        closeKeyboard() /// close caption keyboard if open
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        window?.addSubview(maskView)
                
        let tagView = UploadChooseTagView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 350, width: UIScreen.main.bounds.width, height: 350))
        tagView.layer.cornerRadius = 8
        tagView.layer.cornerCurve = .continuous
        tagView.tag = 100
        tagView.setUp()
        tagView.delegate = self
        maskView.addSubview(tagView)
    }
    
    func openCamera() {
        
        if navigationController?.viewControllers.contains(where: {$0.isKind(of: AVCameraController.self)}) ?? false { return }

        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func openGallery() {
        
        if navigationController?.viewControllers.contains(where: {$0.isKind(of: PhotosContainerController.self)}) ?? false { return }
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "PhotosContainer") as? PhotosContainerController {
            
            vc.spotObject = spotObject
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func switchToChooseSpot() {
        
        if passedSpot != nil { return } /// cant edit spot on passed spot
        closeKeyboard() /// close caption keyboard if open
        animateToChooseSpot()
        
        DispatchQueue.main.async {
            self.nearbyTable.reloadData()
            if self.nearbyTable.numberOfRows(inSection: 0) > 0 { self.nearbyTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false) }
        }
    }
    
    func pushInviteFriends() {
        
        if navigationController?.viewControllers.contains(where: {$0.isKind(of: InviteFriendsController.self)}) ?? false { return }
        closeKeyboard() /// close caption keyboard if open
        
        if let inviteVC = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "InviteFriends") as? InviteFriendsController {
            
            var friends = UploadImageModel.shared.friendObjects /// friendsList sorted by top friends
            friends.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"})
            
            /// add selected friends to show in header, remove from table friendslist
            for friend in postObject.addedUserProfiles {
                inviteVC.selectedFriends.append(friend)
                friends.removeAll(where: {$0.id == friend.id})
            }
            
            inviteVC.friendsList = friends
            inviteVC.queryFriends = friends
            inviteVC.delegate = self
            
            self.present(inviteVC, animated: true, completion: nil)
        }
    }
    
    func exitNewSpot() {
        
        postType = .none
        newSpotName = ""
        newSpotID = ""
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
    
    /// show flip animation from spotIcon to tag
    func runTagTransition() {
        
        guard let overviewCell = self.uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        UIView.transition(with: overviewCell.spotIcon,
                          duration: 0.5,
                          options: .transitionFlipFromRight,
                          animations: {
                            overviewCell.spotIcon.image = Tag(name: UploadImageModel.shared.selectedTag).image
            
        }) { [weak self] _ in
            guard let self = self else { return }
            self.reloadOverviewDetail()
        }
    }
                          
    /// reload detail view to show "is ___" + spotName
    func reloadOverviewDetail() {
        guard let cell = uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        cell.loadDetailView(post: postObject)
    }
    
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        removePreviews()
    }
    
    func removePreviews() {
        for sub in maskView.subviews { sub.removeFromSuperview() }
        maskView.removeFromSuperview()
    }
    
    func runFailedUpload(spot: MapSpot, post: MapPost, selectedImages: [UIImage], actualTimestamp: Date) {
        Mixpanel.mainInstance().track(event: "UploadPostFailed", properties: nil)
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
        /*
        switch postType {
            
        case .newSpot, .postToPOI:
            
            let spotObject = SpotDraft(context: managedContext)
            
            spotObject.spotName = spot.spotName
            spotObject.spotDescription = spot.spotDescription
            spotObject.tag = post.tag ?? ""
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
            spotObject.friendsList = post.friendsList
            spotObject.city = post.city ?? ""
            spotObject.poiCategory = spot.poiCategory ?? ""
            spotObject.addedUsers = post.addedUsers ?? []
            
            let timestamp = actualTimestamp.timeIntervalSince1970
            let seconds = Int64(timestamp)
            spotObject.timestamp = seconds
            
        default:
            */
        let postObject = PostDraft(context: managedContext)
        postObject.caption = post.caption
        postObject.city = post.city ?? ""
        postObject.createdBy = post.createdBy
        postObject.privacyLevel = post.privacyLevel
        postObject.spotPrivacy = spot.privacyLevel
        postObject.spotIDs = [spot.id!]
        postObject.inviteList = spot.inviteList ?? []
        postObject.postLat = post.postLat
        postObject.postLong = post.postLong
        postObject.spotLat = spot.spotLat
        postObject.spotLong = spot.spotLong
        postObject.spotNames = [spot.spotName]
        postObject.taggedUsers = post.taggedUsers
        postObject.taggedUserIDs = post.taggedUserIDs
        postObject.images = NSSet(array: imageObjects)
        postObject.uid = uid
        postObject.isFirst = false
        postObject.visitorList = spot.visitorList
        postObject.hideFromFeed = post.hideFromFeed ?? false
        postObject.frameIndexes = post.frameIndexes ?? []
        postObject.aspectRatios = aspectRatios
        postObject.friendsList = post.friendsList
        postObject.addedUsers = post.addedUsers
        postObject.tags = [post.tag!]
        postObject.newSpot = postType == .newSpot
        postObject.postToPOI = postType == .postToPOI
        postObject.poiCategory = spot.poiCategory ?? ""
        postObject.phone = spot.phone ?? ""
        postObject.spotIndexes = [0]
            
            let timestamp = actualTimestamp.timeIntervalSince1970
            let seconds = Int64(timestamp)
            postObject.timestamp = seconds
     //   }
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

// delegate methods
extension UploadPostController: GIFPreviewDelegate, NewSpotNameDelegate, InviteFriendsDelegate, ChooseTagDelegate, PrivacyPickerDelegate, ShowOnFeedDelegate {
        
    func finishPassingLocationPicker(spot: MapSpot) {
        
        /// deselect old spot
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.selected!}) {
            UploadImageModel.shared.nearbySpots[i].selected = false
        }
        
        /// remove new spot anno from map
        if newSpotID != "" {
            if let anno = nearbyAnnotations.first(where: {$0.key == newSpotID}) {
                mapView.removeAnnotation(anno.value)
                nearbyAnnotations.removeValue(forKey: newSpotID)
            }
        }
        
        newSpotName = ""
        newSpotID = ""
        
        /// select new spot
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.id == spot.id}) { selectSpot(index: i, select: true, fromMap: true) } else {
            UploadImageModel.shared.nearbySpots.append(spot)
            selectSpot(index: UploadImageModel.shared.nearbySpots.count - 1, select: true, fromMap: true)
        }
    }
    
    func finishPassingPrivacy(tag: Int) {

        Mixpanel.mainInstance().track(event: "UploadPrivacySelected", properties: ["tag": tag])

        switch tag {
            
        case 0:
            if postType == .newSpot {
                launchSubmitPublic()
                return
                
            } else {
                postObject.privacyLevel = "public"
                privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", spotPrivacy: postObject.spotPrivacy ?? "friends", postType: postType)
            }
            
        case 1:
            postObject.privacyLevel = "friends"
            privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", spotPrivacy: postObject.spotPrivacy ?? "friends", postType: postType)
            
        case 2:
            postObject.privacyLevel = "invite"
            closePrivacyPicker()
            pushInviteFriends()
            
        case 3:
            /// pressed "okay" on submit public
            postObject.privacyLevel = "public"
            submitPublic = true
            privacyView.setUp(privacyLevel: postObject.privacyLevel ?? "friends", spotPrivacy: postObject.privacyLevel ?? "friends", postType: postType)
            
        default: return
        }
    }
    
    func finishPassingVisibility(hide: Bool) {
        Mixpanel.mainInstance().track(event: "UploadVisibilitySelected", properties: ["hide": hide])
        postObject.hideFromFeed = hide
    }
    
    func finishPassingName(name: String) {
        
        var overrideSelection = false
        if let i = UploadImageModel.shared.nearbySpots.firstIndex(where: {$0.selected!}) {
            UploadImageModel.shared.nearbySpots[i].selected = false
            spotObject = nil
            postObject.spotPrivacy = "friends"
            postObject.privacyLevel = "friends"
            overrideSelection = true
        }
        
        Mixpanel.mainInstance().track(event: "UploadNameSelected", properties: ["overrideSelection": overrideSelection])

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        newSpotName = trimmedName == "" ? trimmedName : name
        postObject.spotName = newSpotName
        postType = .newSpot
        
        removePreviews()
        newView = nil
        reloadChooseSpot(resort: false, spotSelect: true)
        addPostButton()

        /// remove old new spot if changing it
        if newSpotID != "" { if let anno = nearbyAnnotations.removeValue(forKey: newSpotID) { mapView.removeAnnotation(anno) } }
        if newSpotName == "" { return }
        
        /// spot location will be in the same place if no spot already selected, only need to reset if spot selected before
        if overrideSelection {
            setPostLocation()
            resetImages()
        }
        
        var newSpot = MapSpot(spotDescription: "", spotName: newSpotName, spotLat: postObject.postLat, spotLong: postObject.postLong, founderID: uid, privacyLevel: "", imageURL: "")
        newSpot.id = UUID().uuidString
        newSpotID = newSpot.id!
        addSpotAnno(spot: newSpot)
        filterSpots()
    }
    
    func finishPassingTag(tag: Tag) {

        let animate = tag.selected && UploadImageModel.shared.selectedTag == ""
        postObject.tag = tag.selected ? tag.name : ""
        UploadImageModel.shared.selectedTag = tag.selected ? tag.name : ""
        
        Mixpanel.mainInstance().track(event: "UploadTagSelected", properties: ["tag": tag.name, "selected": tag.selected])

        DispatchQueue.main.async {
            self.removePreviews()
            animate ? self.runTagTransition() : self.reloadOverviewDetail()
        }
    }
    
    func finishPassingSelectedFriends(selected: [UserProfile]) {
        
        postObject.addedUsers = selected.map({$0.id ?? ""})
        postObject.addedUserProfiles = selected
        Mixpanel.mainInstance().track(event: "UploadFriendsSelected", properties: ["friendCount": selected.count, "privacyLevel": postObject.privacyLevel ?? "friends"])
        
        if postObject.privacyLevel == "invite" {
            postObject.inviteList = postObject.addedUsers!
            presentPrivacyPicker()
        }
                
        DispatchQueue.main.async {
            self.reloadOverviewDetail()
        }
    }
    
    func finishPassingFromCamera(images: [UIImage]) {
        
        Mixpanel.mainInstance().track(event: "UploadSelectFromCamera", properties: nil)

        let gifMode = images.count > 1
        let object = ImageObject(id: UUID().uuidString, asset: PHAsset(), rawLocation: UserDataModel.shared.currentLocation, stillImage: images.first ?? UIImage(), animationImages: gifMode ? images : [], animationIndex: 0, directionUp: true, gifMode: gifMode, creationDate: Date(), fromCamera: true)
        UploadImageModel.shared.scrollObjects.append(object)
        
        sortAndReloadImages(newSelection: true, fromGallery: false)
    }
    
    /// not a delegate method because just notifying to check selected images on select tap
    func finishPassingFromGallery() {
        
        Mixpanel.mainInstance().track(event: "UploadSelectFromGallery", properties: nil)

        UploadImageModel.shared.scrollObjects.removeAll()
        for object in UploadImageModel.shared.selectedObjects {
            UploadImageModel.shared.scrollObjects.append(object)
        }
        
        sortAndReloadImages(newSelection: true, fromGallery: true)
    }
    
    func cancelFromGallery() {
        
        Mixpanel.mainInstance().track(event: "UploadCancelFromGallery", properties: nil)
        
        /// reset selectedImages and imageObjects
        UploadImageModel.shared.selectedObjects.removeAll()
        while let i = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.selected}) {
            UploadImageModel.shared.imageObjects[i].selected = false
        }
        
        for object in UploadImageModel.shared.scrollObjects {
            UploadImageModel.shared.selectedObjects.append(object)
            if let index = UploadImageModel.shared.imageObjects.firstIndex(where: {$0.image.id == object.id}) {
                UploadImageModel.shared.imageObjects[index].selected = true
            }
        }
        
        sortAndReloadImages(newSelection: false, fromGallery: true)
    }
    
    func downloadImage(cellIndex: Int, galleryIndex: Int, circleTap: Bool) {
                
        if UploadImageModel.shared.selectedObjects.count > 4 { return } /// show error alert
        guard let selectedObject = UploadImageModel.shared.imageObjects[safe: galleryIndex] else { return }
        
        if selectedObject.image.stillImage != UIImage() {
            Mixpanel.mainInstance().track(event: "UploadSelectImage", properties: ["selected": true])
            selectImageAt(index: galleryIndex, selected: true)
            
        } else {
            guard let imagesCell = uploadTable.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
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
                    
                    Mixpanel.mainInstance().track(event: "UploadSelectImage", properties: ["selected": true])
                    self.selectImageAt(index: galleryIndex, selected: true)
                }
            }
        }
    }
    
    func selectImageAt(index: Int, selected: Bool) {
        
        /// delete image from camera entirely
        if !selected && index == -1 {
            UploadImageModel.shared.scrollObjects.removeAll(where: {$0.fromCamera})
            sortAndReloadImages(newSelection: selected, fromGallery: false)
            return
        }
        
        /// add/remove image to scroll objects and selected images
        let imageObject = UploadImageModel.shared.imageObjects[index].image
        selected ? UploadImageModel.shared.scrollObjects.append(imageObject) : UploadImageModel.shared.scrollObjects.removeAll(where: {$0.id == imageObject.id})
        /// update image model
        UploadImageModel.shared.selectObject(imageObject: imageObject, selected: selected)
        /// reload cells 0 & 2
        sortAndReloadImages(newSelection: selected, fromGallery: false)
    }
    
    func sortAndReloadImages(newSelection: Bool, fromGallery: Bool) {
        
        if cancelOnDismiss { return }
        
        if newSelection || UploadImageModel.shared.scrollObjects.count == 0 { setPostLocation() }
        
        guard let overviewCell = self.uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadOverviewCell else { return }
        
        guard let imageCell = uploadTable.cellForRow(at: IndexPath(row: 2, section: 0)) as? UploadImagesCell else { return }
        imageCell.setImages(reload: true)

        DispatchQueue.main.async {
                        
            overviewCell.selectedCollection.performBatchUpdates {
                overviewCell.selectedCollection.reloadSections(IndexSet(0...0))
                
            } completion: { complete in
                /// scroll to selected item if newSelection out of bounds
                let ct = overviewCell.selectedCollection.numberOfItems(inSection: 0)
                if complete && newSelection && ct > 2 {
                    overviewCell.selectedCollection.scrollToItem(at: IndexPath(row: ct - 1, section: 0), at: .right, animated: true) }
            }

        }
    }
    
    func setPostLocation() {
        
        /// update post location, if this is a new post in post #1, re-run choose spot fetch with new location
        let previousLong = postObject.postLong
        let previousLat = postObject.postLat
        
        /// default: postLocation = user's current location
        var postLocation = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)
        
        /// 1. if theres a selected image with location, use that location
        let scrollObjects = UploadImageModel.shared.scrollObjects
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
                
        postObject.postLat = postLocation.latitude
        postObject.postLong = postLocation.longitude
        
        let animated = (abs(postObject.postLat - previousLat) + abs(postObject.postLong - previousLong)) < (abs(mapView.region.span.latitudeDelta) + abs(mapView.region.span.longitudeDelta)) /// only want to animate nearby stuff, animation over a mile or 2 takes too long
        setPostAnnotation(first: false, animated: animated)
        
        /// set new spot annotation to post location
        if newSpotName != "" { nearbyAnnotations[newSpotID]?.coordinate = postLocation }
        
        /// get a new batch of nearby spots if selecting an image
        if postObject.postLong != previousLong {
            fetchImmediately = true
            setPostCity() /// set post city with every location change
        }
    }
    
    func setPostCity() {
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)) { [weak self] (city) in
            guard let self = self else { return }
            self.postObject.city = city
        }
    }
    
    func deselectImage(index: Int, circleTap: Bool) {
        Mixpanel.mainInstance().track(event: "UploadSelectImage", properties: ["selected": false])
        selectImageAt(index: index, selected: false)
    }
    
    func cancelFetchForRowAt(index: Int) {
        
        Mixpanel.mainInstance().track(event: "UploadCancelImageFetch")
        
        guard let imageCell = uploadTable.cellForRow(at: IndexPath(row: 0, section: 0)) as? UploadImagesCell else { return }
        guard let cell = imageCell.imagesCollection.cellForItem(at: IndexPath(row: index + 1, section: 0)) as? ImagePreviewCell else { return }
        
        guard let currentObject = UploadImageModel.shared.scrollObjects[safe: index] else { return }
        let currentAsset = currentObject.asset
        
        cell.activityIndicator.stopAnimating()
        imageFetcher.cancelFetchForAsset(asset: currentAsset)
    }
    
    func askForGallery(first: Bool) {
        
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
            
        case .notDetermined:
            /// set nav bar item colors in case using limited gallery
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.systemBlue], for: .highlighted)
            PHPhotoLibrary.requestAuthorization { _ in self.askForGallery(first: false) }
            
        case .restricted, .denied:
            
            /// if restricted / denied on the first time asking for gallery, prompt user to open settings
            if first {UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil ); return }
            
            let alert = UIAlertController(title: "Allow gallery access to upload pictures from your camera roll", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil) }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            
            
        case .authorized, .limited:
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .normal)
            UIBarButtonItem.appearance().setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .highlighted)
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
    
    func showError(message: String) {
        
        let errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 100, width: UIScreen.main.bounds.width, height: 32))
        errorBox.backgroundColor = UIColor(red: 0.929, green: 0.337, blue: 0.337, alpha: 1)
        view.addSubview(errorBox)
        
        let errorText = UILabel(frame: CGRect(x: 0, y: 6, width: UIScreen.main.bounds.width, height: 18))
        errorText.lineBreakMode = .byWordWrapping
        errorText.numberOfLines = 0
        errorText.textColor = UIColor.white
        errorText.textAlignment = .center
        errorText.text = message
        errorText.font = UIFont(name: "SFCompactText-Regular", size: 14)!
        errorBox.addSubview(errorText)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            errorBox.removeFromSuperview()
        }
    }
}


extension UploadPostController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        if touch.view == nil { return false }
        /// only close view on touch outside of textView. use tag of 100 when tag not used for other properties
        if touch.view!.isKind(of: UICollectionView.self) || touch.view!.isKind(of: UploadTagCell.self) || touch.view!.isKind(of: TagCategoryCell.self) || touch.view!.tag == 100 { return false }
        // avoid accidental closures when typing new spot name
        if (touch.view!.isKind(of: NewSpotNameView.self)) { return false }
        // for keyboard close
        if touch.view!.isKind(of: UITextView.self) { return false }
        return true
    }
    
}

extension UploadPostController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0: return 3 /// uploadTable
        case 1: return min(UploadImageModel.shared.nearbySpots.count, 25) /// nearbyTable
        case 2: return min(querySpots.count, 7) /// resultsTable
        default: return 0
        }
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView.tag {
        case 0:
            switch indexPath.row {
            case 0:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadOverview") as? UploadOverviewCell else { return UITableViewCell() }
                cell.setUp(post: postObject)
                cell.clipsToBounds = true
                return cell
                
            case 1:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpot") as? UploadChooseSpotCell else { return UITableViewCell() }
                let selected = spotObject != nil
                cell.setUp(newSpotName: newSpotName, selected: selected, post: postObject)
                cell.clipsToBounds = true
                return cell
                
            case 2:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImages") as? UploadImagesCell else { return UITableViewCell() }
                cell.setUp()
                return cell
                
            default: return UITableViewCell()
            }
            
        default:
            /// used for both choose spot / results tables
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotCell") as? LocationPickerSpotCell else { return UITableViewCell() }
            let spot = tableView.tag == 1 ? UploadImageModel.shared.nearbySpots[indexPath.row] : querySpots[indexPath.row]
            cell.tag = tableView.tag
            cell.setUp(spot: spot)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        switch tableView.tag {
        case 0:
            let screenSize = UserDataModel.shared.screenSize
            var bodyHeight: CGFloat = spotObject == nil && newSpotName == "" ? 0 : 96
            bodyHeight += screenSize == 0 ? 112 : screenSize == 1 ? 117 : 140
            let collectionHeight = screenSize == 0 ? 140 * 1.3266 : screenSize == 1 ? 160 * 1.3266 : 195 * 1.3266
            
            let imageWidth = UIScreen.main.bounds.width / 5.4166
            let imageHeight = imageWidth * 1.21388
            let imagesCellHeight: CGFloat = screenSize == 0 ? imageHeight + 50 : imageHeight * 2 + 58
            
            switch indexPath.row {
                case 0: return collectionHeight + bodyHeight
                case 1: return spotObject == nil && newSpotName == "" ? 96 : 0
                case 2: return imagesCellHeight
                default: return 0
            }
        case 1: return 62
        case 2: return 53
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        /// new spot selection from nearby/upload
        let spot = tableView.tag == 1 ? UploadImageModel.shared.nearbySpots[indexPath.row] : querySpots[indexPath.row]
        searchBar.endEditing(true)
        finishPassingLocationPicker(spot: spot)
        animateToUpload()
    }
}

extension UploadPostController: MKMapViewDelegate {
        
    func setPostAnnotation(first: Bool, animated: Bool) {
        
        let distance: CLLocationDistance = 1000
        let coordinate = CLLocationCoordinate2D(latitude: postObject.postLat, longitude: postObject.postLong)
        let centerOffset = chooseSpotMode ? 0.00025 : 0.0015
        let adjustedCenter = CLLocationCoordinate2D(latitude: coordinate.latitude - centerOffset, longitude: coordinate.longitude)
        let camera = MKMapCamera(lookingAtCenter: adjustedCenter, fromDistance: distance, pitch: 0, heading: 0)

        DispatchQueue.main.async {
            self.mapView.setCamera(camera, animated: animated)
            self.postAnnotation.coordinate = coordinate
            if first { self.mapView.addAnnotation(self.postAnnotation) }
        }

        return
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                
        if annotation is CustomPointAnnotation {
            /// main location annotation
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "Upload") as? UploadAnnotationView
            
            if annotationView == nil {
                annotationView = UploadAnnotationView(annotation: annotation, reuseIdentifier: "Upload")
            } else {
                annotationView!.annotation = annotation
            }
            
            if !cancelOnDismiss {
                let nibView = loadUploadDown()
                annotationView!.image = nibView.asImage()
                
            } else {
                let nibView = self.loadPostDown()
                annotationView!.image = nibView.asImage()
            }
                        
            annotationView!.sizeToFit()
            return annotationView
                            
        } else if let anno = annotation as? CustomSpotAnnotation {
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? SpotAnnotationView
            if annotationView == nil {
                annotationView = SpotAnnotationView(annotation: anno, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            } else {
                annotationView!.annotation = annotation
            }
            
            annotationView?.clusteringIdentifier = nil
            annotationView?.displayPriority = spotObject != nil || newSpotName != "" ? .required : anno.spotInfo.postIDs.isEmpty ? .defaultLow : .defaultHigh
            let nibView = loadSpotNib()
            
            var spotName = ""
            if let anno = self.nearbyAnnotations.first(where: {$0.value.spotInfo.id == anno.spotInfo.id}) {
                spotName = anno.value.spotInfo.spotName
            }
            
            nibView.spotNameLabel.text = spotName
            
            let temp = nibView.spotNameLabel
            temp?.sizeToFit()
            nibView.resizeBanner(width: temp?.frame.width ?? 0)
            
            let nibImage = nibView.asImage()
            annotationView!.image = nibImage
            annotationView!.alpha = 0.25
            annotationView!.isUserInteractionEnabled = false
            
            return annotationView
            
        }  else { return nil }
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        /// disable userlocation callout on tap
        if let userView = mapView.view(for: mapView.userLocation) { userView.isEnabled = false }
        if let uploadView = views.first(where: {$0 is UploadAnnotationView}) { mapView.bringSubviewToFront(uploadView) } /// bring profile in front of other spots
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {

        let span = mapView.region.span
        if span.longitudeDelta < 0.001 {
            /// remove clustering if zoomed in far (check here if zoom went over boundary on this zoom)
            if self.shouldCluster {
                self.shouldCluster = false
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    self.mapView.removeAnnotations(annotations)
                    self.mapView.addAnnotations(annotations)
                }
            }
        } else {
            if !self.shouldCluster {
                self.shouldCluster = true
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    self.mapView.removeAnnotations(annotations)
                    self.mapView.addAnnotations(annotations)
                }
            }
        }
        
        /// should update region is on a delay so that it doesn't get called constantly on the map pan
        if shouldUpdateRegion && queryReady {
        
            shouldUpdateRegion = false
            let delay = fetchImmediately ? 0.0 : 2.0
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
                
                guard let self = self else { return }
                
                self.shouldUpdateRegion = true
                if !mapView.region.IsValid { return }
                self.filterSpots()
                self.runChooseSpotFetch()
                self.fetchImmediately = false
            }
        }
    }

    // set location on tap
    @objc func mapTap(_ sender: UITapGestureRecognizer) {
        
        Mixpanel.mainInstance().track(event: "UploadMapTap")
        
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
    
        UploadImageModel.shared.tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude) /// tappedLocation will take precedence over spot
        postObject.postLat = coordinate.latitude
        postObject.postLong = coordinate.longitude
        setPostAnnotation(first: false, animated: true)
        
        setPostCity() /// set post city with every location change
        resetImages()
        reloadChooseSpot(resort: true, spotSelect: false)
        DispatchQueue.main.async { self.nearbyTable.reloadSections(IndexSet(0...0), with: .automatic) }
    }

    func filterSpots() {
        
        for anno in nearbyAnnotations {
            
            if spotObject != nil || newSpotName != "" {
                
                if (spotObject != nil && anno.value.spotInfo.id != spotObject.id) || (newSpotName != "" && anno.value.spotInfo.spotName != newSpotName) {
                    DispatchQueue.main.async { self.hideAnnotation(anno: anno.value) }
                    
                } else if !cancelOnDismiss {
                    DispatchQueue.main.async { self.unhideAnnotation(anno: anno.value) }
                }
                continue
                
            } else if mapView.spotFilteredByLocation(spotCoordinates: anno.value.coordinate) {
                DispatchQueue.main.async { self.hideAnnotation(anno: anno.value) }
                
            } else if anno.value.isHidden {
                /// check if we're adding it back on search page reappear or filter values changed
                DispatchQueue.main.async { self.unhideAnnotation(anno: anno.value) }
            }
        }
    }
    
    func hideAnnotation(anno: CustomSpotAnnotation) {
        self.nearbyAnnotations[anno.spotInfo.id!]?.isHidden = true
        self.mapView.removeAnnotation(anno)
    }
    
    func unhideAnnotation(anno: CustomSpotAnnotation) {
        self.nearbyAnnotations[anno.spotInfo.id!]?.isHidden = true
        self.mapView.addAnnotation(anno)
    }
    
    func addSpotAnno(spot: MapSpot) {
        let annotation = CustomSpotAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        annotation.spotInfo = spot
        nearbyAnnotations.updateValue(annotation, forKey: spot.id!)
        DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
    }

    func loadSpotNib() -> MapTarget {
        let infoWindow = MapTarget.instanceFromNib() as! MapTarget
        infoWindow.clipsToBounds = true
        infoWindow.spotNameLabel.font = UIFont(name: "SFCompactText-Regular", size: 13)
        infoWindow.spotNameLabel.numberOfLines = 2
        infoWindow.spotNameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        infoWindow.spotNameLabel.lineBreakMode = .byWordWrapping
        
        return infoWindow
    }
    
    func loadUploadUp() -> UploadWindowUp {
        let infoWindow = UploadWindowUp.instanceFromNib() as! UploadWindowUp
        infoWindow.clipsToBounds = true
        return infoWindow
    }
    
    func loadUploadMiddle() -> UploadWindowMiddle {
        let infoWindow = UploadWindowMiddle.instanceFromNib() as! UploadWindowMiddle
        infoWindow.clipsToBounds = true
        return infoWindow
    }
    
    func loadUploadDown() -> UploadWindowDown {
        let infoWindow = UploadWindowDown.instanceFromNib() as! UploadWindowDown
        infoWindow.clipsToBounds = true
        return infoWindow
    }
    
    func loadPostUp() -> UploadPostUp {
        let infoWindow = UploadPostUp.instanceFromNib() as! UploadPostUp
        infoWindow.clipsToBounds = true
        infoWindow.postImage.contentMode = .scaleAspectFill
        infoWindow.postImage.clipsToBounds = true
        infoWindow.postImage.layer.cornerRadius = 8
        infoWindow.postImage.image = postObject.postImage.first ?? UIImage()
        return infoWindow
    }
    
    func loadPostMiddle() -> UploadPostMiddle {
        let infoWindow = UploadPostMiddle.instanceFromNib() as! UploadPostMiddle
        infoWindow.clipsToBounds = true
        infoWindow.postImage.contentMode = .scaleAspectFill
        infoWindow.postImage.clipsToBounds = true
        infoWindow.postImage.layer.cornerRadius = 8
        infoWindow.postImage.image = postObject.postImage.first ?? UIImage()
        return infoWindow
    }
    
    func loadPostDown() -> UploadPostDown {
        let infoWindow = UploadPostDown.instanceFromNib() as! UploadPostDown
        infoWindow.clipsToBounds = true
        infoWindow.postImage.contentMode = .scaleAspectFill
        infoWindow.postImage.clipsToBounds = true
        infoWindow.postImage.layer.cornerRadius = 8
        infoWindow.postImage.image = postObject.postImage.first ?? UIImage()
        return infoWindow
    }
}

