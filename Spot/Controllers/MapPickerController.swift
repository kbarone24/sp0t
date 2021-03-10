//
//  MapPickerController.swift
//  Spot
//
//  Created by kbarone on 4/16/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import MapKit
import CoreLocation
import Mixpanel
import FirebaseUI

struct ImageObject {
    let asset: PHAsset
    let rawLocation: CLLocation
    let image: UIImage
    let creationDate: Date
}

class MapPickerController: UIViewController, MKMapViewDelegate {
    
    var maskView: UIView!
    var activityIndicator, refreshIndicator: CustomActivityIndicator!
    var currentLocation: CLLocation!
    var storedCamera: MKMapCamera!
    var baseSize: CGSize!
    private var infoWindow = MarkerInfoWindow()
    
    lazy var locationManager = CLLocationManager()
    lazy var locationObjects: [ImageObject] = []
    lazy var annotations: [CustomPointAnnotation] = []
    
    var firstTimeGettingLocation = true
    
    var loaded = false
    
    override func viewDidLoad() {
        self.navigationItem.title = "Photo map"
    }
    
    deinit {
        print("picker deinit")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        guard let parentVC = parent as? PhotosContainerController else { return }
        
        /// remove mapview delegate when view disappears bc either going to location picker or back to main mapVC
        if parentVC.mapView != nil && !isMovingFromParent {
            storedCamera = parentVC.mapView.camera
            parentVC.mapView.delegate = nil
            parentVC.mapView.removeAnnotations(annotations)
            parentVC.mapView.removeFromSuperview()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "MapPickerOpen")
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        if self.locationObjects.isEmpty {
            /// original load
            view.isUserInteractionEnabled = false
            
            baseSize = CGSize(width: UIScreen.main.bounds.width/4 - 0.1, height: UIScreen.main.bounds.width/4 - 0.1)
            parentVC.mapView = MKMapView(frame: UIScreen.main.bounds)
            parentVC.mapView.delegate = self
            parentVC.mapView.overrideUserInterfaceStyle = .dark
            parentVC.mapView.register(StandardPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            parentVC.mapView.register(PostClusterView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
            parentVC.mapView.setCameraZoomRange(MKMapView.CameraZoomRange(minCenterCoordinateDistance: 1000), animated: false)
            parentVC.mapView.isUserInteractionEnabled = true
            
            maskView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
            maskView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            
            activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 140, width: UIScreen.main.bounds.width, height: 30))
            
            let textMask = UILabel(frame: CGRect(x: 0, y: 230, width: UIScreen.main.bounds.width, height: 30))
            textMask.text = "Loading photo map"
            textMask.textAlignment = .center
            textMask.textColor = .white
            textMask.font = UIFont(name: "SFCamera-Regular", size: 14)
            
            DispatchQueue.main.async {
                self.view.addSubview(parentVC.mapView)
                self.view.addSubview(self.maskView)
                self.maskView.addSubview(self.activityIndicator)
                self.maskView.addSubview(textMask)
                self.activityIndicator.startAnimating()
            }
            
            locationManager.delegate = self
            checkLocation()
            
        } else if parentVC.mapView != nil && parentVC.mapView.superview == nil {
            /// reset delegate after return from location picker

            if locationObjects.count > 0 { self.view.isUserInteractionEnabled = true }
            
            DispatchQueue.main.async {
                
                parentVC.mapView.mapType = .mutedStandard
                self.view.addSubview(parentVC.mapView)
                
                if self.storedCamera != nil {
                    parentVC.mapView.camera = self.storedCamera
                    self.storedCamera = nil
                } else if self.currentLocation != nil {             parentVC.mapView.setRegion(MKCoordinateRegion(center: self.currentLocation.coordinate, latitudinalMeters: 50000, longitudinalMeters: 50000), animated: false) }
                
                /// add annotations for this map rect
                parentVC.mapView.delegate = self
                
                /// main thread was getting clogged with map updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    guard let parentVC = self.parent as? PhotosContainerController else { return }
                    
                    self.addRefreshIndicator()
                    parentVC.mapView.addAnnotations(self.annotations)
                }
            }
        }
        
        super.viewDidAppear(animated)
    }
    
    func addRefreshIndicator() {
        refreshIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 140, width: UIScreen.main.bounds.width, height: 30))
        refreshIndicator.startAnimating()
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        if parentVC.mapView != nil { parentVC.mapView.addSubview(refreshIndicator) }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.refreshIndicator.stopAnimating()
        }
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
    
    func getImages() {
       
        var assetIndex = 0
        
        /// reload images once assets full is fetched from container
        guard let parentVC = parent as? PhotosContainerController else { return }
        if parentVC.assetsFull == nil || parentVC.assetsFull.count == 0 {
            DispatchQueue.main.async { self.maskView.isHidden = true }
            return
        }
        
        parentVC.assetsFull.enumerateObjects({ (object, count, stop) in
            /// stop adding images once mapView disappears
            
            if parentVC.mapView == nil { stop.pointee = true }
            if let l = object.location {
                var creationDate = Date()
                if let d = object.creationDate {
                    creationDate = d
                }
                
                if !self.locationObjects.contains(where: {$0.asset == object })  {
                    
                    let annotation = CustomPointAnnotation()
                    annotation.coordinate = l.coordinate
                    annotation.asset = object
                    self.annotations.append(annotation)
                    
                    self.locationObjects.append(ImageObject(asset: object, rawLocation: l, image: UIImage(), creationDate: creationDate))
                    
                    if parentVC.mapView == nil { return }
                    parentVC.mapView.addAnnotation(annotation)
                    
                    assetIndex += 1
                    
                    /// enable mapView interactions once annotations all loaded
                    if assetIndex == parentVC.assetsFull.count { self.enableMap() }
                }
                
            } else {
                /// no location data for this image
                assetIndex += 1
                if assetIndex == parentVC.assetsFull.count {
                    self.enableMap()
                }
            }
        })
    }
    
    func enableMap() {
        view.isUserInteractionEnabled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: { [weak self] in
            guard let self = self else { return }
             self.maskView.isHidden = true
        })
    }
    
    
    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        if loaded && self.locationObjects.isEmpty {
            self.getImages()
        }
    }
            
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.coordinate.latitude == 0.0 { return MKAnnotationView() }
        if annotation is CustomPointAnnotation {
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? StandardPostAnnotationView
            if annotationView == nil {
                annotationView = StandardPostAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
            } else {
                annotationView!.annotation = annotation
            }
            
            ///if nibview for this coordinate doesn't exist, create it, add to object
            ///if nibview for this coordinate does exist, fetch and add to annotation
            
            if let i = self.locationObjects.lastIndex(where: {$0.rawLocation.coordinate.latitude == annotation.coordinate.latitude && $0.rawLocation.coordinate.longitude == annotation.coordinate.longitude}) {
              
                annotationView!.updateImage(object: self.locationObjects[i])
                
            } else {
                annotationView!.image = UIImage()
            }
            
            let tap = MapPickerTap(target: self, action: #selector(markerTap(_:)))
            tap.coordinates = annotation.coordinate
            annotationView!.addGestureRecognizer(tap)
            annotationView!.centerOffset = CGPoint(x: 6.25, y: -26)
            return annotationView
            
        } else if annotation is MKClusterAnnotation {
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? PostClusterView
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? PostClusterView
            }
            else {
                annotationView!.annotation = annotation
            }
            /// update image to have the number of member annotations in the cluster showing
            
            annotationView!.updateImage(imageObjects: self.locationObjects)
            
            let tap = MapPickerTap(target: self, action: #selector(clusterTap(_:)))
            tap.coordinates = annotation.coordinate
            annotationView!.addGestureRecognizer(tap)
            return annotationView
        } else {
            return nil
        }
    }
    
    @objc func markerTap(_ sender: MapPickerTap) {
        let latitude = sender.coordinates.latitude
        let longitude = sender.coordinates.longitude
        openMarker(latitude: latitude, longitude: longitude)
    }
    
    func openMarker(latitude: Double, longitude: Double) {
        
        var passObjects: [(ImageObject)] = []
        guard let parentVC = parent as? PhotosContainerController else { return }
        if let match = self.locationObjects.first(where: {$0.rawLocation.coordinate.longitude == longitude && $0.rawLocation.coordinate.latitude == latitude}) {
            
            passObjects.append(match)
            if let vc = storyboard?.instantiateViewController(withIdentifier: "ClusterPicker") as? ClusterPickerController {
                
                vc.mapVC = parentVC.mapVC
                vc.containerVC = parentVC
                vc.spotObject = parentVC.spotObject
                vc.editSpotMode = parentVC.editSpotMode
                
                vc.tappedLocation = CLLocation(latitude: latitude, longitude: longitude)
                vc.zoomLevel = "city"
                vc.imageObjects = passObjects
                if !parentVC.selectedObjects.isEmpty {
                    var index = 0
                    for obj in parentVC.selectedObjects {
                        vc.imageObjects.insert(obj.object, at: index)
                        vc.selectedObjects.append((object: obj.object, index: index))
                        index += 1
                    }
                } else {
                    vc.single = true
                }
                DispatchQueue.main.async { parentVC.navigationController?.pushViewController(vc, animated: true) }
            }
        }
    }
    
    @objc func clusterTap(_ sender: MapPickerTap) {
        
        let latitude = sender.coordinates.latitude
        let longitude = sender.coordinates.longitude
        
        var index = 0
        var passObjects: [ImageObject] = []
        guard let parentVC = parent as? PhotosContainerController else { return }
        
        if let cluster = parentVC.mapView.annotations.last(where: {$0.coordinate.latitude == latitude && $0.coordinate.longitude == longitude}) as? MKClusterAnnotation {
            for member in cluster.memberAnnotations {
                if let cp = member as? CustomPointAnnotation {
                    
                    /// add all images in cluster to images for cluster picker
                    if let match = self.locationObjects.first(where: {$0.asset == cp.asset}) {
                        if !passObjects.contains(where: {$0.asset == match.asset}) {
                            passObjects.append(match)
                        }
                    }
                }
                
                index = index + 1
                if index == cluster.memberAnnotations.count {
                    if let vc = storyboard?.instantiateViewController(withIdentifier: "ClusterPicker") as? ClusterPickerController {
                        let zoom = parentVC.mapView.camera.altitude
                        print("zoom", zoom)
                        if zoom < 5000000 {
                            if zoom < 500000 {
                                vc.zoomLevel = "city"
                            } else {
                                vc.zoomLevel = "state"
                            }
                        } else {
                            vc.zoomLevel = "country"
                        }
                        
                        vc.mapVC = parentVC.mapVC
                        vc.containerVC = parentVC
                        vc.spotObject = parentVC.spotObject
                        vc.editSpotMode = parentVC.editSpotMode
                        
                        vc.tappedLocation = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
                        vc.imageObjects = passObjects
                        vc.imageObjects.sort(by: {$0.creationDate > $1.creationDate})
                        
                        
                        if !parentVC.selectedObjects.isEmpty {
                            var index = 0
                            for obj in parentVC.selectedObjects {
                                vc.imageObjects.insert(obj.object, at: index)
                                vc.selectedObjects.append((object: obj.object, index: index))
                                index += 1
                            }
                        }
                        DispatchQueue.main.async { parentVC.navigationController?.pushViewController(vc, animated: true) }
                    }
                }
            }
        } else {
            openMarker(latitude: latitude, longitude: longitude)
        }
    }
    
    func loadNib() -> MarkerInfoWindow {
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
}

extension MapPickerController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied {
            return
        } else {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let parentVC = parent as? PhotosContainerController else { return }
        guard let location = locations.last else { return }
        
        if (firstTimeGettingLocation) {
            currentLocation = location
            parentVC.mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50000, longitudinalMeters: 50000), animated: false)
            self.firstTimeGettingLocation = false
        } else {
            currentLocation = location
        }
    }
}

class StandardPostAnnotationView: MKAnnotationView {
    
    var galleryImage: UIImage!
    var asset: PHAsset!
    var spotID = ""
    
    var imageManager: SDWebImageManager!
    var galleryManager: PHCachingImageManager!
    var requestID: Int32 = 0
    var imageObject: ImageObject!
    
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".CustomAnnotationView"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = StandardPostAnnotationView.preferredClusteringIdentifier
        collisionMode = .rectangle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        willSet {
            clusteringIdentifier = StandardPostAnnotationView.preferredClusteringIdentifier
        }
    }
    
    deinit {
        print("deinit standard post")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        galleryManager = PHCachingImageManager()
        let nibView = loadPostNib()
           
        DispatchQueue.global(qos: .userInitiated).async {
            if self.imageObject == nil { return }
            self.loadGalleryAnnotationImage(object: self.imageObject) { [weak self] (image) in
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if image == UIImage() { return }
                    
                    nibView.galleryImage.image = image
                    nibView.count.isHidden = true
                    let nibImage = nibView.asImage()
                    self.image = nibImage
                }
                
            }
        }
    }
    
    func updateImage(post: MapPost) {
        imageManager = SDWebImageManager()
        let nibView = loadPostNib()
        
        loadPostAnnotationImage(post: post) { [weak self] (image) in
            guard let self = self else { return }
            
            nibView.galleryImage.image = image
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
            self.isEnabled = true
        }
    }
    
    func updateImage(object: ImageObject) {
        self.imageObject = object
        
        let nibView = loadPostNib()
        nibView.count.isHidden = true
        let nibImage = nibView.asImage()
        self.image = nibImage
    }
    
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
    
    func loadGalleryAnnotationImage(object: ImageObject, completion: @escaping (_ image: UIImage) -> Void) {
        let baseSize = CGSize(width: 49, height: 34)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        self.requestID = self.galleryManager.requestImage(for: object.asset, targetSize: baseSize, contentMode: .aspectFill, options: options) { (result, info) in
            if result != nil {
                completion(result!)
            } else { completion(UIImage()) }
        }
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
        if imageManager == nil { imageManager = SDWebImageManager() }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func cancelImage() {
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID) }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID); galleryManager = nil }
        if galleryImage != nil { galleryImage = UIImage() }
        if image != nil { image = nil }
    }
}

class PostClusterView: MKAnnotationView {
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".CustomClusterView"
    
    var topPostID = ""
    var imageManager: SDWebImageManager!
    
    var galleryManager: PHCachingImageManager!
    var requestID: Int32 = 0
    lazy var imageObjects: [ImageObject] = []
    
    deinit {
        print("deinit post cluster")
    }
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .rectangle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        /// return when not using in map picker
        if topPostID != "" { return }
        let nibView = loadNib()
        
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let anno0 = clusterAnnotation.memberAnnotations.first
            if let obj = imageObjects.last(where: {$0.rawLocation.coordinate.latitude == anno0!.coordinate.latitude && $0.rawLocation.coordinate.longitude == anno0!.coordinate.longitude}) {
                DispatchQueue.global(qos: .userInitiated).async {
                    
                    self.loadGalleryAnnotationImage(object: obj) { (image) in
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            nibView.galleryImage.image = image
                            nibView.count.text = String(clusterAnnotation.memberAnnotations.count)
                            nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                            let nibImage = nibView.asImage()
                            self.image = nibImage
                        }
                    }
                }
                
            } else {
                nibView.galleryImage.image = UIImage()
                nibView.count.text = String(clusterAnnotation.memberAnnotations.count)
                nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                let nibImage = nibView.asImage()
                self.image = nibImage
            }
            
        } else {
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
        }
    }
        
    func updateImage(imageObjects: [ImageObject]) {
        self.imageObjects = imageObjects
        
        /// set cluster to blank image to ensure clusters are spaced apart correctly
        let nibView = loadNib()
        nibView.count.isHidden = true
        let nibImage = nibView.asImage()
        self.image = nibImage
    }
    
    func updateImage(posts: [MapPost], count: Int) {
        let nibView = loadNib()
        
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let anno0 = clusterAnnotation.memberAnnotations.first
            if let topPost = posts.first(where: {$0.postLat == anno0!.coordinate.latitude && $0.postLong == anno0!.coordinate.longitude}) {
                
                self.topPostID = topPost.id ?? ""
                loadPostAnnotationImage(post: topPost) { [weak self] (image) in
                    guard let self = self else { return }

                    nibView.galleryImage.image = image
                    
                    nibView.count.text = String(count)
                    nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                    let nibImage = nibView.asImage()
                    self.image = nibImage
                }
            } else {
                nibView.count.text = String(count)
                nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                nibView.galleryImage.image = UIImage()
                let nibImage = nibView.asImage()
                self.image = nibImage
            }
        } else {
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
        }
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        imageManager = SDWebImageManager()
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
    
        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func loadGalleryAnnotationImage(object: ImageObject, completion: @escaping (_ image: UIImage) -> Void) {
        
        galleryManager = PHCachingImageManager()
        let baseSize = CGSize(width: 49, height: 34)

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        self.requestID = self.galleryManager.requestImage(for: object.asset, targetSize: baseSize, contentMode: .aspectFill, options: options) { [weak self] (result, info) in
            guard self != nil else { return }
            if result != nil {
                completion(result!)
            } else { completion(UIImage()) }
        }
    }
    
    func cancelImage() {
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID) }
    }
    
    func loadNib() -> MarkerInfoWindow {
        let infoWindow = MarkerInfoWindow.instanceFromNib() as! MarkerInfoWindow
        
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.clipsToBounds = true
        
        infoWindow.count.font = UIFont(name: "SFCamera-Semibold", size: 12)
        infoWindow.count.textColor = .black
        infoWindow.count.textAlignment = .center
        infoWindow.count.clipsToBounds = true
        let attText = NSAttributedString(string: (infoWindow.count.text)!, attributes: [NSAttributedString.Key.kern: -0.2])
        infoWindow.count.attributedText = attText
        
        infoWindow.bringSubviewToFront(infoWindow.count)
        
        return infoWindow
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID); galleryManager = nil }
        if image != nil { image = UIImage() }
    }
}

class CustomPointAnnotation: MKPointAnnotation {
    
  //  lazy var imageURL: String = ""
    lazy var asset: PHAsset = PHAsset()
    
    override init() {
        super.init()
    }
}

extension UIView {
    
    // render nib view as an image to use with annotation view
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

class MapPickerTap: UITapGestureRecognizer {
    var coordinates = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
}
