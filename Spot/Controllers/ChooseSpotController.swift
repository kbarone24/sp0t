//
//  ChooseSpotController.swift
//  Spot
//
//  Created by kbarone on 9/16/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation
import Geofirestore
import Mixpanel
import FirebaseUI
import MapKit

class ChooseSpotController: UIViewController {
    
    unowned var mapVC: MapViewController!
    weak var locationPickerVC: LocationPickerController!
    
    lazy var selectedImages: [UIImage] = []
    lazy var frameIndexes: [Int] = []
    lazy var nearbyIDs: [(id: String, distance: CLLocationDistance)] = []
    lazy var nearbyPOIs: [POI] = []
    lazy var nearbySpotsRef: [MapSpot] = [] /// keep basic spot structure to avoid closure issues on remove duplicates
    lazy var nearbySpots: [MapSpot] = []
    
    lazy var searchTextGlobal = ""
    lazy var queryIDs: [(id: String, score: Double)] = []
    lazy var queryPOIs: [POI] = []
    lazy var querySpotsRef: [MapSpot] = [] //// keep basic spot structure to avoid closure issues on remove duplicates
    lazy var querySpots: [MapSpot] = []

    var postLocation: CLLocationCoordinate2D!
    var postDate: Date!
    var nearbyTable: UITableView!
    var nearbyIndicator: CustomActivityIndicator!
        
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var resultsTable: UITableView!
    var searchIndicator: CustomActivityIndicator!
    
    var circleQuery: GFSCircleQuery?
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    var searchManager: SDWebImageManager!
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]
        
    var queryReady = false
    var spotLoaded = false /// true when there's a spot in the nearby radius
    var emptyView: UIView! /// empty footer view
    var infoMask: UIView!
    
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyRefreshCount = 0
    var searchRefreshCount = 0
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        searchManager = SDWebImageManager()
        
        setUpNavBar()
        setUpViews()
        
        if nearbyIDs.isEmpty { DispatchQueue.global().async {
            self.getNearbyPOIs()
            self.getNearbySpots()
        }}
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseSpotOpen")
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)

        /// indicator animation doesn't work until view has entered foreground
        if nearbyIndicator == nil && nearbyTable != nil && nearbyRefreshCount < 2 && emptyView == nil {
            nearbyIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 10, width: UIScreen.main.bounds.width, height: 30))
            nearbyTable.addSubview(nearbyIndicator)
            DispatchQueue.main.async { self.nearbyIndicator.startAnimating() }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if searchManager != nil { searchManager.cancelAll() }
        if circleQuery != nil { circleQuery?.removeAllObservers() }
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }
    
    func setUpNavBar() {

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)

        let titleView = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 75, y: 14, width: 150, height: 23))
        titleView.text = "Choose a spot"
        titleView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        titleView.font = UIFont(name: "SFCamera-Regular", size: 18)
        titleView.textAlignment = .center
        navigationItem.titleView = titleView
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "+ New Spot", style: .plain, target: self, action: #selector(newSpotTap(_:)))
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "SpotGreen")!, NSAttributedString.Key.font : UIFont(name: "SFCamera-Semibold", size: 15)!], for: .normal)
    }
    
    func setUpViews() {
        
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: 15, width: UIScreen.main.bounds.width, height: 40))
        searchBarContainer.backgroundColor = nil
        view.addSubview(searchBarContainer)
        
        searchBar = UISearchBar(frame: CGRect(x: 14, y: 3, width: UIScreen.main.bounds.width - 28, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.showsCancelButton = false
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.searchTextField.clipsToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBar.placeholder = "Search spots"
        searchBar.tintColor = .white
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 70, y: 5.5, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        searchBarContainer.addSubview(cancelButton)
        
        nearbyTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY + 20, width: UIScreen.main.bounds.width, height: view.bounds.height - searchBarContainer.frame.maxY - 20))
        nearbyTable.backgroundColor = UIColor(named: "SpotBlack")
        nearbyTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        nearbyTable.showsVerticalScrollIndicator = false
        nearbyTable.separatorStyle = .none
        nearbyTable.dataSource = self
        nearbyTable.delegate = self
        nearbyTable.tag = 0
        nearbyTable.isUserInteractionEnabled = true
        nearbyTable.register(ChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpotCell")
        nearbyTable.register(ChooseSpotHeader.self, forHeaderFooterViewReuseIdentifier: "ChooseSpotHeader")
        view.addSubview(nearbyTable)
        
        /// results table unhidden when search bar is interacted with - update with keyboard height
        resultsTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY + 10, width: UIScreen.main.bounds.width, height: 400))
        resultsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.backgroundColor = UIColor(named: "SpotBlack")
        resultsTable.separatorStyle = .none
        resultsTable.showsVerticalScrollIndicator = false
        resultsTable.isHidden = true
        resultsTable.register(SpotSearchCell.self, forCellReuseIdentifier: "SpotSearch")
        resultsTable.tag = 1
        
        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
        view.addSubview(resultsTable)
    }
    
    func getNearbyPOIs() {
        
        let searchRequest = MKLocalPointsOfInterestRequest(center: postLocation, radius: 200)
        /// these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
        let filters = MKPointOfInterestFilter(including: searchFilters)
        searchRequest.pointOfInterestFilter = filters
        
        runPOIFetch(request: searchRequest)
    }
    
    /// recursive func called with an increasing radius -> Ensure always fetching the closest POI's since max limit is 25
    func runPOIFetch(request: MKLocalPointsOfInterestRequest) {
            
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in

            guard let self = self else { return }
            
            let newRequest = MKLocalPointsOfInterestRequest(center: self.postLocation, radius: request.radius * 2)
            print("radius", newRequest.radius)
            newRequest.pointOfInterestFilter = request.pointOfInterestFilter

            
            /// if the new radius won't be greater than about 1.5 miles then run poi fetch to get more nearby stuff
            guard let response = response else {
                /// error usually means no results found
                newRequest.radius < 3000 ? self.runPOIFetch(request: newRequest) : self.endQuery()
                return
            }
            
            /// > 10 poi's should be enough for the table, otherwise re-run fetch
            if response.mapItems.count < 10 && newRequest.radius < 3000 {   self.runPOIFetch(request: newRequest); return }
            
            for item in response.mapItems {

                if item.pointOfInterestCategory != nil && item.name != nil {

                    self.spotLoaded = true
                    let phone = item.phoneNumber ?? ""
                    let coordinate = item.placemark.coordinate
                    let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distanceFromImage = itemLocation.distance(from: CLLocation(latitude: self.postLocation.latitude, longitude: self.postLocation.longitude))
                    
                    let item = POI(name: item.name!, coordinate: item.placemark.coordinate, distance: distanceFromImage, type: item.pointOfInterestCategory!, phone: phone)
                    if item.name.count > 60 { item.name = String(item.name.prefix(60))}
                    
                    /// check if already appended to spots - very rare
                    if !self.isDuplicateNearby(poi: item) {
                        self.nearbyIDs.append((id: item.id, distance: distanceFromImage))
                        self.nearbyPOIs.append(item)
                    }
                }
                
                if item == response.mapItems.last { self.endQuery() }
            }
        }
    }
    
    func getNearbySpots() {
        
        circleQuery = geoFirestore.query(withCenter: GeoPoint(latitude: postLocation.latitude, longitude: postLocation.longitude), radius: 0.5)
        let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)

        let _ = circleQuery?.observeReady { [weak self] in
            
            guard let self = self else { return }
            self.queryReady = true
            
            if self.nearbyEnteredCount == 0 {
                self.endQuery()
            } else if self.noAccessCount + self.nearbySpots.count == self.nearbyEnteredCount {
                self.endQuery()
            }
        }
    }
    
    func loadSpotFromDB(key: String?, location: CLLocation?) {
        
        
        if nearbySpots.contains(where: {$0.id == key}) { return }
        guard let spotKey = key else { return }
        guard let coordinate = location?.coordinate else { return }
        
        nearbyEnteredCount += 1
        
        let ref = db.collection("spots").document(spotKey)
         ref.getDocument { [weak self] (doc, err) in
            
            guard let self = self else { return }

            do {
                
                let unwrappedInfo = try doc?.data(as: MapSpot.self)
                guard var spotInfo = unwrappedInfo else { self.noAccessCount += 1; self.accessEscape(); return }

                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                                
                if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? [], mapVC: self.mapVC) {
                    
                    self.spotLoaded = true
                    
                    /// remove from POIs if this POI has been made into a spot. save the POI description in case unvisited by current user
                    
                    /// remove any duplicate POIs and store description if necessary
                    let POIdescription = self.removeDuplicates(spot: spotInfo)
                                                            
                    let distanceFromImage = location!.distance(from: CLLocation(latitude: self.postLocation.latitude, longitude: self.postLocation.longitude))
                    spotInfo.distance = distanceFromImage
                    
                    spotInfo.friendVisitors = self.getFriendVisitors(visitorList: spotInfo.visitorList)
                                               
                    self.nearbySpotsRef.append(spotInfo) /// append with basic info for async comparison before entering closure
                    
                    /// show friends image/description or blank spot if user doesn't have access to any content at a public spot
                    if spotInfo.privacyLevel == "public" && !self.isFriends(id: spotInfo.founderID) {
                        spotInfo.spotDescription = POIdescription; spotInfo.imageURL = ""
                    }
                    
                    if spotInfo.privacyLevel != "public" {
                        spotInfo.visiblePosts = spotInfo.postIDs.count
                        self.nearbyIDs.append((id: spotInfo.id!, distance: distanceFromImage))
                        self.nearbySpots.append(spotInfo)
                        self.accessEscape()
                        return
                    }
                    
                    var visiblePosts = 0
                    let friendImageFromFounder = self.isFriends(id: spotInfo.founderID)
                    var friendImage = friendImageFromFounder
                    var postFetchID = ""
                   
                    /// error handling for failed transaction where postPrivacies and postIDs dont
                    if spotInfo.postIDs.count != 0 && spotInfo.postPrivacies.count == spotInfo.postIDs.count {

                        for i in 0 ... spotInfo.postIDs.count - 1 {
                            
                            let isFriend = self.isFriends(id: spotInfo.posterIDs[safe: i] ?? "xxxxx") /// is this a friend or a public stranger post
                            let postPrivacy = spotInfo.postPrivacies[safe: i] ?? "friends"
                            
                            if postPrivacy == "public" || isFriend {
                                visiblePosts += 1
                                
                                if postFetchID == "" {
                                    /// set postFetchID for first visible post
                                    postFetchID = spotInfo.postIDs[i]
                                    friendImage = isFriend
                                    
                                } else if !friendImage && isFriend {
                                    /// always show first friend image if possible
                                    postFetchID = spotInfo.postIDs[i]
                                    friendImage = true
                                }
                            }
                        }
                    }
                        
                    
                    spotInfo.visiblePosts = visiblePosts
                    spotInfo.friendImage = friendImageFromFounder
                    spotInfo.postFetchID = postFetchID
                    
                    if spotInfo.imageURL == "" {
                        
                        /// edge case where async return causes poi query to run after getting the spotObject but before cycling through posts and altering the description / imageURL
                        if let nearbyDuplicate = self.nearbySpotsRef.last(where: {$0.id == spotInfo.id}) {
                            spotInfo.spotDescription = nearbyDuplicate.spotDescription
                        }
                    }
                    
                    if !self.nearbySpots.contains(where: {$0.id == spotInfo.id}) {
                        
                        /// friends with public spot owner, append to nearby spots and end query
                        if spotInfo.friendImage {
                            self.nearbyIDs.append((id: spotInfo.id!, distance: distanceFromImage))
                            self.nearbySpots.append(spotInfo)
                            self.accessEscape()
                            return
                        }
                        
                        self.nearbyIDs.append((id: spotInfo.id!, distance: distanceFromImage))

                        /// get friends image and description if available for public spot
                        if spotInfo.postFetchID != "" {
                            var newSpot = spotInfo
                            
                            self.db.collection("posts").document(newSpot.postFetchID).getDocument { (doc, err) in
                                
                                do {
                                    
                                    let postInfo = try doc?.data(as: MapPost.self)
                                    guard let post = postInfo else { self.nearbySpots.append(spotInfo); self.accessEscape(); return }
                                    
                                    newSpot.spotDescription = post.caption
                                    newSpot.imageURL = post.imageURLs.first ?? ""
                                    self.nearbySpots.append(newSpot)
                                    self.accessEscape()
                                    
                                } catch {
                                    self.nearbySpots.append(spotInfo); self.accessEscape(); return}
                            }
                            
                        } else { self.nearbySpots.append(spotInfo); self.accessEscape() }
                    } else { self.noAccessCount += 1; self.accessEscape(); return }

                } else { self.noAccessCount += 1; self.accessEscape(); return }
            } catch { self.noAccessCount += 1; self.accessEscape(); return }
         }
    }
    
    func accessEscape() {
        if noAccessCount + nearbySpots.count == nearbyEnteredCount && queryReady { endQuery() }
    }

    func endQuery() {
        
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading

        nearbyIDs.sort(by: {$0.distance < $1.distance})

        DispatchQueue.main.async { [weak self] in

            guard let self = self else { return }
        
            if !self.spotLoaded {
                self.addEmptyView()
                
            } else if self.emptyView != nil {
                self.emptyView.isHidden = true
                self.emptyView = nil
            }
            
            self.nearbyTable.reloadData()
            
            if self.nearbyIndicator != nil { self.nearbyIndicator.stopAnimating() }
            
            return
        }
    }
    
    func addEmptyView() {
        self.emptyView = UIView(frame: CGRect(x: 0, y: 30, width: UIScreen.main.bounds.width, height: 20))
        self.emptyView.backgroundColor = nil
        self.nearbyTable.addSubview(self.emptyView)
        
        let emptyLabel = UILabel(frame: CGRect(x: 14, y: 0, width: UIScreen.main.bounds.width - 28, height: 14))
        emptyLabel.text = "None nearby. Try searching or creating a new spot"
        emptyLabel.textColor = UIColor(red: 0.454, green: 0.454, blue: 0.454, alpha: 1)
        emptyLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        emptyLabel.numberOfLines = 0
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.sizeToFit()
        self.emptyView.addSubview(emptyLabel)
    }
    
    func isFriends(id: String) -> Bool {
        if id == uid || mapVC.friendIDs.contains(where: {$0 == id}) { return true }
        return false
    }
    
    func getFriendVisitors(visitorList: [String]) -> Int {
        var friendCount = 0
        for visitor in visitorList {
            if isFriends(id: visitor) { friendCount += 1 }
        }
        return friendCount
    }
    
    @objc func keyboardWillShow(_ sender: NSNotification) {
        if let keyboardFrame: NSValue = sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height
            let resultsHeight = UIScreen.main.bounds.height - (searchBarContainer.frame.maxY + 50) - keyboardHeight
            
            resultsTable.frame = CGRect(x: resultsTable.frame.minX, y: resultsTable.frame.minY, width: resultsTable.frame.width, height: resultsHeight)
        }
    }

        
    @objc func maskTap(_ sender: UITapGestureRecognizer) {
        for sub in infoMask.subviews {
            sub.removeFromSuperview()
        }
        infoMask.removeFromSuperview()
    }
    
    @objc func newSpotTap(_ sender: UIButton) {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "UploadPost") as? UploadPostController {
            
            Mixpanel.mainInstance().track(event: "ChooseSpotNewSpot")
            vc.postLocation = postLocation
            vc.postDate = postDate
            vc.selectedImages = selectedImages
            vc.frameIndexes = frameIndexes
            
            vc.postType = .newSpot
            vc.mapVC = mapVC
            
            vc.imageFromCamera = locationPickerVC.imageFromCamera
            vc.draftID = locationPickerVC.draftID

            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ChooseSpotController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0:
            return nearbyIDs.count > 35 ? 35 : nearbyIDs.count
        default:
            return queryIDs.count > 5 ? 5 : queryIDs.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotCell") as? ChooseSpotCell {
            let id = nearbyIDs[indexPath.row].id
            if let spot = nearbySpots.first(where: {$0.id == id}) { cell.setUp(spot: spot) }
            if let poi = nearbyPOIs.first(where: {$0.id == id}) { cell.setUp(POI: poi) }
            return cell
            
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SpotSearch") as! SpotSearchCell
            cell.backgroundColor = UIColor(named: "SpotBlack") /// in case returning blank we want it to blend in with background rather than be white
            guard let id = queryIDs[safe: indexPath.row] else { return cell }
            if let spot = querySpots.first(where: {$0.id == id.id}) { cell.setUp(spot: spot) }
            if let poi = queryPOIs.first(where: {$0.id == id.id}) { cell.setUp(POI: poi) }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ChooseSpotHeader") as? ChooseSpotHeader {
            header.setUp()
            return header
        } else { return UITableViewHeaderFooterView() }
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.tag == 0 ? 66 : 60
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        switch tableView.tag {

        case 0:
            if !spotLoaded && emptyView != nil { return 57 }
            return 27

        default:
            return 0
        }
    }
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "UploadPost") as? UploadPostController {
            
                        
            vc.postLocation = postLocation
            vc.postDate = postDate
            vc.selectedImages = selectedImages
            vc.frameIndexes = frameIndexes
            vc.mapVC = mapVC
            
            vc.imageFromCamera = locationPickerVC.imageFromCamera
            vc.draftID = locationPickerVC.draftID
            
            var imageTransition = false
                        
            switch tableView.tag {
            
                case 0:
                    let id = nearbyIDs[indexPath.row].id
                    
                    if let spotObject = nearbySpots.first(where: {$0.id! == id}) {
                        
                        Mixpanel.mainInstance().track(event: "ChooseSpotSpotSelected", properties: ["POI": false])
                        
                        vc.spotObject = spotObject
                        vc.postType = spotObject.privacyLevel == "public" ? .postToPublic : .postToPrivate

                        if spotObject.imageURL == "" {
                            imageTransition = true
                            transitionFromImage(tableView: tableView, indexPath: indexPath, vc: vc)
                        }
                        
                    } else if let POI = nearbyPOIs.first(where: {$0.id == id}) {
                        /// if no image on spot, animate transition
                        
                        Mixpanel.mainInstance().track(event: "ChooseSpotSpotSelected", properties: ["POI": true])

                        vc.poi = POI
                        vc.postType = .postToPOI
                        imageTransition = true
                        transitionFromImage(tableView: tableView, indexPath: indexPath, vc: vc)
                    }
                    
                case 1:
                    let id = queryIDs[indexPath.row].id

                    if let spotObject = querySpots.first(where: {$0.id! == id}) {
                        
                        Mixpanel.mainInstance().track(event: "ChooseSpotSearchSpotSelected", properties: ["POI": false])
                        
                        vc.spotObject = spotObject
                        vc.postType = spotObject.privacyLevel == "public" ? .postToPublic : .postToPrivate
                        
                        if spotObject.imageURL == "" {
                            imageTransition = true
                            transitionFromImage(tableView: tableView, indexPath: indexPath, vc: vc)
                        }
                        
                    } else if let POI = queryPOIs.first(where: {$0.id == id}) {
                        
                        Mixpanel.mainInstance().track(event: "ChooseSpotSearchSpotSelected", properties: ["POI": true])

                        /// if no image on spot, animate transiton
                        vc.poi = POI
                        vc.postType = .postToPOI
                        imageTransition = true
                        transitionFromImage(tableView: tableView, indexPath: indexPath, vc: vc)
                    }
                    
                default: return
            }
            
            if !imageTransition { navigationController?.pushViewController(vc, animated: true) }
        }
    }
    
    func transitionFromImage(tableView: UITableView, indexPath: IndexPath, vc: UIViewController) {
        
        tableView.isUserInteractionEnabled = false

        // animate from nearby
        if let cell = tableView.cellForRow(at: indexPath) as? ChooseSpotCell {
            UIView.transition(with: cell.thumbnailImage,
                              duration: 0.6,
                              options: .transitionFlipFromRight,
                              animations: {
                                cell.thumbnailImage.image = self.selectedImages.first ?? UIImage()
                              }, completion: { [weak self] _ in
                                guard let self = self else { return }
                                
                                self.navigationController?.pushViewController(vc, animated: true)
                                    tableView.reloadData()
                                    tableView.isUserInteractionEnabled = true
                              })
            
        // animate from search
        } else if let cell = tableView.cellForRow(at: indexPath) as? SpotSearchCell {
            UIView.transition(with: cell.thumbnailImage,
                              duration: 0.6,
                              options: .transitionFlipFromRight,
                              animations: {
                                cell.thumbnailImage.image = self.selectedImages.first ?? UIImage()
                              }, completion: { [weak self] _ in
                                guard let self = self else { return }
                                
                                self.navigationController?.pushViewController(vc, animated: true)
                                    tableView.reloadData()
                                    tableView.isUserInteractionEnabled = true
                              })
        }
    }
    
}

extension ChooseSpotController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        UIView.animate(withDuration: 0.1) {
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 93, height: self.searchBar.frame.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.cancelButton.isHidden = false
            self.resultsTable.isHidden = false
            self.searchIndicator.isHidden = true
            self.nearbyTable.isHidden = true
            if self.nearbyIndicator != nil { self.nearbyIndicator.isHidden = true }
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        self.searchBar.text = ""
        emptyQueries()
        
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: self.searchBar.frame.minY, width: UIScreen.main.bounds.width - 28, height: self.searchBar.frame.height)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
            self.resultsTable.isHidden = true
            self.nearbyTable.isHidden = false
            self.nearbyTable.reloadData()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
      
        self.searchTextGlobal = searchText
        emptyQueries()
        resultsTable.reloadData()
        
        if searchBar.text == "" { self.searchIndicator.stopAnimating(); return }
        if !self.searchIndicator.isAnimating() { self.searchIndicator.startAnimating() }
        
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runQuery), object: nil)
        self.perform(#selector(runQuery), with: nil, afterDelay: 0.65)
    }
    
    @objc func runQuery() {
        
        emptyQueries()
        resultsTable.reloadData()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.runPOIQuery(searchText: self.searchTextGlobal)
            self.runSpotsQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func runPOIQuery(searchText: String) {
                
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: postLocation!, latitudinalMeters: 5000, longitudinalMeters: 5000)
        search.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .carRental, .evCharger, .parking, .police, .restroom])
        
        let searcher = MKLocalSearch(request: search)
        searcher.start { [weak self] response, error in
            
            guard let self = self else { return }
            if error != nil { self.reloadResultsTable(searchText: searchText) }
            if !self.queryValid(searchText: searchText) { return }
            guard let response = response else { self.reloadResultsTable(searchText: searchText); return }
            
            var index = 0
            for item in response.mapItems {
                if item.name != nil {
                    
                    let phone = item.phoneNumber ?? ""
                    let coordinate = item.placemark.coordinate
                    let address = item.placemark.addressFormatter(number: false)
                    let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distanceFromImage = itemLocation.distance(from: CLLocation(latitude: self.postLocation.latitude, longitude: self.postLocation.longitude))
                    
                    let poi = POI(name: item.name!, coordinate: item.placemark.coordinate, distance: distanceFromImage, type: item.pointOfInterestCategory ?? MKPointOfInterestCategory(rawValue: ""), phone: phone, address: address)
                    if poi.name.count > 60 { poi.name = String(poi.name.prefix(60)) }
                    
                    if !self.queryValid(searchText: searchText) { return }
                    
                    /// check to make sure there's no public spot existing for this POI
                    self.isDuplicateQuery(poi: poi) { [weak self] (duplicate) in
                        
                        guard let self = self else { return }
                        if !self.queryValid(searchText: searchText) { return }
                        
                        if !duplicate {
                            /// give preference to POI's that fit the normal category criteria
                            let multiplier: Double = item.pointOfInterestCategory == nil || self.isLowRankPOI(category: item.pointOfInterestCategory ?? MKPointOfInterestCategory(rawValue: "")) ? 250 : 1000
                            self.queryIDs.append((id: poi.id, score: multiplier/distanceFromImage))
                            self.queryPOIs.append(poi)
                        }
                        
                        index += 1
                        if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                    }
                    
                } else {
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                }
            }
        }
    }
    
    func isLowRankPOI(category: MKPointOfInterestCategory) -> Bool {
        return !searchFilters.contains(category)
    }
        
    func runSpotsQuery(searchText: String) {
                
        let spotsRef = db.collection("spots")
        let spotsQuery = spotsRef.whereField("searchKeywords", arrayContains: searchText.lowercased()).limit(to: 10)
                
        spotsQuery.getDocuments { [weak self] (snap, err) in
                        
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { return }
            
            if docs.count == 0 { self.reloadResultsTable(searchText: searchText) }

            for doc in docs {
                
                do {
                    /// get all spots that match query and order by distance
                    let spotInfo = try doc.data(as: MapSpot.self)
                    guard var info = spotInfo else { return }
                    info.id = doc.documentID
                    
                    if self.hasPOILevelAccess(creatorID: info.founderID, privacyLevel: info.privacyLevel, inviteList: info.inviteList ?? [], mapVC: self.mapVC) {
                                                    
                        let location = CLLocation(latitude: info.spotLat, longitude: info.spotLong)
                        let distanceFromImage = location.distance(from: CLLocation(latitude: self.postLocation.latitude, longitude: self.postLocation.longitude))
                        info.distance = distanceFromImage
                        self.querySpotsRef.append(info)
                    }
                    
                    if doc == docs.last {
                        self.querySpotsRef.sort(by: {$0.distance < $1.distance})
                        self.getSpotScores(searchText: searchText)
                    }
                    
                } catch { if doc == docs.last {
                    self.getSpotScores(searchText: searchText) }; return }
            }
        }
    }
    
    func getSpotScores(searchText: String) {
        
        /// get detailed data for the 10 closest spots then sort on composite score
        if !self.queryValid(searchText: searchText) { return }
        let topSpots = querySpotsRef.count > 10 ? Array(querySpotsRef.prefix(10)) : querySpotsRef
        
        for spot in topSpots {
            
            var newSpot = spot
            var scoreMultiplier: Double = 1000
            var POIdescription = ""
            
            if spot.privacyLevel == "public" {
                if let i = self.queryPOIs.firstIndex(where: {$0.name == spot.spotName}) {
                    
                    POIdescription = self.queryPOIs[i].type.toString()
                    self.queryIDs.removeAll(where: {$0.id == self.queryPOIs[i].id})
                    self.queryPOIs.remove(at: i)
                    
                    /// try to match on phone number in case of slightly off strings, changed names
                } else if spot.phone?.count ?? 0 > 1, let i = self.queryPOIs.firstIndex(where: {$0.phone == spot.phone}) {
                    POIdescription = self.queryPOIs[i].type.toString()
                    self.queryIDs.removeAll(where: {$0.id == self.queryPOIs[i].id})
                    self.queryPOIs.remove(at: i)
                }
            }
            
            let friendVisitors = self.getFriendVisitors(visitorList: spot.visitorList)
            if friendVisitors > 0 { scoreMultiplier += Double((200 + friendVisitors * 50)) }
            
            if spot.privacyLevel == "public" && !self.isFriends(id: spot.founderID) {
                newSpot.spotDescription = POIdescription; newSpot.imageURL = ""
            }
            
            let friendImageFromFounder = spot.privacyLevel != "public" || isFriends(id: spot.founderID)
            var friendImage = friendImageFromFounder
            var postFetchID = ""
            
            if spot.postIDs.count != 0 && spot.postPrivacies.count == spot.postIDs.count {

                for i in 0 ... spot.postIDs.count - 1 {
                    
                    let isFriend = self.isFriends(id: spot.posterIDs[safe: i] ?? "xxxxx") /// is this a friend or a public stranger post
                    let postPrivacy = spot.postPrivacies[safe: i] ?? "friends"

                    if postPrivacy == "public" || isFriend {
                        
                        scoreMultiplier += 20
                        
                        if postFetchID == "" {
                            /// set postFetchID for first visible post
                            postFetchID = spot.postIDs[i]
                            friendImage = isFriend
                            
                        } else if !friendImage && isFriend {
                            /// always show first friend image if possible
                            postFetchID = spot.postIDs[i]
                            friendImage = true
                        }
                    }
                }
            }
                
            newSpot.friendImage = friendImageFromFounder
            newSpot.postFetchID = postFetchID
            
            if postFetchID == "" {
                
                /// edge case where async return causes poi query to run after getting the spotObject but before cycling through posts and altering the description / imageURL
                if let nearbyDuplicate = self.nearbySpotsRef.last(where: {$0.id == newSpot.id}) {
                    newSpot.spotDescription = nearbyDuplicate.spotDescription
                }
            }
            
            if !self.querySpots.contains(where: {$0.id == newSpot.id}) {
                self.querySpots.append(newSpot)
                self.queryIDs.append((id: spot.id!, score: scoreMultiplier/spot.distance))
            }
            
            if self.querySpots.count == topSpots.count { self.reloadResultsTable(searchText: searchText) }
        }
    }
    
    
    func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }

    func reloadResultsTable(searchText: String) {

        searchRefreshCount += 1
        if searchRefreshCount < 2 { return }
        
        queryIDs.sort(by: {$0.score > $1.score})
        let topIDs = queryIDs.prefix(5)
        var counter = 0

        if topIDs.count == 0 { finishResultsLoad() }
        
        for id in topIDs {
            
            if let i = self.querySpots.firstIndex(where: {$0.id == id.id}) {
                /// fetch friend image / description for spot on search
                let spot = self.querySpots[i]
                
                if spot.friendImage { counter += 1; if counter == topIDs.count { finishResultsLoad() } }
                
                if spot.postFetchID != "" {
                    
                    var newSpot = spot
                    self.db.collection("posts").document(spot.postFetchID).getDocument { [weak self] (doc, err) in
                        
                        guard let self = self else { return }
                        if searchText != self.searchTextGlobal { return } /// text changed while in fetch

                        do {
                            
                            let postInfo = try doc?.data(as: MapPost.self)
                            guard let info = postInfo else { counter += 1; if counter == topIDs.count { self.finishResultsLoad()}; return }
                            
                            newSpot.spotDescription = info.caption
                            newSpot.imageURL = info.imageURLs.first ?? ""
                            self.querySpots[i] = newSpot
                            counter += 1; if counter == topIDs.count { self.finishResultsLoad() }
                            
                        } catch { counter += 1; if counter == topIDs.count { self.finishResultsLoad()} }
                    }
                }
                
            } else {
                counter += 1; if counter == topIDs.count { finishResultsLoad() }
            }
        }
    }
    
    func finishResultsLoad() {
        DispatchQueue.main.async {
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
        }
    }
    
    func emptyQueries() {
        searchRefreshCount = 0
        queryIDs.removeAll()
        querySpotsRef.removeAll()
        querySpots.removeAll()
        queryPOIs.removeAll()
        searchManager.cancelAll()
    }
            
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.resignFirstResponder()
    }
}

class ChooseSpotCell: UITableViewCell {
    
    var topLine: UIView!
    var thumbnailImage: UIImageView!
    var friendCount: UILabel!
    var friendIcon: UIImageView!
    var postCount: UILabel!
    var postIcon: UIImageView!
    var spotName: UILabel!
    var descriptionLabel: UILabel!
    var locationIcon: UIImageView!
    var distanceLabel: UILabel!
    
    func setUp(spot: MapSpot) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        addSubview(topLine)
        
        thumbnailImage = UIImageView(frame: CGRect(x: 14, y: 11, width: 44, height: 44))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        addSubview(thumbnailImage)
        
        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            thumbnailImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        } else {
            /// adjust cell to look like POI cell
            thumbnailImage.image = UIImage(named: "POIIcon")
            thumbnailImage.frame = CGRect(x: 12, y: 10, width: 46, height: 46)
        }
        
        var spotNameY: CGFloat = 15
        var minX = thumbnailImage.frame.maxX + 10
        
        if spot.friendVisitors > 0 {
            friendCount = UILabel(frame: CGRect(x: minX, y: 7, width: 30, height: 16))
            friendCount.text = String(spot.friendVisitors)
            friendCount.textColor = UIColor(named: "SpotGreen")
            friendCount.font = UIFont(name: "SFCamera-Regular", size: 13)
            friendCount.sizeToFit()
            addSubview(friendCount)
            
            friendIcon = UIImageView(frame: CGRect(x: friendCount.frame.maxX + 3, y: 10, width: 12, height: 10))
            friendIcon.image = UIImage(named: "FriendCountIcon")
            addSubview(friendIcon)
            
            minX = friendIcon.frame.maxX + 10
        }
        
        if spot.visiblePosts > 0 {
            /// move spot name down if icons are added (friends will never be added without posts)
            spotNameY = 24
            
            postCount = UILabel(frame: CGRect(x: minX, y: 7, width: 30, height: 16))
            postCount.text = String(spot.visiblePosts)
            postCount.textColor = UIColor(red: 0.688, green: 0.688, blue: 0.688, alpha: 1)
            postCount.font = UIFont(name: "SFCamera-Regular", size: 13)
            postCount.sizeToFit()
            addSubview(postCount)
            
            postIcon = UIImageView(frame: CGRect(x: postCount.frame.maxX + 3, y: 11, width: 9.86, height: 9.5))
            postIcon.image = UIImage(named: "PostCountIcon")
            addSubview(postIcon)
        }
                
        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 10, y: spotNameY, width: UIScreen.main.bounds.width - (thumbnailImage.frame.maxX + 72), height: 16))
        spotName.text = spot.spotName
        spotName.lineBreakMode = .byTruncatingTail
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        addSubview(spotName)
        
        if spot.spotDescription != "" {
            descriptionLabel = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 10, y: spotName.frame.maxY + 1, width: UIScreen.main.bounds.width - 72, height: 16))
            descriptionLabel.text = spot.spotDescription
            descriptionLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
            descriptionLabel.font = UIFont(name: "SFCamera-Regular", size: 11)
            descriptionLabel.lineBreakMode = .byTruncatingTail
            addSubview(descriptionLabel)
            
        } else {
            /// adjust other info to center
            spotName.frame = CGRect(x: spotName.frame.minX, y: spotName.frame.minY + 8, width: spotName.frame.width, height: spotName.frame.height)
            if friendCount != nil { friendCount.frame = CGRect(x: friendCount.frame.minX, y: friendCount.frame.minY + 8, width: friendCount.frame.width, height: friendCount.frame.height) }
            if friendIcon != nil { friendIcon.frame = CGRect(x: friendIcon.frame.minX, y: friendIcon.frame.minY + 8, width: friendIcon.frame.width, height: friendIcon.frame.height) }
            if postCount != nil { postCount.frame = CGRect(x: postCount.frame.minX, y: postCount.frame.minY + 8, width: postCount.frame.width, height: postCount.frame.height) }
            if postIcon != nil { postIcon.frame = CGRect(x: postIcon.frame.minX, y: postIcon.frame.minY + 8, width: postIcon.frame.width, height: postIcon.frame.height) }
        }
        
        locationIcon = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 58, y: 22, width: 7, height: 10))
        locationIcon.image = UIImage(named: "DistanceIcon")
        addSubview(locationIcon)
        
        distanceLabel = UILabel(frame: CGRect(x: locationIcon.frame.maxX + 4, y: 21, width: 50, height: 15))
        distanceLabel.text = spot.distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 10.5)
        addSubview(distanceLabel)
    }
    
    func setUp(POI: POI) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
        topLine.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        addSubview(topLine)
        
        thumbnailImage = UIImageView(frame: CGRect(x: 12, y: 10, width: 46, height: 46))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        thumbnailImage.image = UIImage(named: "POIIcon")
        addSubview(thumbnailImage)
                                
        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 10, y: 15, width: UIScreen.main.bounds.width - (thumbnailImage.frame.maxX + 72), height: 16))
        spotName.lineBreakMode = .byTruncatingTail
        spotName.text = POI.name
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        addSubview(spotName)
        
        descriptionLabel = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 10, y: spotName.frame.maxY + 1, width: UIScreen.main.bounds.width - 72, height: 16))
        descriptionLabel.text = POI.type.toString()
        descriptionLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        descriptionLabel.font = UIFont(name: "SFCamera-Regular", size: 11)
        descriptionLabel.lineBreakMode = .byTruncatingTail
        addSubview(descriptionLabel)
                
        locationIcon = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 58, y: 17, width: 7, height: 10))
        locationIcon.image = UIImage(named: "DistanceIcon")
        addSubview(locationIcon)
        
        distanceLabel = UILabel(frame: CGRect(x: locationIcon.frame.maxX + 4, y: 16, width: 50, height: 15))
        distanceLabel.text = POI.distance.getLocationString()
        distanceLabel.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 10.5)
        addSubview(distanceLabel)
    }
        
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if thumbnailImage != nil { thumbnailImage.image = UIImage() }
        if friendCount != nil { friendCount.text = "" }
        if friendIcon != nil { friendIcon.image = UIImage() }
        if postCount != nil { postCount.text = "" }
        if postIcon != nil { postIcon.image = UIImage() }
        if spotName != nil { spotName.text = "" }
        if descriptionLabel != nil { descriptionLabel.text = "" }
        if locationIcon != nil { locationIcon.image = UIImage() }
        if distanceLabel != nil { distanceLabel.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if thumbnailImage != nil { thumbnailImage.sd_cancelCurrentImageLoad() }
        if thumbnailImage != nil {  thumbnailImage.image = UIImage() }
    }
}

class ChooseSpotHeader: UITableViewHeaderFooterView {
    
    var label: UILabel!
    
    func setUp() {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        if label != nil { label.text = "" }
        label = UILabel(frame: CGRect(x: 14, y: 0, width: 150, height: 22))
        label.text = "Nearby spots"
        label.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        label.font = UIFont(name: "SFCamera-Regular", size: 13)
        label.sizeToFit()
        addSubview(label)
        
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpotSearchCell: UITableViewCell {

    var thumbnailImage: UIImageView!
    var spotName: UILabel!
    var profilePic: UIImageView!
    var name: UILabel!
    var username: UILabel!
    var address: UILabel!
    var bottomLine: UIView!
    
    func setUp(spot: MapSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        thumbnailImage = UIImageView(frame: CGRect(x: 18, y: 7, width: 36, height: 36))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        addSubview(thumbnailImage)

        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            thumbnailImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        } else {
            /// adjust cell to look like POI cell
            thumbnailImage.image = UIImage(named: "POIIcon")
            thumbnailImage.frame = CGRect(x: 16, y: 5, width: 38, height: 38)
        }

        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: 15, width: 250, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCamera-Regular", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
    }
    
    func setUp(POI: POI) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        thumbnailImage = UIImageView(frame: CGRect(x: 16, y: 7, width: 38, height: 38))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        thumbnailImage.image = UIImage(named: "POIIcon")
        addSubview(thumbnailImage)

        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: 9, width: UIScreen.main.bounds.width - 84, height: 16))
        spotName.lineBreakMode = .byTruncatingTail
        spotName.text = POI.name
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        addSubview(spotName)

        address = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 12, y: spotName.frame.maxY + 1, width: UIScreen.main.bounds.width - 84, height: 16))
        address.text = POI.address
        address.textColor = UIColor(red: 0.608, green: 0.608, blue: 0.608, alpha: 1)
        address.font = UIFont(name: "SFCamera-Regular", size: 12)
        address.lineBreakMode = .byTruncatingTail
        addSubview(address)
    }
    
    
    func setUpSpot(spot: ResultSpot) {
        
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()

        thumbnailImage = UIImageView(frame: CGRect(x: 18, y: 12, width: 36, height: 36))
        thumbnailImage.layer.cornerRadius = 4
        thumbnailImage.layer.masksToBounds = true
        thumbnailImage.clipsToBounds = true
        thumbnailImage.contentMode = .scaleAspectFill
        addSubview(thumbnailImage)
        
        let url = spot.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            thumbnailImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        
        spotName = UILabel(frame: CGRect(x: thumbnailImage.frame.maxX + 8, y: 22, width: 250, height: 16))
        spotName.text = spot.spotName
        spotName.font = UIFont(name: "SFCamera-Regular", size: 13)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
    }
        
    func setUpUser(user: UserProfile) {

        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 18, y: 12, width: 36, height: 36))
        profilePic.layer.cornerRadius = 18
        profilePic.clipsToBounds = true
        profilePic.layer.masksToBounds = true
        profilePic.contentMode = .scaleAspectFill
        addSubview(profilePic)

        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        name = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 12, width: 250, height: 20))
        name.text = user.name
        name.font = UIFont(name: "SFCamera-Semibold", size: 13)
        name.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        name.sizeToFit()
        addSubview(name)
        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: name.frame.maxY + 1, width: 250, height: 20))
        username.text = user.username
        username.font = UIFont(name: "SFCamera-Regular", size: 13)
        username.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1)
        username.sizeToFit()
        addSubview(username)
    }
    
    func setUpCity(cityName: String) {

        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none
        
        resetCell()
        
        spotName = UILabel(frame: CGRect(x: 28.5, y: 22, width: 250, height: 16))
        spotName.text = cityName
        spotName.font = UIFont(name: "SFCamera-Semibold", size: 15)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.sizeToFit()
        addSubview(spotName)
        
        bottomLine = UIView(frame: CGRect(x: 14, y: 64, width: UIScreen.main.bounds.width - 28, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1)
        addSubview(bottomLine)
    }
    
    func resetCell() {
        if thumbnailImage != nil { thumbnailImage.image = UIImage() }
        if spotName != nil {spotName.text = ""}
        if profilePic != nil {profilePic.image = UIImage()}
        if name != nil {name.text = ""}
        if username != nil {username.text = ""}
        if address != nil { address.text = "" }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if thumbnailImage != nil { thumbnailImage.sd_cancelCurrentImageLoad(); thumbnailImage.image = UIImage() }
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}

extension MKPointOfInterestCategory {
    
    func toString() -> String {
        
        /// convert POI type into readable string
        var text = rawValue
        var counter = 13
        while counter > 0 { text = String(text.dropFirst()); counter -= 1 }
        
        /// insert space in POI type if necessary
        counter = 0
        var uppercaseIndex = 0
        for letter in text {if letter.isUppercase && counter != 0 { uppercaseIndex = counter }; counter += 1}
        if uppercaseIndex != 0 { text.insert(" ", at: text.index(text.startIndex, offsetBy: uppercaseIndex)) }

        return text
    }
}

extension ChooseSpotController {
    // helper functions
    
    func locationsClose(coordinate1: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> Bool {
        /// run to ensure that this is actually the same spot and not just one with the same name
        if abs(coordinate1.latitude - coordinate2.latitude) + abs(coordinate1.longitude - coordinate2.longitude) < 0.01 { return true }
        return false
    }
    
    func isDuplicateNearby(poi: POI) -> Bool {
        
        var duplicate = false
        
        if let i = self.nearbySpotsRef.firstIndex(where: {$0.spotName == poi.name}) {
            
            let spot = self.nearbySpotsRef[i]
            if spot.privacyLevel == "public" && locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) { duplicate = true }
            
            if spot.imageURL == "" { self.nearbySpotsRef[i].spotDescription = poi.type.toString() }

        } else if poi.phone.count > 1, let i = self.nearbySpotsRef.firstIndex(where: {$0.phone == poi.phone}) {
            
            let spot = self.nearbySpotsRef[i]
            if spot.privacyLevel == "public" && locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) { duplicate = true }
            
                if spot.imageURL == "" { self.nearbySpotsRef[i].spotDescription = poi.type.toString() }
            }

        return duplicate
    }
    
    func isDuplicateQuery(poi: POI, completion: @escaping (_ duplicate: Bool) -> Void) {
                
        if let i = querySpotsRef.firstIndex(where: {$0.spotName == poi.name}) {
            
            let spot = querySpotsRef[i]
            
            if spot.privacyLevel == "public" && locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) {
                
                if spot.imageURL == "" { querySpotsRef[i].spotDescription = poi.type.toString() }
                completion(true); return
            }
        }
        
        if poi.phone.count > 1, let i = querySpotsRef.firstIndex(where: {$0.phone == poi.phone}) {
            let spot = querySpotsRef[i]
            
            if spot.privacyLevel == "public" && locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) {
                
                if querySpotsRef[i].imageURL == "" { querySpotsRef[i].spotDescription = poi.type.toString() }
                completion(true); return
            }
        }
        /// need to check database in case apple maps query returned something but spot names didnt
        let query = db.collection("spots").whereField("spotName", isEqualTo: poi.name)
        query.getDocuments { [weak self] (snap, err) in
            
            if snap?.documents.count ?? 0 > 0 {
                
                guard let snap = snap else { return }
                guard let self = self else { return }
                
                for doc in snap.documents {
                    do {
                        
                        let spotInfo = try doc.data(as: MapSpot.self)
                        guard let spot = spotInfo else { completion(false); return }
                        
                        if spot.privacyLevel == "public" && self.locationsClose(coordinate1: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), coordinate2: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)) {
                            completion(true); return
                        }

                        if doc == snap.documents.last { completion(false); return }

                    } catch { completion(false); return }
                }
            } else { completion(false); return }
        }
    }

    func removeDuplicates(spot: MapSpot) -> String {
        
        var POIDescription = ""
        
        if spot.privacyLevel == "public" {
            
            /// try first to match on spot name + location
            if let i = nearbyPOIs.firstIndex(where: {$0.name == spot.spotName}) {

                let poi = nearbyPOIs[i]
                if locationsClose(coordinate1: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude), coordinate2: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)) {

                    POIDescription = nearbyPOIs[i].type.toString()
                    nearbyIDs.removeAll(where: {$0.id == poi.id})
                    nearbyPOIs.remove(at: i)
                }
            
            /// try to match on phone number in case of slightly off strings, changed names
            } else if spot.phone?.count ?? 0 > 1, let i = nearbyPOIs.firstIndex(where: {$0.phone == spot.phone}) {
                
                let poi = nearbyPOIs[i]
                if locationsClose(coordinate1: CLLocationCoordinate2D(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude), coordinate2: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)) {

                    POIDescription = nearbyPOIs[i].type.toString()
                    nearbyIDs.removeAll(where: {$0.id == poi.id})
                    nearbyPOIs.remove(at: i)
                }
            }
        }

        return POIDescription
    }
}
