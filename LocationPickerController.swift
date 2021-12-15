//
//  LocationPickerController.swift
//  Spot
//
//  Created by kbarone on 9/14/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation
import MapKit
import Photos
import Mixpanel
import Geofirestore
import FirebaseUI

protocol LocationPickerDelegate {
    func finishPassingLocationPicker(spot: MapSpot)
    func locationPickerNewSpotTap()
}

class LocationPickerController: UIViewController {
    
    var mapView: MKMapView!
    var searchContainer: UIView!
    var delegate: LocationPickerDelegate?

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    let db = Firestore.firestore()
    lazy var imageManager = SDWebImageManager()

    var frameIndexes: [Int] = []

    var galleryLocation: CLLocation!
    var postDate: Date!
    var imageFromCamera = false
    var draftID: Int64!
    
    var addressText = ""
    
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var searchIndicator: CustomActivityIndicator!
    var addressLabel: UILabel!
    
    var resultsTable: UITableView!
    var nearbyTable: UITableView!
    
    var pan: UIPanGestureRecognizer!
        
    var regionQuery: GFSRegionQuery?
    
    var shouldUpdateRegion = false
    var shouldCluster = false
    var firstTimeGettingLocation = true
        
    lazy var searchTextGlobal = ""
    lazy var searchRefreshCount = 0
    lazy var querySpots: [MapSpot] = []
    
    var postAnnotation: CustomPointAnnotation!
    var nearbyAnnotations = [String: CustomSpotAnnotation]()
        
    var passedLocation: CLLocation!
    var spotName = ""
    
    var navBarHeight: CGFloat = 88
    var localSearch: MKLocalSearch!
    
    let searchFilters: [MKPointOfInterestCategory] = [.airport, .amusementPark, .aquarium, .bakery, .beach, .brewery, .cafe, .campground, .foodMarket, .library, .marina, .museum, .movieTheater, .nightlife, .nationalPark, .park, .restaurant, .store, .school, .stadium, .theater, .university, .winery, .zoo]
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    deinit {

        if mapView != nil {
            let annotations = mapView.annotations
            mapView.removeAnnotations(annotations)
            mapView.delegate = nil
            mapView.removeFromSuperview()
            mapView = nil
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        }
        
        NotificationCenter.default.removeObserver(self, name: Notification.Name("UpdateLocation"), object: nil)
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        
        Mixpanel.mainInstance().track(event: "LocationPickerSearchOpen")
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCurrentLocation(_:)), name: Notification.Name("UpdateLocation"), object: nil)
    }
    
    func setUpViews() {
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "+ New Spot", style: .plain, target: self, action: #selector(newSpotTap(_:)))
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "SpotGreen")!, NSAttributedString.Key.font : UIFont(name: "SFCamera-Semibold", size: 15)!], for: .normal)
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        /// was having an issue with autolayout not recognizing the navigation bar so extending view under opaque bars

        addMapView()
    }
    
    func addMapView() {
        
        mapView = MKMapView(frame: CGRect(x: 0, y: navBarHeight, width: UIScreen.main.bounds.width, height: 240))
        
        mapView.isUserInteractionEnabled = true
        mapView.userLocation.title = ""
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = true
        mapView.userLocation.title = ""
        mapView.tintColor = .systemBlue
        mapView.register(LocationPickerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "Profile")
        DispatchQueue.main.async { self.view.addSubview(self.mapView) }
        
        mapView.delegate = self
                
        addSearch()

        /// map tap will allow user to set the location of the post by tapping the map
        let mapTap = UITapGestureRecognizer(target: self, action: #selector(mapTap(_:)))
        mapTap.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(mapTap)
    }
    
    func setUpNavBar() {
        
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addShadow()
        navigationController?.navigationBar.addGradientBackground(alpha: 1.0)

        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        navigationItem.backBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .selected)
        
        navigationItem.title = "Choose a spot"
    }
    
    func addSearch() {

        searchContainer = UIView(frame: CGRect(x: 0, y: navBarHeight + 200, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - navBarHeight - 200))
        searchContainer.backgroundColor = UIColor(named: "SpotBlack")
        DispatchQueue.main.async { self.view.addSubview(self.searchContainer) }

        searchBarContainer = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 60))
        searchBarContainer.backgroundColor = nil
        searchBarContainer.layer.cornerRadius = 8
        DispatchQueue.main.async { self.searchContainer.addSubview(self.searchBarContainer) }
        
        searchBar = UISearchBar(frame: CGRect(x: 14, y: 18, width: UIScreen.main.bounds.width - 68, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.tintColor = .white
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = " Search for spots"
        searchBar.searchTextField.font = UIFont(name: "SFCamera-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        DispatchQueue.main.async { self.searchBarContainer.addSubview(self.searchBar) }
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 70, y: 19, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1), for: .normal)
        cancelButton.alpha = 0.8
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 16)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.isHidden = true
        DispatchQueue.main.async { self.searchBarContainer.addSubview(self.cancelButton)}
        
        let nearbyLabel = UILabel(frame: CGRect(x: 18, y: searchBarContainer.frame.maxY + 8, width: 100, height: 20))
        nearbyLabel.text = "Spots nearby"
        nearbyLabel.textColor = UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        nearbyLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        DispatchQueue.main.async { self.searchBarContainer.addSubview(nearbyLabel) }
        
        addressLabel = UILabel(frame: CGRect(x: 123, y: searchBarContainer.frame.maxY + 10.5, width: UIScreen.main.bounds.width - 134, height: 18))
        addressLabel.text = addressText
        addressLabel.textColor = UIColor(red: 0.235, green: 0.235, blue: 0.235, alpha: 1)
        addressLabel.font = UIFont(name: "SFCamera-Semibold", size: 12)
        addressLabel.lineBreakMode = .byTruncatingTail
        DispatchQueue.main.async { self.searchBarContainer.addSubview(self.addressLabel) }
        
        nearbyTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY + 40, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - searchContainer.frame.minY - 100))
        nearbyTable.backgroundColor = .black
        nearbyTable.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 50, right: 0)
        nearbyTable.showsVerticalScrollIndicator = false
        nearbyTable.separatorStyle = .none
        nearbyTable.dataSource = self
        nearbyTable.delegate = self
        nearbyTable.tag = 0
        nearbyTable.register(LocationPickerSpotCell.self, forCellReuseIdentifier: "ChooseSpotCell")
        DispatchQueue.main.async { self.searchContainer.addSubview(self.nearbyTable) }
        
        /// results table unhidden when search bar is interacted with - update with keyboard height
        resultsTable = UITableView(frame: CGRect(x: 0, y: searchBarContainer.frame.maxY + 10, width: UIScreen.main.bounds.width, height: 400))
        resultsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.backgroundColor = .black
        resultsTable.separatorStyle = .none
        resultsTable.showsVerticalScrollIndicator = false
        resultsTable.isHidden = true
        resultsTable.register(LocationPickerSpotCell.self, forCellReuseIdentifier: "ChooseSpotCell")
        resultsTable.tag = 1
        
        searchIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 30))
        searchIndicator.isHidden = true
        resultsTable.addSubview(searchIndicator)
        DispatchQueue.main.async { self.searchContainer.addSubview(self.resultsTable) }

        pan = UIPanGestureRecognizer(target: self, action: #selector(closeTable(_:)))
    }

    
    func loadNearbySpots() {
        // run circle query to get nearby spots
        let radius = self.mapView.currentRadius()
        
        if !self.nearbyAnnotations.isEmpty { filterSpots() }
        
        if locationIsEmpty(location: UserDataModel.shared.currentLocation) || radius == 0 || radius > 6000 { return }
        
        regionQuery = geoFirestore.query(inRegion: mapView.region)
        DispatchQueue.global(qos: .userInitiated).async { let _ = self.regionQuery?.observe(.documentEntered, with: self.loadSpotFromDB) }
    }
    
    func loadNearbyPOIs() {
        
        if localSearch != nil { localSearch.cancel() }
        
        let searchRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude), radius: mapView.currentRadius())
        
        /// these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
        let filters = MKPointOfInterestFilter(including: searchFilters)
        searchRequest.pointOfInterestFilter = filters
        
        runPOIFetch(request: searchRequest)
    }
    
    func runPOIFetch(request: MKLocalPointsOfInterestRequest) {
                
        localSearch = MKLocalSearch(request: request)
        localSearch.start { [weak self] response, error in

            guard let self = self else { return }
            
            let newRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: request.coordinate.latitude, longitude: request.coordinate.longitude), radius: request.radius * 2)
            newRequest.pointOfInterestFilter = request.pointOfInterestFilter
            
            guard let response = response else { return }
            
            for item in response.mapItems {

                if item.pointOfInterestCategory != nil && item.name != nil {

                    if UploadImageModel.shared.nearbySpots.contains(where: {$0.spotName == item.name || $0.phone == item.phoneNumber ?? ""}) { continue }
                    
                    let coordinate = item.placemark.coordinate
                    let itemLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distanceFromImage = itemLocation.distance(from: CLLocation(latitude: request.coordinate.latitude, longitude: request.coordinate.longitude))
                    
                    var item = POI(name: item.name!, coordinate: item.placemark.coordinate, distance: distanceFromImage, type: item.pointOfInterestCategory!, phone: "")
                    if item.name.count > 60 { item.name = String(item.name.prefix(60))}
                
                    let annotation = CustomSpotAnnotation()
                    annotation.coordinate = item.coordinate
                    annotation.rank = 0.01
                    
                    var spotInfo = MapSpot(spotDescription: item.type.toString(), spotName: item.name, spotLat: item.coordinate.latitude, spotLong: item.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    spotInfo.phone = item.phone
                    spotInfo.poiCategory = item.type.toString()
                    
                    let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                    let postLocation = CLLocation(latitude: self.postAnnotation.coordinate.latitude, longitude: self.postAnnotation.coordinate.longitude)
                    spotInfo.distance = postLocation.distance(from: spotLocation)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                    
                    annotation.spotInfo = spotInfo
                    
                    let hidden = self.mapView.spotFilteredByLocation(spotCoordinates: item.coordinate)
                    self.nearbyAnnotations.updateValue(annotation, forKey: item.id)
                    UploadImageModel.shared.nearbySpots.append(spotInfo)
                    
                    if !hidden {
                        self.nearbyAnnotations[item.id]?.isHidden = false
                        DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
                    }

                }
            }
        }

    }

    func loadSpotFromDB(key: String?, location: CLLocation?) {

        // 1. check that marker isn't already shown on map
        if key == nil || key == "" || self.nearbyAnnotations.contains(where: {$0.key == key}) { return }

        // 2. prepare new marker -> load all spot-level data needed, ensure user has privacy level access
        let annotation = CustomSpotAnnotation()
        guard let coordinate = location?.coordinate else { return }
        annotation.coordinate = coordinate
        
        self.db.collection("spots").document(key!).getDocument { [weak self] (spotSnap, err) in
            
            guard let doc = spotSnap else { return }
            guard let self = self else { return }
            
            do {
                
                let spotIn = try doc.data(as: MapSpot.self)
                guard var spotInfo = spotIn else { return }
                
                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                
                /// set spot description to friends' name (founder) or POI level category info
                if spotInfo.privacyLevel != "public" {
                    spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                    
                } else {
                    spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                }

                if !self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) { return }
                if self.nearbyAnnotations.contains(where: {$0.value.spotInfo.spotName == spotInfo.spotName}) { return }
                                
                let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                let postLocation = CLLocation(latitude: self.postAnnotation.coordinate.latitude, longitude: self.postAnnotation.coordinate.longitude)
                spotInfo.distance = postLocation.distance(from: spotLocation)
                spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                    
                annotation.spotInfo = spotInfo
                annotation.title = spotInfo.spotName

                /// POI already loaded to map, replace with real spot object - remove from everywhere first
                if let index = self.nearbyAnnotations.firstIndex(where: {$0.value.spotInfo.spotName == spotInfo.spotName || ($0.value.spotInfo.phone ?? "" == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "")}) {
                    
                    let anno = self.nearbyAnnotations[index]
                    self.mapView.removeAnnotation(anno.value)

                    UploadImageModel.shared.nearbySpots.removeAll(where: {$0.id == self.nearbyAnnotations[index].value.spotInfo.id})
                    self.nearbyAnnotations.remove(at: index)
                }
                
                UploadImageModel.shared.nearbySpots.append(annotation.spotInfo)
                
                /// if spot isnt already out of frame, load to map
                if self.mapView.spotFilteredByLocation(spotCoordinates: CLLocationCoordinate2D(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)) {
                    self.loadSpotToMap(annotation: annotation, id: key ?? "", hidden: true)
                } else {
                    self.loadSpotToMap(annotation: annotation, id: key ?? "", hidden: false)
                }
            } catch {
                return
            }
        }
    }
    
    func loadSpotToMap(annotation: CustomSpotAnnotation, id: String, hidden: Bool) {
        
        if !nearbyAnnotations.contains(where: {$0.key == id}) {
                                    
            let rank = getMapRank(spot: annotation.spotInfo)
            annotation.rank = rank
            nearbyAnnotations.updateValue(annotation, forKey: id)

            if !hidden {
                self.nearbyAnnotations[id]?.isHidden = false
                DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
            }
        }
    }

    func filterSpots() {
        
        for anno in nearbyAnnotations {
            
            if mapView.spotFilteredByLocation(spotCoordinates: anno.value.coordinate) {
                DispatchQueue.main.async {
                    anno.value.isHidden = true
                    self.mapView.removeAnnotation(anno.value)
                }
                continue
                
            } else if anno.value.isHidden {
                /// check if we're adding it back on search page reappear or filter values changed
                DispatchQueue.main.async {
                    anno.value.isHidden = false
                    self.mapView.addAnnotation(anno.value)
                }
            }
        }
    }
        
    @objc func keyboardWillShow(_ sender: NSNotification) {
        if let keyboardFrame: NSValue = sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height
            let resultsHeight = view.bounds.height - 95 - keyboardHeight
            
            resultsTable.frame = CGRect(x: resultsTable.frame.minX, y: resultsTable.frame.minY, width: resultsTable.frame.width, height: resultsHeight)
        }
    }
    
    @objc func notifyCurrentLocation(_ sender: NSNotification) {
        if !firstTimeGettingLocation { return }
        addAnnotations()
        loadNearbySpots()
        loadNearbyPOIs()
    }
    
    // set location on tap
    @objc func mapTap(_ sender: UITapGestureRecognizer) {
        
        Mixpanel.mainInstance().track(event: "LocationPickerChangePostLocation")
        
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
    
        postAnnotation.coordinate = coordinate
        UploadImageModel.shared.tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocodeAddress(coordinate: coordinate)
        
        sortAndReloadNearby(coordinate: coordinate)
    }
    
    func sortAndReloadNearby(coordinate: CLLocationCoordinate2D) {
        
        /// resort based on new annotation location
        if UploadImageModel.shared.nearbySpots.count == 0 { return }
        UploadImageModel.shared.resortSpots(coordinate: coordinate)
        DispatchQueue.main.async { self.nearbyTable.reloadSections(IndexSet(0...0), with: .fade)}
    }
        
    func geocodeAddress(coordinate: CLLocationCoordinate2D) {
        reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] (addy) in
            guard let self = self else { return }
            DispatchQueue.main.async { self.setAddress(address: addy) }
        }
    }
            
    func setAddress(address: String) {

        addressText = address
        if addressLabel == nil { return }
        addressLabel.text = address
    }
    
    @objc func newSpotTap(_ sender: UIBarButtonItem) {
        delegate?.locationPickerNewSpotTap()
        navigationController?.popViewController(animated: false)
    }
}

extension LocationPickerController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension LocationPickerController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                
        if annotation is CustomPointAnnotation {
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "Profile") as? LocationPickerAnnotationView
            
            if annotationView == nil {
                annotationView = LocationPickerAnnotationView(annotation: annotation, reuseIdentifier: "Profile")
            } else {
                annotationView!.annotation = annotation
            }
            
            let nibView = loadUploadNib()
            annotationView!.image = nibView.asImage()
            annotationView!.sizeToFit()
            return annotationView
                            
        } else if let anno = annotation as? CustomSpotAnnotation {
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? SpotAnnotationView
            if annotationView == nil {
                annotationView = SpotAnnotationView(annotation: anno, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            } else {
                annotationView!.annotation = annotation
            }

            annotationView?.clusteringIdentifier = Bundle.main.bundleIdentifier! + ".SpotAnnotationView"
            let nibView = loadSpotNib()
            
            var spotName = ""
            if let anno = self.nearbyAnnotations.first(where: {$0.value.coordinate.latitude == annotation.coordinate.latitude && $0.value.coordinate.longitude == annotation.coordinate.longitude}) {
                spotName = anno.value.spotInfo.spotName
            }
            
            nibView.spotNameLabel.text = spotName
            
            let temp = nibView.spotNameLabel
            temp?.sizeToFit()
            nibView.resizeBanner(width: temp?.frame.width ?? 0)
            
            let nibImage = nibView.asImage()
            annotationView!.image = nibImage
            annotationView!.alpha = 0.4
            annotationView!.isUserInteractionEnabled = false
            
            return annotationView
            
        } else if annotation is MKClusterAnnotation {
            // spot banner view as cluster
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? SpotClusterView
            
            if annotationView == nil {
                annotationView = SpotClusterView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
            }
            
            else { annotationView?.annotation = annotation }
            
            annotationView!.alpha = 0.4
            annotationView!.updateImage(annotations: Array(nearbyAnnotations.values))
            annotationView!.isUserInteractionEnabled = false
            
            return annotationView
        }
        else { return nil }
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        /// disable userlocation callout on tap
        if let userView = mapView.view(for: mapView.userLocation) { userView.isEnabled = false }
        if let profileView = views.first(where: {$0 is LocationPickerAnnotationView}) { mapView.bringSubviewToFront(profileView) } /// bring profile in front of other spots
    }
    
    
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        if !locationIsEmpty(location: UserDataModel.shared.currentLocation) && firstTimeGettingLocation { addAnnotations() }
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
        if shouldUpdateRegion {
        
            shouldUpdateRegion = false
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                
                guard let self = self else { return }
                
                self.shouldUpdateRegion = true
                if !mapView.region.IsValid { return }
                
                if self.regionQuery != nil {
                    /// active query on regionQuery, re-run local search for nearbyPOIs
                    self.regionQuery?.region = mapView.region
                    self.loadNearbyPOIs()
                    
                } else {
                    self.loadNearbySpots()
                    self.loadNearbyPOIs()
                }
                
                self.filterSpots()
            }
        }
    }
    
    func addAnnotations() {
        
        firstTimeGettingLocation = false
        addFromPassedLocation()
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
            ///run on delay to avoid updating region immediately on open
            guard let self = self else { return }
            self.shouldUpdateRegion = true
        }
    }
    
    func animateToSelectedLocation(coordinate: CLLocationCoordinate2D) {
        
        let adjustedCenter = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.0004, longitude: coordinate.longitude)
        let camera = MKMapCamera(lookingAtCenter: adjustedCenter, fromDistance: 1000, pitch: 0, heading: 0)

        DispatchQueue.main.async {
            self.mapView.camera = camera
            self.mapView.addAnnotation(self.postAnnotation)
        }
        
        geocodeAddress(coordinate: coordinate)
        return
    }
    
    
    func addPassedSpots(coordinate: CLLocationCoordinate2D) {
        
        if !UploadImageModel.shared.nearbySpots.isEmpty {
            
            /// resort for choose spot table
            UploadImageModel.shared.resortSpots(coordinate: coordinate)
            
            /// add annotations
            for i in 0...UploadImageModel.shared.nearbySpots.count - 1 {
                
                guard let spot = UploadImageModel.shared.nearbySpots[safe: i] else { continue }
                if spot.id == "" { continue }
                let annotation = CustomSpotAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
                
                annotation.spotInfo = spot
                let rank = getMapRank(spot: annotation.spotInfo)
                annotation.rank = rank
                nearbyAnnotations.updateValue(annotation, forKey: spot.id!)
                
                DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
            }
        }
        
        DispatchQueue.main.async { self.nearbyTable.reloadData() }
    }
        
    func addFromPassedLocation() {
        
        let selectedCoordinate = CLLocationCoordinate2D(latitude: passedLocation.coordinate.latitude, longitude: passedLocation.coordinate.longitude)
        postAnnotation = CustomPointAnnotation()
        postAnnotation.coordinate = selectedCoordinate
    
        self.addPassedSpots(coordinate: selectedCoordinate)
        self.animateToSelectedLocation(coordinate: selectedCoordinate)
    }
        
    func loadSpotNib() -> MapTarget {
        let infoWindow = MapTarget.instanceFromNib() as! MapTarget
        infoWindow.clipsToBounds = true
        infoWindow.spotNameLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        infoWindow.spotNameLabel.numberOfLines = 2
        infoWindow.spotNameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        infoWindow.spotNameLabel.lineBreakMode = .byWordWrapping
        
        return infoWindow
    }
    
    func loadUploadNib() -> UploadAnnotationWindow {
        
        let infoWindow = UploadAnnotationWindow.instanceFromNib() as! UploadAnnotationWindow
        infoWindow.clipsToBounds = true
        return infoWindow
    }
}

// extensions for handling location search


extension LocationPickerController: UISearchBarDelegate, MKLocalSearchCompleterDelegate, UITableViewDelegate, UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0:
            if postAnnotation == nil { return 0 }
            return min(UploadImageModel.shared.nearbySpots.count, 25)
        default:
            return min(querySpots.count, 7)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotCell") as? LocationPickerSpotCell else { return UITableViewCell() }
        let spot = tableView.tag == 0 ? UploadImageModel.shared.nearbySpots[indexPath.row] : querySpots[indexPath.row]
        cell.tag = tableView.tag
        cell.setUp(spot: spot)
        return cell
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.tag == 0 ? 62 : 53
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let spot = tableView.tag == 0 ? UploadImageModel.shared.nearbySpots[indexPath.row] : querySpots[indexPath.row]
        delegate?.finishPassingLocationPicker(spot: spot)
        navigationController?.popViewController(animated: false)
    }
    

    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.endEditing(true)
    }
    
    @objc func searchButtonTap(_ sender: UIButton) {
        searchBar.becomeFirstResponder()
    }
    
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        openSearch()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        closeSearch()
    }
        
    func openSearch() {
        
        resultsTable.addGestureRecognizer(pan)
        
        cancelButton.alpha = 0.0
        cancelButton.isHidden = false
        resultsTable.alpha = 0.0
        resultsTable.isHidden = false
                
        UIView.animate(withDuration: 0.15) {
            self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: self.navBarHeight, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
            self.searchBar.frame = CGRect(x: 16, y: 18, width: UIScreen.main.bounds.width - 106, height: 36)
            self.cancelButton.alpha = 1.0
            self.resultsTable.alpha = 1.0
            self.nearbyTable.alpha = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.isHidden = true
            self.nearbyTable.isHidden = true
            self.nearbyTable.alpha = 1.0
        }
    }
    
    func closeSearch() {
        
        resultsTable.removeGestureRecognizer(pan)
        
        self.nearbyTable.alpha = 0.0
        self.nearbyTable.isHidden = false

        UIView.animate(withDuration: 0.15) {
            self.searchContainer.frame = CGRect(x: self.searchContainer.frame.minX, y: self.navBarHeight + 200, width: self.searchContainer.frame.width, height: self.searchContainer.frame.height)
            self.searchBar.frame = CGRect(x: 14, y: 18, width: UIScreen.main.bounds.width - 68, height: 36)
            self.resultsTable.alpha = 0.0
            self.cancelButton.alpha = 0.0
            self.nearbyTable.alpha = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.resultsTable.reloadData()
            self.resultsTable.isHidden = true
            self.resultsTable.alpha = 1.0
            self.cancelButton.isHidden = true
            self.cancelButton.alpha = 1.0
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
      
        self.searchTextGlobal = searchText
        emptyQueries()
        DispatchQueue.main.async { self.resultsTable.reloadData() }
        
        if searchBar.text == "" { self.searchIndicator.stopAnimating(); return }
        if !self.searchIndicator.isAnimating() { self.searchIndicator.startAnimating() }
        
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runQuery), object: nil)
        self.perform(#selector(runQuery), with: nil, afterDelay: 0.65)
    }
    
    @objc func runQuery() {
        
        emptyQueries()
        DispatchQueue.main.async { self.resultsTable.reloadData() }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.runPOIQuery(searchText: self.searchTextGlobal)
            self.runSpotsQuery(searchText: self.searchTextGlobal)
        }
    }
    
    func emptyQueries() {
        searchRefreshCount = 0
        querySpots.removeAll()
    }
    
    func runPOIQuery(searchText: String) {
        
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: mapView.centerCoordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        search.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .carRental, .evCharger, .parking, .police])
        
        let searcher = MKLocalSearch(request: search)
        searcher.start { [weak self] response, error in
            
            guard let self = self else { return }
            if error != nil { self.reloadResultsTable(searchText: searchText) }
            if !self.queryValid(searchText: searchText) { return }
            guard let response = response else { self.reloadResultsTable(searchText: searchText); return }
            
            var index = 0
            
            for item in response.mapItems {

                if item.name != nil {

                    if self.querySpots.contains(where: {$0.spotName == item.name || ($0.phone ?? "" == item.phoneNumber ?? "" && item.phoneNumber ?? "" != "")}) { index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }
                                        
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    
                    spotInfo.phone = item.phoneNumber ?? ""
                    spotInfo.id = UUID().uuidString
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    
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
                    let info = try doc.data(as: MapSpot.self)
                    guard var spotInfo = info else { return }
                    spotInfo.id = doc.documentID
                    
                    if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                        
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

        DispatchQueue.main.async {
            self.resultsTable.reloadData()
            self.searchIndicator.stopAnimating()
        }
    }
    
    func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }
    
    @objc func closeOnTap(_ sender: UITapGestureRecognizer) {
        searchBar.endEditing(true)
    }
    
    @objc func closeTable(_ sender: UIPanGestureRecognizer) {
        
        let velocity = sender.velocity(in: view)
        let translation = sender.translation(in: view)
        
        if abs(translation.y) > abs(translation.x) && velocity.y > 100 {
            searchBar.endEditing(true)
        }
    }
}

