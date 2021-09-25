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
}

class LocationPickerController: UIViewController {
    
    var mapView: MKMapView!
    var searchContainer: UIView!
    var delegate: LocationPickerDelegate?

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    let db = Firestore.firestore()
    
    var spotObject: MapSpot!
    var selectedImages: [UIImage] = []
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
    var spotAnnotation: CustomSpotAnnotation!
    
    var nearbyAnnotations = [String: CustomSpotAnnotation]()
        
    var passedLocation: CLLocation!
    var secondaryLocation: CLLocation!
    var spotName = ""
    var passedAddress = ""
    
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
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)
        
        ///if came from image picker, nav bar shouldnt be translucent
        if passedLocation == nil {
            navigationController?.navigationBar.isTranslucent = false
            navigationController?.navigationBar.addShadow()
            navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
        }
    }

    
    
    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)
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
            
            guard let response = response else { print("responsenil"); return }
            
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
                    annotation.spotInfo = spotInfo
                    
                    let hidden = self.spotFilteredByLocation(spotCoordinates: item.coordinate)
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
                    spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername!)"
                    
                } else {
                    spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                }

                if !self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) { return }
                if self.nearbyAnnotations.contains(where: {$0.value.spotInfo.spotName == spotInfo.spotName}) { return }
                
                annotation.spotInfo = spotInfo
                annotation.title = spotInfo.spotName
                
                /// POI already loaded to map, replace with real spot object - remove from everywhere first
                if let index = self.nearbyAnnotations.firstIndex(where: {$0.value.spotInfo.spotName == spotInfo.spotName || $0.value.spotInfo.phone == spotInfo.phone ?? ""}) {
                    
                    let anno = self.nearbyAnnotations[index]
                    self.mapView.removeAnnotation(anno.value)

                    UploadImageModel.shared.nearbySpots.removeAll(where: {$0.id == self.nearbyAnnotations[index].value.spotInfo.id})
                    self.nearbyAnnotations.remove(at: index)
                }
                    
                UploadImageModel.shared.nearbySpots.append(annotation.spotInfo)
                
                /// if spot isnt already out of frame, load to map
                if self.spotFilteredByLocation(spotCoordinates: CLLocationCoordinate2D(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)) {
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
            
             if spotFilteredByLocation(spotCoordinates: anno.value.coordinate) {
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
    
    func spotFilteredByLocation(spotCoordinates: CLLocationCoordinate2D) -> Bool {
        let coordinates = mapView.region.boundingBoxCoordinates
        if !(spotCoordinates.latitude < coordinates[0].latitude && spotCoordinates.latitude > coordinates[2].latitude && spotCoordinates.longitude > coordinates[0].longitude && spotCoordinates.longitude < coordinates[2].longitude) {
            return true
        }
        return false
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
    }
    
    // set location on tap
    @objc func mapTap(_ sender: UITapGestureRecognizer) {
        
        Mixpanel.mainInstance().track(event: "LocationPickerChangePostLocation")
        
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        
        if postAnnotation == nil {
            spotAnnotation.coordinate = coordinate
            
        } else {
            postAnnotation.coordinate = coordinate
            UploadImageModel.shared.tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            geocodeAddress(coordinate: coordinate)
            
            sortAndReloadNearby(coordinate: coordinate)
        }
    }
    
    func sortAndReloadNearby(coordinate: CLLocationCoordinate2D) {
        
        /// resort based on new annotation location
        
        if UploadImageModel.shared.nearbySpots.count == 0 { return }
        
        /// resort based on new location
        for i in 0...UploadImageModel.shared.nearbySpots.count - 1 { UploadImageModel.shared.nearbySpots[i].spotScore = getSpotRank(spot: UploadImageModel.shared.nearbySpots[i], location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) }
        UploadImageModel.shared.nearbySpots.sort(by: {$0.spotScore > $1.spotScore})
        
        DispatchQueue.main.async { self.nearbyTable.reloadSections(IndexSet(0...0), with: .fade)}
    }
    
    func geocodeAddress(coordinate: CLLocationCoordinate2D) {
        reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] (addy) in
            guard let self = self else { return }
            self.setAddress(address: addy)
        }
    }
            
    func setAddress(address: String) {

        addressText = address
        
        if addressLabel == nil { return }
        addressLabel.text = address
    }
        
    @objc func doneTap(_ sender: UIBarButtonItem) {
        // send notification, return to spotVC
        self.navigationController?.popViewController(animated: true)
        let coordinate = postAnnotation == nil ? spotAnnotation.coordinate : postAnnotation.coordinate
        let userInfo: [String: Any] = ["coordinate": coordinate]
        let notiName = spotObject == nil ? NSNotification.Name("PostAddressChange") : NSNotification.Name("SpotAddressChange")
        NotificationCenter.default.post(Notification(name: notiName, object: nil, userInfo: userInfo))
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
            
            let nibView = loadProfileNib()
            
            let url = UserDataModel.shared.userInfo.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
                nibView.profileImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
            
            let nibImage = nibView.asImage()
            annotationView!.image = nibImage
            annotationView!.sizeToFit()
            
            annotationView!.isEnabled = true
            annotationView!.isDraggable = true
            annotationView!.isSelected = true
            annotationView!.clusteringIdentifier = nil
            
            annotationView!.centerOffset = CGPoint(x: 0, y: -15)
            return annotationView
            
        } else if let anno = annotation as? CustomSpotAnnotation {
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? SpotAnnotationView
            if annotationView == nil {
                annotationView = SpotAnnotationView(annotation: anno, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            } else {
                annotationView!.annotation = annotation
            }

            if self.shouldCluster && spotObject == nil {
                annotationView?.clusteringIdentifier = Bundle.main.bundleIdentifier! + ".SpotAnnotationView"
            } else {
                annotationView?.clusteringIdentifier = nil
            }
            
            let nibView = loadSpotNib()
            
            var spotName = ""
            if spotObject != nil { spotName = spotObject.spotName }
            else if let anno = self.nearbyAnnotations.first(where: {$0.value.coordinate.latitude == annotation.coordinate.latitude && $0.value.coordinate.longitude == annotation.coordinate.longitude}) {
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
        
        if passedLocation == nil {
            
            ///upload new
            self.addInitialAnnotation()
            
            if self.spotObject != nil {
                ///post to spot, show spot on map in addition to post annotation
                self.addSpotAnnotation(coordinate: CLLocationCoordinate2D(latitude: spotObject.spotLat, longitude: spotObject.spotLong))
            }
            
        } else {
            ///edit post / spot
            self.addFromPassedLocation()
        }
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
            ///run on delay to avoid updating region immediately on open
            guard let self = self else { return }
            self.shouldUpdateRegion = true
        }
    }
    
    func animateToSelectedLocation(coordinate: CLLocationCoordinate2D, passed: Bool) {
        
        let adjustedCenter = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.0004, longitude: coordinate.longitude)
        let camera = MKMapCamera(lookingAtCenter: adjustedCenter, fromDistance: 1000, pitch: 0, heading: 0)

        mapView.camera = camera
        
        if postAnnotation == nil {
            mapView.addAnnotation(self.spotAnnotation)
        } else {
            mapView.addAnnotation(self.postAnnotation)
        }
        
        geocodeAddress(coordinate: coordinate)
        return
    }
    
    
    func addPassedSpots(coordinate: CLLocationCoordinate2D) {
        
        for i in 0...UploadImageModel.shared.nearbySpots.count - 1 {
            
            let spot = UploadImageModel.shared.nearbySpots[i]
            
            let annotation = CustomSpotAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
            
            annotation.spotInfo = spot
            let rank = getMapRank(spot: annotation.spotInfo)
            annotation.rank = rank
            nearbyAnnotations.updateValue(annotation, forKey: spot.id!)
            
            DispatchQueue.main.async { self.mapView.addAnnotation(annotation) }
        }
                
        UploadImageModel.shared.nearbySpots.sort(by: {$0.spotScore > $1.spotScore})
        DispatchQueue.main.async { self.nearbyTable.reloadData() }
    }
    
    func addInitialAnnotation() {
        
        postAnnotation = CustomPointAnnotation()

        var lat = UserDataModel.shared.currentLocation.coordinate.latitude
        var long = UserDataModel.shared.currentLocation.coordinate.longitude
        
        /// if from gallery get image location if it exists
        if galleryLocation != nil {
            let imLat = galleryLocation.coordinate.latitude
            if imLat != 0.0 { lat = imLat }
            let imLong = galleryLocation.coordinate.longitude
            if imLong != 0.0 { long = imLong }
            
        /// use spot location if no image location and posting to spot
        } else if spotObject != nil && !imageFromCamera && lat == UserDataModel.shared.currentLocation.coordinate.latitude {
            lat = spotObject.spotLat
            long = spotObject.spotLong
        }
        
        let selectedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        postAnnotation.coordinate = selectedCoordinate
        
        self.animateToSelectedLocation(coordinate: selectedCoordinate, passed: false)
    }
    
    func addFromPassedLocation() {
        
        let selectedCoordinate = CLLocationCoordinate2D(latitude: passedLocation.coordinate.latitude, longitude: passedLocation.coordinate.longitude)
        
        if spotObject != nil {
            //edit spot, add spot annotation as primary annotation
            spotAnnotation = CustomSpotAnnotation()
            spotAnnotation.coordinate = selectedCoordinate
            spotAnnotation.title = spotObject.spotName
            
        } else {
            //edit post
            postAnnotation = CustomPointAnnotation()
            postAnnotation.coordinate = selectedCoordinate
            
            if secondaryLocation != nil {
                ///add spot annotation as secondary annotation
                self.addSpotAnnotation(coordinate: secondaryLocation.coordinate)
            }
        }
        
        self.addPassedSpots(coordinate: selectedCoordinate)
        self.animateToSelectedLocation(coordinate: selectedCoordinate, passed: true)
    }
    
    func addSpotAnnotation(coordinate: CLLocationCoordinate2D) {
        spotAnnotation = CustomSpotAnnotation()
        spotAnnotation.coordinate = coordinate
        spotAnnotation.title = spotObject == nil ? spotName : spotObject.spotName
        mapView.addAnnotation(spotAnnotation)
    }

    
    //   func mapViewdidmo
    
    func loadProfileNib() -> LocationPickerWindow {
        
        let infoWindow = LocationPickerWindow.instanceFromNib() as! LocationPickerWindow
        infoWindow.clipsToBounds = true
        
        infoWindow.profileImage.contentMode = .scaleAspectFill
        infoWindow.profileImage.layer.cornerRadius = infoWindow.profileImage.bounds.width/2
        infoWindow.profileImage.clipsToBounds = true
        infoWindow.bringSubviewToFront(infoWindow.profileImage)
                
        return infoWindow
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
}

// extensions for handling location search


extension LocationPickerController: UISearchBarDelegate, MKLocalSearchCompleterDelegate, UITableViewDelegate, UITableViewDataSource {
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0:
            return nearbyAnnotations.count > 25 ? 25 : nearbyAnnotations.count
        default:
            return querySpots.count > 7 ? 7 : querySpots.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChooseSpotCell") as? LocationPickerSpotCell else { return UITableViewCell() }
        let spot = tableView.tag == 0 ? UploadImageModel.shared.nearbySpots[indexPath.row] : querySpots[indexPath.row]
        cell.tag = tableView.tag
        if tableView.tag == 0 { cell.annotationLocation = CLLocation(latitude: postAnnotation.coordinate.latitude, longitude: postAnnotation.coordinate.longitude) }
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

                    if self.querySpots.contains(where: {$0.spotName == item.name || $0.phone == item.phoneNumber ?? ""}) { index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }
                                        
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    spotInfo.phone = item.phoneNumber ?? ""
                    spotInfo.id = UUID().uuidString
                    
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
                        print("has poi level")
                        
                        if spotInfo.privacyLevel != "public" {
                            spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername!)"
                            
                        } else {
                            spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                        }

                        self.querySpots.append(spotInfo)
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

class LocationPickerAnnotationView: MKAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LocationPickerSpotCell: UITableViewCell {
    
    var topLine: UIView!
    var spotName: UILabel!
    var descriptionLabel: UILabel!
    
    var separatorView: UIView!
    var cityLabel: UILabel!
    
    var annotationLocation: CLLocation!
    var locationIcon: UIImageView!
    var distanceLabel: UILabel!
    
    func setUp(spot: MapSpot) {
        
        self.backgroundColor = .black
        self.selectionStyle = .none
        
        resetCell()
                
        let nameY: CGFloat = tag == 0 ? 17 : 11
        spotName = UILabel(frame: CGRect(x: 18, y: nameY, width: UIScreen.main.bounds.width - 78, height: 16))
        spotName.text = spot.spotName
        spotName.lineBreakMode = .byTruncatingTail
        spotName.font = UIFont(name: "SFCamera-Regular", size: 15)
        spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        contentView.addSubview(spotName)
        
        var separatorX: CGFloat = 18
        if spot.spotDescription != "" {
            descriptionLabel = UILabel(frame: CGRect(x: 18, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - 78, height: 16))
            descriptionLabel.text = spot.spotDescription
            descriptionLabel.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            descriptionLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
            descriptionLabel.lineBreakMode = .byTruncatingTail
            descriptionLabel.sizeToFit()
            contentView.addSubview(descriptionLabel)
            
            separatorX = descriptionLabel.frame.maxX + 4
            
        } else if tag == 0 {
            /// move spot name down for nearby cell only
            spotName.frame = CGRect(x: spotName.frame.minX, y: spotName.frame.minY + 8, width: spotName.frame.width, height: spotName.frame.height)
        }
        
        if tag == 1 {
            /// add city for search cell
            if separatorX != 18 {
                separatorView = UIView(frame: CGRect(x: separatorX, y: descriptionLabel.frame.midY - 1, width: 3, height: 3))
                separatorView.backgroundColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
                separatorView.layer.cornerRadius = 1.5
                contentView.addSubview(separatorView)
                
                separatorX += 7
            }
            
            cityLabel = UILabel(frame: CGRect(x: separatorX, y: spotName.frame.maxY + 2, width: UIScreen.main.bounds.width - separatorX - 18, height: 16))
            cityLabel.text = spot.city ?? ""
            cityLabel.textColor = UIColor(red: 0.363, green: 0.363, blue: 0.363, alpha: 1)
            cityLabel.font = UIFont(name: "SFCamera-Semibold", size: 12.5)
            cityLabel.lineBreakMode = .byTruncatingTail
            contentView.addSubview(cityLabel)
            
            /// for POIs will need to fetch city here
            let localName = spot.spotName
            if cityLabel.text == "" {
                reverseGeocodeFromCoordinate(numberOfFields: 2, location: CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)) { [weak self] city in
                    guard let self = self else { return }
                    if localName == spot.spotName { self.cityLabel.text = city }
                }
            }
            
        } else {
            
            topLine = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1))
            topLine.backgroundColor = UIColor(red: 0.062, green: 0.062, blue: 0.062, alpha: 1)
            contentView.addSubview(topLine)

            /// add distance for nearby cell
            locationIcon = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 58, y: 22, width: 7, height: 10))
            locationIcon.image = UIImage(named: "DistanceIcon")?.withTintColor(UIColor(red: 0.262, green: 0.262, blue: 0.262, alpha: 1))
            contentView.addSubview(locationIcon)
            
            distanceLabel = UILabel(frame: CGRect(x: locationIcon.frame.maxX + 4, y: 21, width: 50, height: 15))
            
            let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
            let distanceFromImage = annotationLocation.distance(from: spotLocation)
            distanceLabel.text = distanceFromImage.getLocationString()
            
            distanceLabel.textColor = UIColor(red: 0.262, green: 0.262, blue: 0.262, alpha: 1)
            distanceLabel.font = UIFont(name: "SFCamera-Regular", size: 10.5)
            contentView.addSubview(distanceLabel)
        }
    }
        
    func resetCell() {
        if topLine != nil { topLine.backgroundColor = nil }
        if spotName != nil { spotName.text = "" }
        if descriptionLabel != nil { descriptionLabel.text = "" }
        if separatorView != nil { separatorView.backgroundColor = nil }
        if cityLabel != nil { cityLabel.text = "" }
        if locationIcon != nil { locationIcon.image = UIImage() }
        if distanceLabel != nil { distanceLabel.text = "" }
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
