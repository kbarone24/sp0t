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

class LocationPickerController: UIViewController {
    
    unowned var mapVC: MapViewController!
    weak var containerVC: PhotosContainerController!
    
    var spotObject: MapSpot!
    lazy var selectedImages: [UIImage] = []

    var galleryLocation: CLLocation!
    var gifMode = false
    var imageFromCamera = false
    var draftID: Int64!
    
    var mapView: MKMapView!
    var bottomMask: UIView!
    var addressLabel: UILabel!
    
    var maskView: UIView!
    var searchBarContainer: UIView!
    var searchBar: UISearchBar!
    var cancelButton: UIButton!
    var resultsTable: UITableView!
    var pan: UIPanGestureRecognizer!
    lazy var searchCompleter = MKLocalSearchCompleter()
    lazy var searchResults = [MKLocalSearchCompletion]()
    
    var locationManager: CLLocationManager!
    var firstTimeGettingLocation = true
    var currentLocation: CLLocation!
    
    var postAnnotation: CustomPointAnnotation!
    var spotAnnotation: CustomSpotAnnotation!
    
    var userLocationButton, toggleMapButton: UIButton!
    
    var passedLocation: CLLocation!
    var secondaryLocation: CLLocation!
    var spotName = ""
    var passedAddress = ""
    
    enum uploadType {
        case standardPost
        case spotPost
        case editPost
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    deinit {
        print("deinit location picker")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("view disappear")
        ///if came from image picker, nav bar shouldnt be translucent
        if passedLocation == nil { self.navigationController?.navigationBar.isTranslucent = false }
        
        if mapView != nil && isMovingToParent {
            let annotations = mapView.annotations
            mapView.removeAnnotations(annotations)
            mapView.delegate = nil
            mapView.removeFromSuperview()
            mapView = nil
        }
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    
    
    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)
        
        if mapView == nil {
            setUpViews()
            
            searchCompleter.delegate = self
            searchCompleter.resultTypes = [.address, .pointOfInterest]
            Mixpanel.mainInstance().track(event: "LocationPickerOpen")
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func setUpViews() {
        addMapView()
    }
    
    func addMapView() {
        if mapVC == nil { return }
        
        if containerVC != nil && containerVC.mapView != nil {
            /// set the current mapView to the mapView of the map picker if it has been initialized
            mapView = containerVC.mapView
        } else {
            mapView = MKMapView(frame: mapVC.mapView.bounds)
        }
        
        let annotations = mapView.annotations
        mapView.removeAnnotations(annotations)
        
        mapView.isUserInteractionEnabled = true
        mapView.userLocation.title = ""
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = true
        mapView.tintColor = .systemBlue
        mapView.register(StandardPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "Post")
        DispatchQueue.main.async { self.view.addSubview(self.mapView) }
        
        mapView.delegate = self
        
        userLocationButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 61, y: view.bounds.height - 200, width: 50, height: 50))
        userLocationButton.setImage(UIImage(named: "UserLocationButton"), for: .normal)
        userLocationButton.addTarget(self, action: #selector(userLocationTap(_:)), for: .touchUpInside)
        userLocationButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        DispatchQueue.main.async { self.mapView.addSubview(self.userLocationButton) }
        
        toggleMapButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 61, y: userLocationButton.frame.minY - 58, width: 50, height: 50))
        toggleMapButton.setImage(UIImage(named: "ToggleMap3D"), for: .normal)
        toggleMapButton.addTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
        toggleMapButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        DispatchQueue.main.async { self.mapView.addSubview(self.toggleMapButton) }

        /// map tap will allow user to set the location of the post by tapping the map
        let mapTap = UITapGestureRecognizer(target: self, action: #selector(mapTap(_:)))
        mapTap.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(mapTap)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        
        addBottomMask()
    }
    
    func setUpNavBar() {
        
        let backArrow = UIImage(named: "BackArrow")?.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = backArrow
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = backArrow
        navigationItem.backBarButtonItem?.tintColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        navigationItem.backBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.clear], for: .selected)
        
        navigationItem.title = "Confirm location"
        
        let btnTitle = passedLocation == nil ? "Next" : "Done"
        let action = passedLocation == nil ? #selector(nextTap(_:)) : #selector(doneTap(_:))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: btnTitle, style: .plain, target: self, action: action)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "SpotGreen")!, NSAttributedString.Key.font : UIFont(name: "SFCamera-Semibold", size: 15)!], for: .normal)
    }
    
    func addBottomMask() {
                
        let maskHeight: CGFloat = mapVC.largeScreen ? 175 : 145
        bottomMask = UIView(frame: CGRect(x: 0, y: view.bounds.height - maskHeight, width: UIScreen.main.bounds.width, height: maskHeight))
        bottomMask.backgroundColor = nil
        bottomMask.isUserInteractionEnabled = false
        let layer0 = CAGradientLayer()
        layer0.frame = bottomMask.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.8).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        ]
        layer0.locations = [0, 0.12, 0.2, 0.39, 0.6, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomMask.layer.addSublayer(layer0)
        
        DispatchQueue.main.async { self.view.addSubview(self.bottomMask) }
        
        addressLabel = UILabel(frame: CGRect(x: 18, y: 45, width: UIScreen.main.bounds.width - 32, height: 20))
        addressLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        addressLabel.font = UIFont(name: "SFCamera-Regular", size: 16)
        addressLabel.lineBreakMode = .byTruncatingTail
        DispatchQueue.main.async { self.bottomMask.addSubview(self.addressLabel) }
        
        /// if add flow add next button, edit flow add save button
        
        searchBarContainer = UIView(frame: CGRect(x: 0, y: self.bottomMask.frame.minY + 75, width: UIScreen.main.bounds.width, height: 75))
        searchBarContainer.backgroundColor = nil
        searchBarContainer.layer.cornerRadius = 8
        DispatchQueue.main.async { self.view.addSubview(self.searchBarContainer) }
        
        searchBar = UISearchBar(frame: CGRect(x: 14, y: 11, width: UIScreen.main.bounds.width - 28, height: 36))
        searchBar.searchBarStyle = .default
        searchBar.tintColor = .white
        searchBar.barTintColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.searchTextField.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.137, alpha: 1)
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.placeholder = " Search for a location"
        searchBar.searchTextField.font = UIFont(name: "SFCamera-Regular", size: 13)
        searchBar.clipsToBounds = true
        searchBar.layer.masksToBounds = true
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.layer.cornerRadius = 8
        searchBar.searchTextField.layer.cornerRadius = 8
        searchBarContainer.addSubview(searchBar)
        
        cancelButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: 13, width: 50, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCamera-Regular", size: 14)
        cancelButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        cancelButton.addTarget(self, action: #selector(searchCancelTap(_:)), for: .touchUpInside)
        cancelButton.alpha = 0.0
        searchBarContainer.addSubview(cancelButton)
        
        resultsTable = UITableView(frame: CGRect(x: 0, y: view.bounds.height, width: UIScreen.main.bounds.width, height: view.bounds.height - 200))
        resultsTable.contentInset = UIEdgeInsets(top: 9, left: 0, bottom: 40, right: 0)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.backgroundColor = UIColor(named: "SpotBlack")
        resultsTable.separatorStyle = .none
        DispatchQueue.main.async { self.view.addSubview(self.resultsTable)}
        
        pan = UIPanGestureRecognizer(target: self, action: #selector(closeTable(_:)))
        
        maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        maskView.isHidden = true
        maskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeOnTap(_:))))
        mapView.addSubview(maskView)
    }
    
    func checkLocation() {

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
            
        //prompt user to open their settings if they havent allowed location services
        case .restricted, .denied:
            let alert = UIAlertController(title: "Spot needs your location to find spots near you", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                switch action.style{
                case .default:
                    
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:], completionHandler: nil)
                    //   self.startLocationServices()
                    
                case .cancel:
                    print("cancel")
                case .destructive:
                    print("destruct")
                @unknown default:
                    fatalError()
                }}))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                switch action.style{
                case .default:
                    break
                case .cancel:
                    print("cancel")
                case .destructive:
                    print("destruct")
                @unknown default:
                    fatalError()
                }}))
            
            self.present(alert, animated: true, completion: nil)
            break
            
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            
            break
            
        @unknown default:
            fatalError()
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
    
    // set location on tap
    @objc func mapTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "LocationPickerChangePostLocation")
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        
        if postAnnotation == nil {
            spotAnnotation.coordinate = coordinate
        } else {
            postAnnotation.coordinate = coordinate
        }
        
        reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] (addy) in
            guard let self = self else { return }
            self.addressLabel.text = addy
            self.addressLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 120, height: 40))
        }
    }
    
    @objc func toggle2D(_ sender: UIButton) {
        mapView.mapType = .mutedStandard
        mapView.camera.pitch = 0
        
        toggleMapButton.setImage(UIImage(named: "ToggleMap3D"), for: .normal)
        toggleMapButton.removeTarget(self, action: #selector(toggle2D(_:)), for: .touchUpInside)
        toggleMapButton.addTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
    }
    
    @objc func toggle3D(_ sender: UIButton) {
        mapView.mapType = .hybridFlyover
        mapView.camera.pitch = 60

        toggleMapButton.setImage(UIImage(named: "ToggleMap2D"), for: .normal)
        toggleMapButton.removeTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
        toggleMapButton.addTarget(self, action: #selector(toggle2D(_:)), for: .touchUpInside)
    }
    
    // animate to current location + change annotation location + reverse geocode for address
    @objc func userLocationTap(_ sender: UIButton) {
        
        let camera = MKMapCamera(lookingAtCenter: currentLocation.coordinate, fromDistance: 500, pitch: 60, heading: 0)
        mapView.setCamera(camera, animated: false)
        
        if postAnnotation == nil {
            spotAnnotation.coordinate = currentLocation.coordinate
        } else {
            postAnnotation.coordinate = currentLocation.coordinate
        }
        
        reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude)) { [weak self] (addy) in
            guard let self = self else { return }
            self.addressLabel.text = addy
            self.addressLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 120, height: 40))
        }
    }
    
    // skip choose spot if add-to-spot flow
    @objc func nextTap(_ sender: UIBarButtonItem) {
        if spotObject == nil {
            presentChooseSpot(animated: true)
        } else {
            presentUploadPost(animated: true)
        }
    }
    
    @objc func doneTap(_ sender: UIBarButtonItem) {
        // send notification, return to spotVC
        self.navigationController?.popViewController(animated: true)
        let coordinate = postAnnotation == nil ? spotAnnotation.coordinate : postAnnotation.coordinate
        let userInfo: [String: Any] = ["coordinate": coordinate]
        let notiName = spotObject == nil ? NSNotification.Name("PostAddressChange") : NSNotification.Name("SpotAddressChange")
        NotificationCenter.default.post(Notification(name: notiName, object: nil, userInfo: userInfo))
    }
    
    func presentChooseSpot(animated: Bool) {
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(withIdentifier: "ChooseSpot") as? ChooseSpotController {
            vc.selectedImages = self.selectedImages
            vc.postLocation = self.postAnnotation.coordinate
            vc.mapVC = self.mapVC
            vc.locationPickerVC = self
            
            let navController = UINavigationController(rootViewController: vc)
            present(navController, animated: animated, completion: nil)
        }
    }
    
    func presentUploadPost(animated: Bool) {
        
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "UploadPost") as? UploadPostController {
            vc.selectedImages = self.selectedImages
            vc.spotObject = self.spotObject
            vc.postLocation = self.postAnnotation.coordinate
            vc.postLocation = self.postAnnotation.coordinate
            vc.mapVC = self.mapVC
            vc.postType = self.spotObject.privacyLevel == "public" ? .postToPublic : .postToPrivate
            
            vc.gifMode = gifMode
            vc.imageFromCamera = imageFromCamera
            vc.draftID = draftID
            
            let navController = UINavigationController(rootViewController: vc)
            present(navController, animated: animated, completion: nil)
        }
    }
}

extension LocationPickerController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension LocationPickerController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status != .authorizedWhenInUse {
            return
        } else {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        if (firstTimeGettingLocation) {
            
            currentLocation = location

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
            
            self.firstTimeGettingLocation = false
            
        } else {
            currentLocation = location
        }
    }
    
    func animateToSelectedLocation(coordinate: CLLocationCoordinate2D, passed: Bool) {
        
        let camera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 500, pitch: 0, heading: 0)

        if passed {
            ///passed location through from edit spot
            mapView.camera = camera
            
            if postAnnotation == nil {
                mapView.addAnnotation(self.spotAnnotation)
            } else {
                mapView.addAnnotation(self.postAnnotation)
            }
            
            addressLabel.text = passedAddress
            addressLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 120, height: 40))
            return
            
        } else {
            mapView.camera = camera
            searchCompleter.region = mapView.region
            finishInitialAdd(coordinate: coordinate)
            return
        }
    }
    
    func finishInitialAdd(coordinate: CLLocationCoordinate2D) {
        self.mapView.addAnnotation(self.postAnnotation)
        self.mapVC.checkForAddTutorial()
                    
        self.reverseGeocodeFromCoordinate(numberOfFields: 4, location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { [weak self] (addy) in
            guard let self = self else { return }
            self.addressLabel.text = addy
            self.addressLabel.sizeThatFits(CGSize(width: UIScreen.main.bounds.width - 120, height: 40))
        }
    }
    
    func addInitialAnnotation() {
        postAnnotation = CustomPointAnnotation()

        var lat = currentLocation.coordinate.latitude
        var long = currentLocation.coordinate.longitude
        
        /// if from gallery get image location if it exists
        if galleryLocation != nil {
            let imLat = galleryLocation.coordinate.latitude
            if imLat != 0.0 { lat = imLat }
            let imLong = galleryLocation.coordinate.longitude
            if imLong != 0.0 { long = imLong }
        } else if spotObject != nil && !imageFromCamera && lat == currentLocation.coordinate.latitude {
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
        
        self.animateToSelectedLocation(coordinate: selectedCoordinate, passed: true)
    }
    
    func addSpotAnnotation(coordinate: CLLocationCoordinate2D) {
        spotAnnotation = CustomSpotAnnotation()
        spotAnnotation.coordinate = coordinate
        spotAnnotation.title = spotObject == nil ? spotName : spotObject.spotName
        mapView.addAnnotation(spotAnnotation)
    }
}

extension LocationPickerController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is CustomPointAnnotation {
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "Post") as? StandardPostAnnotationView
            if annotationView == nil {
                annotationView = StandardPostAnnotationView(annotation: annotation, reuseIdentifier: "Post")
            } else {
                annotationView!.annotation = annotation
            }
            
            let nibView = loadPostNib()
            nibView.galleryImage.image = selectedImages.first ?? UIImage()
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            annotationView!.image = nibImage
            annotationView!.sizeToFit()
            annotationView!.isEnabled = true
            annotationView!.isDraggable = true
            annotationView!.isSelected = true
            annotationView!.clusteringIdentifier = nil
            
            annotationView!.centerOffset = CGPoint(x: 6.25, y: -26)
            return annotationView
        } else if let anno = annotation as? CustomSpotAnnotation {
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? SpotAnnotationView
            if annotationView == nil {
                annotationView = SpotAnnotationView(annotation: anno, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            } else {
                annotationView!.annotation = annotation
            }
            annotationView?.clusteringIdentifier = nil
            
            let nibView = loadSpotNib()
            nibView.spotNameLabel.text = spotObject == nil ? spotName : spotObject.spotName
            let temp = nibView.spotNameLabel
            temp?.sizeToFit()
            nibView.resizeBanner(width: temp?.frame.width ?? 0)
            let nibImage = nibView.asImage()
            annotationView!.image = nibImage
            
            return annotationView
            
        } else { return nil }
    }
    
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        checkLocation()
    }
    
    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        mapView.mapType = .mutedStandard
    }
        
    //   func mapViewdidmo
    
    func loadPostNib() -> MarkerInfoWindow {
        let infoWindow = MarkerInfoWindow.instanceFromNib() as! MarkerInfoWindow
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.clipsToBounds = true
        
        infoWindow.count.font = UIFont(name: "SFCamera-Semibold", size: 12)
        infoWindow.count.textColor = .black
        let attText = NSAttributedString(string: (infoWindow.count.text)!, attributes: [NSAttributedString.Key.kern: 0.8])
        infoWindow.count.attributedText = attText
        infoWindow.count.textAlignment = .center
        infoWindow.count.clipsToBounds = true
        
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
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        searchCompleter.queryFragment = searchText
        
        if searchText == "" {
            resultsTable.addGestureRecognizer(pan)
            searchResults.removeAll()
            resultsTable.reloadData()
        } else { resultsTable.removeGestureRecognizer(pan) }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
        resultsTable.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let searchResult = searchResults[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(named: "SpotBlack")
        
        cell.textLabel?.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        cell.detailTextLabel?.textColor = UIColor(red: 0.61, green: 0.61, blue: 0.61, alpha: 1.00)
        cell.textLabel?.attributedText = highlightedText(searchResult.title, inRanges: searchResult.titleHighlightRanges, size: 13.0)
        cell.detailTextLabel?.attributedText = highlightedText(searchResult.subtitle, inRanges: searchResult.subtitleHighlightRanges, size: 12.0)

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Mixpanel.mainInstance().track(event: "LocationPickerChangeCity")
        
        let completion = searchResults[indexPath.row]
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] (response, error) in
            
            guard let self = self else { return }
            guard let placemark = response?.mapItems[0].placemark else { return }
            
            let coordinate = placemark.coordinate
            let camera = MKMapCamera(lookingAtCenter: coordinate, fromDistance: 2000, pitch: self.mapView.camera.pitch, heading: 0)
            self.mapView.camera = camera
            
            self.postAnnotation.coordinate = coordinate
            self.addressLabel.text = placemark.addressFormatter(number: true)
            self.searchBar.endEditing(true)
        }
    }
        
    @objc func searchCancelTap(_ sender: UIButton) {
        searchBar.endEditing(true)
    }
    
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        openSearch()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        closeSearch()
    }
        
    func openSearch() {
                
        resultsTable.addGestureRecognizer(pan)
        maskView.alpha = 0.0
        maskView.isHidden = false
        
        UIView.animate(withDuration: 0.25) {
            self.maskView.alpha = 1.0
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: 11, width: UIScreen.main.bounds.width - 85, height: self.searchBar.frame.height)
            self.searchBarContainer.frame = CGRect(x: 0, y: 40, width: UIScreen.main.bounds.width, height: 60)
            self.searchBarContainer.backgroundColor = UIColor(named: "SpotBlack")
            self.resultsTable.frame = CGRect(x: 0, y: 95, width: UIScreen.main.bounds.width, height: self.resultsTable.frame.height)
            self.addressLabel.alpha = 0.0
            self.cancelButton.alpha = 1.0
        }
    }
    
    func closeSearch() {
        // searchBar.placeholder = "Search locations"
        
        UIView.animate(withDuration: 0.25) {
            self.maskView.alpha = 0.0
            self.searchBarContainer.backgroundColor = nil
            self.searchBarContainer.frame = CGRect(x: 0, y: self.bottomMask.frame.minY + 75, width: UIScreen.main.bounds.width, height: 75)
            self.searchBar.frame = CGRect(x: self.searchBar.frame.minX, y: 11, width: UIScreen.main.bounds.width - 28, height: self.searchBar.frame.height)
            self.resultsTable.frame = CGRect(x: 0, y: self.view.bounds.height, width: UIScreen.main.bounds.width, height: self.view.bounds.height - 200)

            self.addressLabel.alpha = 1.0
            self.cancelButton.alpha = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.maskView.isHidden = true }
        
        searchBar.text = ""
        searchCompleter.queryFragment = ""
        searchBar.resignFirstResponder()
        searchResults.removeAll()
        resultsTable.reloadData()
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
    
    func highlightedText(_ text: String, inRanges ranges: [NSValue], size: CGFloat) -> NSAttributedString {
        
        let attributedText = NSMutableAttributedString(string: text)
        let regular = UIFont(name: "SFCamera-Regular", size: size)
        attributedText.addAttribute(NSAttributedString.Key.font, value: regular as Any, range:NSMakeRange(0, text.count))

        let bold = UIFont.boldSystemFont(ofSize: size)
        for value in ranges {
            attributedText.addAttribute(NSAttributedString.Key.font, value:bold, range:value.rangeValue)
        }
        
        return attributedText
    }
}

