//
//  ChooseSpotController.swift
//  Spot
//
//  Created by Kenny Barone on 7/12/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Geofirestore
import MapKit
import Mixpanel

protocol ChooseSpotDelegate {
    func finishPassing(spot: MapSpot?)
}

class ChooseSpotController: UIViewController {
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var tableView: UITableView!
    var createSpotButton: CreateSpotButton!
    
    lazy var spotObjects: [MapSpot] = []
    lazy var querySpots: [MapSpot] = []
    
    var searchRefreshCount = 0
    var spotSearching = false
    var queried = false
    var searchTextGlobal = ""
    
    /// nearby spot fetch variables
    let db = Firestore.firestore()
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var circleQuery: GFSCircleQuery?
    var search: MKLocalSearch!
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]

    var cancelOnDismiss = false
    var queryReady = true
    
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyRefreshCount = 0
    var appendCount = 0
    
    var postLocation: CLLocation!
    var delegate: ChooseSpotDelegate?
    unowned var previewVC: ImagePreviewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
        setInitialValues()
        runChooseSpotFetch()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ChooseSpotOpen")
    }
    
    func setUpView() {
        view.backgroundColor = .white
        searchBarContainer = UIView {
            $0.backgroundColor = .white
            view.addSubview($0)
        }
        searchBarContainer.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(20)
            $0.height.equalTo(50)
        }
        
        searchBar = UISearchBar {
            $0.frame = CGRect(x: 16, y: 6, width: UIScreen.main.bounds.width - 32, height: 36)
            $0.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
            $0.searchTextField.backgroundColor = UIColor(red: 0.945, green: 0.945, blue: 0.949, alpha: 1)
            $0.searchTextField.leftView?.tintColor = UIColor(red: 0.396, green: 0.396, blue: 0.396, alpha: 1)
            $0.delegate = self
            $0.autocapitalizationType = .none
            $0.autocorrectionType = .no
            $0.placeholder = " Search"
            $0.clipsToBounds = true
            $0.layer.cornerRadius = 3
            $0.returnKeyType = .done
            $0.keyboardDistanceFromTextField = 250
            searchBarContainer.addSubview($0)
        }
        searchBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(6)
            $0.height.equalTo(36)
        }
        
        tableView = UITableView {
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
            $0.backgroundColor = .white
            $0.separatorStyle = .none
            $0.delegate = self
            $0.dataSource = self
            $0.showsVerticalScrollIndicator = false
            $0.register(ChooseSpotCell.self, forCellReuseIdentifier: "ChooseSpot")
            $0.register(ChooseSpotLoadingCell.self, forCellReuseIdentifier: "ChooseSpotLoading")
            view.addSubview($0)
        }
        tableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(searchBarContainer.snp.bottom)
            $0.bottom.equalToSuperview()
        }
        
        createSpotButton = CreateSpotButton {
            $0.addTarget(self, action: #selector(createSpotTap(_:)), for: .touchUpInside)
            view.addSubview($0)
        }
        createSpotButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(60)
            $0.height.equalTo(54)
            $0.width.equalTo(180)
            $0.centerX.equalToSuperview()
        }
    }
    
    func setInitialValues() {
        postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)      
        if UploadPostModel.shared.spotObject != nil { spotObjects.append(UploadPostModel.shared.spotObject!) }
    }
    
    @objc func createSpotTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "ChooseSpotCreateTap")
        DispatchQueue.main.async {
            self.delegate?.finishPassing(spot: nil)
            self.dismiss(animated: true)
        }
    }
}

extension ChooseSpotController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        searchTextGlobal = searchText
        emptySpotQueries()
        DispatchQueue.main.async { self.tableView.reloadData() }
        
        if queried {
            runSpotSearch(searchText: searchText)
        } else {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runSpotQuery), object: nil)
        }
    }
    
    func runChooseSpotFetch() {
        /// called initially and also after an image is selected
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() } /// shows loading indicator
        
        queryReady = false
        nearbyEnteredCount = 0 /// total number of spots in the circle query
        noAccessCount = 0 /// no privacy access ct
        appendCount = 0 /// spots appended on this fetch
        nearbyRefreshCount = 0 /// incremented once with POI load, once with Spot load
        
        getNearbySpots()
        getNearbyPOIs()
    }

    func getNearbyPOIs() {
        
        if search != nil { search.cancel() }
        let searchRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong), radius: 200)
                
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
            
            let newRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong), radius: request.radius * 2)
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
                    if self.spotObjects.contains(where: {$0.spotName == name || ($0.phone ?? "" == phone && phone != "")}) { index += 1; if index == response.mapItems.count { self.endQuery() }; continue }
                    
                    var spotInfo = MapSpot(founderID: "", imageURL: "", privacyLevel: "public", spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, spotName: name)
                    spotInfo.phone = phone
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    spotInfo.id = UUID().uuidString
                    
                    let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                    let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
                    
                    spotInfo.distance = postLocation.distance(from: spotLocation)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                                        
                    self.spotObjects.append(spotInfo)
                                                                    
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                    
                } else {
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                }
            }
        }
    }
    
    
    func getNearbySpots() {
        
        let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
        
        circleQuery = geoFirestore.query(withCenter: postLocation, radius: 0.5)
        let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)
        
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
        
        guard let spotKey = key else { accessEscape(); return }
        
        nearbyEnteredCount += 1
        
        getSpot(spotID: spotKey) { spot in
            if spot == nil { self.noAccessCount += 1; self.accessEscape(); return }
            var spotInfo = spot!
            
            if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
                let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                
                spotInfo.distance = spotLocation.distance(from: postLocation)
                spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                
                if spotInfo.privacyLevel != "public" {
                    spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                    
                } else {
                    spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                }
                
                /// replace POI with actual spot object if object already added
                /// Use phone number for second degree matching
                if let i = self.spotObjects.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                    spotInfo.selected = self.spotObjects[i].selected
                    self.spotObjects[i] = spotInfo
                    self.spotObjects[i].poiCategory = nil
                    self.noAccessCount += 1; self.accessEscape(); return
                }
                
                self.appendCount += 1
                self.spotObjects.append(spotInfo)
                self.accessEscape()
                return
                
            } else { self.noAccessCount += 1; self.accessEscape(); return }
        }
    }

    
    func accessEscape() {
        if noAccessCount + appendCount == nearbyEnteredCount && queryReady { endQuery() }
        return
    }
    
    func endQuery() {
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        spotObjects.sort(by: {!$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected!})
        
        circleQuery?.removeAllObservers()
        circleQuery = nil
        
        search = nil
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    // search funcs
    
    func runSpotSearch(searchText: String) {
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runSpotQuery), object: nil)
        self.perform(#selector(runSpotQuery), with: nil, afterDelay: 0.4)
    }
    
    @objc func runSpotQuery() {
        
        emptySpotQueries()
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.runPOIQuery(searchText: self.searchTextGlobal)
            self.runNearbyQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func emptySpotQueries() {
        spotSearching = false
        searchRefreshCount = 0
        querySpots.removeAll()
    }
    
    func runPOIQuery(searchText: String) {
    
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: postLocation.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        search.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .carRental, .evCharger, .parking, .police])
        
        let searcher = MKLocalSearch(request: search)
        searcher.start { [weak self] response, error in
            
            guard let self = self else { return }
            if error != nil { self.reloadResultsTable(searchText: searchText) }
            if !self.queryValid(searchText: searchText) { self.spotSearching = false; return }
            guard let response = response else { self.reloadResultsTable(searchText: searchText); return }
            
            var index = 0
            
            for item in response.mapItems {

                if item.name != nil {

                    /// spot was already appended for this POI
                    if self.querySpots.contains(where: {$0.spotName == item.name || ($0.phone ?? "" == item.phoneNumber ?? "" && item.phoneNumber ?? "" != "")}) { index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }
                                        
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                    var spotInfo = MapSpot(founderID: "", imageURL: "", privacyLevel: "public", spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, spotName: name)
                    
                    spotInfo.phone = item.phoneNumber ?? ""
                    spotInfo.id = UUID().uuidString
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))
                    
                    self.querySpots.append(spotInfo)
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                    
                } else {
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                }
                
            }
        }

    }

    func runNearbyQuery(searchText: String) {
        
        let spotsRef = db.collection("spots")
        let spotsQuery = spotsRef.whereField("searchKeywords", arrayContains: searchText.lowercased()).limit(to: 10)
                
        spotsQuery.getDocuments { [weak self] (snap, err) in
                        
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { self.spotSearching = false; return }
            
            if docs.count == 0 { self.reloadResultsTable(searchText: searchText) }

            for doc in docs {

                do {
                    /// get all spots that match query and order by distance
                    let info = try doc.data(as: MapSpot.self)
                    guard var spotInfo = info else { return }
                    spotInfo.id = doc.documentID
                    
                    if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                        
                        spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))

                        for visitor in spotInfo.visitorList {
                            if UserDataModel.shared.userInfo.friendIDs.contains(visitor) { spotInfo.friendVisitors += 1 }
                        }


                        if spotInfo.privacyLevel != "public" {
                            spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                            
                        } else {
                            spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                        }
                        
                        /// replace duplicate POI with correct spotObject
                        if let i = self.querySpots.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                            self.querySpots[i] = spotInfo
                            self.querySpots[i].poiCategory = nil
                        } else {
                            self.querySpots.append(spotInfo)
                        }
                    }
                    
                    if doc == docs.last {
                        self.reloadResultsTable(searchText: searchText)
                    }
                    
                } catch { if doc == docs.last {
                    self.reloadResultsTable(searchText: searchText) }; return }
            }
        }
    }
    
    func reloadResultsTable(searchText: String) {
        searchRefreshCount += 1
        if searchRefreshCount < 2 { return }
        
        querySpots.sort(by: {$0.distance < $1.distance})
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func queryValid(searchText: String) -> Bool {
        /// check that search text didnt change and "spots" seg still selected
        return searchText == searchTextGlobal && searchText != ""
    }
}

extension ChooseSpotController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return spotSearching ? 1 : queried ? querySpots.count : spotObjects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let current = queried ? querySpots : spotObjects

        if indexPath.row < current.count {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpot", for: indexPath) as? ChooseSpotCell {
                cell.setUp(spot: current[indexPath.row])
                return cell
            }
            
        } else {
            /// loading indicator for spot search
            if let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotLoading", for: indexPath) as? ChooseSpotLoadingCell {
                cell.setUp()
                return cell
            }
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "ChooseSpotSelect")
        let current = queried ? querySpots : spotObjects
        let spot = current[indexPath.row]
        DispatchQueue.main.async {
            self.searchBar.resignFirstResponder()
            self.delegate?.finishPassing(spot: spot)
            self.dismiss(animated: true) {
                print("cancel false")
                self.previewVC?.cancelOnDismiss = false
            }
        }
    }
}

class CreateSpotButton: UIButton {
    var createLabel: UILabel!
    var spotIcon: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 18
        backgroundColor = UIColor(named: "SpotGreen")
        
        createLabel = UILabel {
            $0.text = "Create spot"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16.5)
            addSubview($0)
        }
        createLabel.snp.makeConstraints {
            $0.leading.equalTo(22)
            $0.centerY.equalToSuperview()
        }
        
        spotIcon = UIImageView {
            $0.image = UIImage(named: "NewSpotIcon")
            addSubview($0)
        }
        spotIcon.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(25.5)
            $0.width.equalTo(35)
            $0.centerY.equalToSuperview().offset(-1)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class ChooseSpotCell: UITableViewCell {
    
    var topLine: UIView!
    var spotName: UILabel!
    var descriptionLabel: UILabel!
    
    var separatorView: UIView!
    var distanceLabel: UILabel!
    var postsLabel: UILabel!
    
    var spotID = ""
    
    func setUp(spot: MapSpot) {
        selectionStyle = .none
        backgroundColor = spot.selected! ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.4) : .white
        spotID = spot.id!
        
        resetCell()
                
        distanceLabel = UILabel {
            $0.frame = CGRect(x: UIScreen.main.bounds.width - 113.25, y: 21, width: 100, height: 15)
            $0.text = spot.distance.getLocationString()
            $0.textAlignment = .right
            $0.textColor = UIColor(red: 0.808, green: 0.808, blue: 0.808, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 13)
            $0.sizeToFit()
            contentView.addSubview($0)
        }
        distanceLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(13)
            $0.top.equalTo(21)
            $0.height.equalTo(15)
        }

        /// tag = 1 for nearbySpots, tag = 2 for querySpots
        spotName = UILabel {
            $0.text = spot.spotName
            $0.lineBreakMode = .byTruncatingTail
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 16)
            $0.textColor = .black
            contentView.addSubview($0)
        }
        spotName.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.top.equalTo(11)
            $0.trailing.equalTo(distanceLabel.snp.leading).offset(-5)
            $0.height.equalTo(17)
        }
        
        /// add spot description - either
        if spot.spotDescription != "" {
            descriptionLabel = UILabel {
                $0.text = spot.spotDescription
                $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
                $0.lineBreakMode = .byTruncatingTail
                $0.sizeToFit()
                contentView.addSubview($0)
            }
            descriptionLabel.snp.makeConstraints {
                $0.leading.equalTo(20)
                $0.top.equalTo(spotName.snp.bottom).offset(2)
              //  $0.trailing.equalTo(distanceLabel.snp.leading).offset(-5)
            }
        }
        
        if spot.postIDs.count > 0 {
            /// if addedDescription, add separator
            if spot.spotDescription != "" {
                separatorView = UIView {
                    $0.backgroundColor = UIColor(red: 0.839, green: 0.839, blue: 0.839, alpha: 1)
                    contentView.addSubview($0)
                }
                separatorView.snp.makeConstraints {
                    $0.leading.equalTo(descriptionLabel.snp.trailing).offset(5)
                    $0.top.equalTo(descriptionLabel.snp.centerY).offset(-1)
                    $0.width.height.equalTo(3)
                }
            }
            
            var postsText = "\(spot.postIDs.count) post"
            if spot.postIDs.count > 1 { postsText += "s" }
            postsLabel = UILabel {
                $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
                $0.text = postsText
                $0.sizeToFit()
                contentView.addSubview($0)
            }
            postsLabel.snp.makeConstraints {
                if spot.spotDescription == "" {
                    $0.leading.equalTo(20)
                } else {
                    $0.leading.equalTo(separatorView.snp.trailing).offset(5)
                }
                $0.top.equalTo(spotName.snp.bottom).offset(2)
                $0.width.equalTo(100)
            }
        }
        
        /// slide spotName down if no description label
        if spot.friendVisitors == 0 && spot.spotDescription == "" { spotName.frame = CGRect(x: spotName.frame.minX, y: 19, width: spotName.frame.width, height: spotName.frame.height) }
        
        topLine = UIView {
            $0.backgroundColor = UIColor(red: 0.967, green: 0.967, blue: 0.967, alpha: 1)
            contentView.addSubview($0)
        }
        topLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }
            
    func resetCell() {
        if topLine != nil { topLine.removeFromSuperview() }
        if spotName != nil { spotName.removeFromSuperview() }
        if descriptionLabel != nil { descriptionLabel.removeFromSuperview() }
        if postsLabel != nil { postsLabel.removeFromSuperview() }
        if separatorView != nil { separatorView.removeFromSuperview() }
        if distanceLabel != nil { distanceLabel.removeFromSuperview() }
    }
}


class ChooseSpotLoadingCell: UITableViewCell {
    
    var activityIndicator: CustomActivityIndicator!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp() {
    
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
        
        activityIndicator = CustomActivityIndicator {
            $0.startAnimating()
            addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.top.equalTo(10)
            $0.width.height.equalTo(30)
        }
    }
}

