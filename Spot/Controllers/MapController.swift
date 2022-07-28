//
//  MapController.swift
//  Spot
//
//  Created by kbarone on 2/15/19.
//   Copyright © 2019 sp0t, LLC. All rights reserved.
//
import UIKit
import MapKit
import Firebase
import Geofirestore
import FirebaseFirestoreSwift
import Photos
import Mixpanel
import FirebaseUI
import FirebaseFirestore
import FirebaseAuth
import MapboxMaps
import FirebaseMessaging

class MapController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var titleView: MapTitleView!
    var mapView: MapView!
    var bottomMapMask: UIView!
    var mapsCollection: UICollectionView!
    var selectedItemIndex = 0
    
    let locationManager = CLLocationManager()
    lazy var imageManager = SDWebImageManager()
    var userListener: ListenerRegistration!
    
    let homeFetchGroup = DispatchGroup()
    let mapPostsGroup = DispatchGroup()
            
    var firstTimeGettingLocation = true
    var friendsLoaded = false
    var feedLoaded = false
    var shouldCluster = true /// should cluster is false when nearby (tab index 1) selected and max zoom enabled
        
    lazy var postsList: [MapPost] = []
    lazy var friendsPostsDictionary = [String: MapPost]()
    lazy var friendsPostsGroup: [FriendsPostGroup] = []
    
    /// use to avoid deleted documents entering from cache
    lazy var deletedSpotIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []
    
    var notiListener: ListenerRegistration!

    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled
        
    /// post annotations
    var postAnnotationManager: PointAnnotationManager!
    var pointAnnotations: [PointAnnotation] = []
    
    /// sheet view: Must declare outside to listen to UIEvent
    private var sheetView: DrawerView? {
        didSet {
            navigationController?.navigationBar.isHidden = sheetView == nil ? false : true
        }
    }
      
    override func viewDidLoad() {
        addMapView()
        addMapsCollection()
        checkLocationAuth()
        getAdmins() /// get admin users to exclude from analytics
        addNotifications()
        runMapFetches()
        
        locationManager.delegate = self
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "MapOpen")
    }
    
    
    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name(("FriendsListLoad")), object: nil)
      //  NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
    }
    
    func addMapView() {
        let options = MapInitOptions(resourceOptions: ResourceOptions(accessToken: "pk.eyJ1Ijoic3AwdGtlbm55IiwiYSI6ImNrem9tYzhkODAycmUydW50bXVza2JhZmgifQ.Cl0TokRRaMo8UZDImGqp0A"), mapOptions: MapOptions(), cameraOptions: CameraOptions(), styleURI: StyleURI(rawValue: "mapbox://styles/sp0tkenny/ckzpv54l9004114kdu5kcy8w4"))
        mapView = MapView(frame: .zero, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.location.options.puckType = .puck2D()
        view.addSubview(mapView)
        mapView.snp.makeConstraints {
            $0.leading.top.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(65)
        }
                
        addPostAnnotationManager()
        
        let addButton = UIButton {
            $0.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
            $0.addTarget(self, action: #selector(addTap(_:)), for: .touchUpInside)
            mapView.addSubview($0)
        }
        addButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().inset(110) /// offset 65 px for portion of map below fold
            $0.height.width.equalTo(73)
        }
    }
    
    func addMapsCollection() {
        let spacing: CGFloat = 9 + 5 * 3
        let itemWidth = (UIScreen.main.bounds.width - spacing) / 3.6
        let layout = UICollectionViewFlowLayout {
            $0.itemSize = CGSize(width: itemWidth, height: itemWidth * 0.95)
            $0.minimumInteritemSpacing = 5
            $0.scrollDirection = .horizontal
        }
        mapsCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        mapsCollection.backgroundColor = .white
        mapsCollection.showsHorizontalScrollIndicator = false
        mapsCollection.register(TagFriendCell.self, forCellWithReuseIdentifier: "TagFriendCell")
        mapsCollection.contentInset = UIEdgeInsets(top: 5, left: 9, bottom: 0, right: 9)
        mapsCollection.delegate = self
        mapsCollection.dataSource = self
        mapsCollection.register(MapHomeCell.self, forCellWithReuseIdentifier: "MapCell") 
        view.addSubview(mapsCollection)
        mapsCollection.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(115)
        }
    }
    
    func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        
        navigationController?.navigationBar.addWhiteBackground()
        navigationItem.titleView = getTitleView()
        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }
    }
    
    func getTitleView() -> UIView {
        if titleView != nil { return titleView }
        
        titleView = MapTitleView {
            $0.profileButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)
            $0.notiButton.addTarget(self, action: #selector(openNotis(_:)), for: .touchUpInside)

        }
        
        let notificationRef = self.db.collection("users").document(self.uid).collection("notifications")
        let query = notificationRef.whereField("seen", isEqualTo: false)
        
        /// show green bell on notifications when theres an unseen noti
        if notiListener != nil { notiListener.remove() }
        notiListener = query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in
            if err != nil || snap?.metadata.isFromCache ?? false {
                return
            } else {
                if snap!.documents.count > 0 {
                    self.titleView.notiButton.pendingCount = snap!.documents.count
                }
            }
        }
                
        return titleView
    }

    
    
    @objc func addTap(_ sender: UIButton) {
        if navigationController!.viewControllers.contains(where: {$0 is AVCameraController}) { return } /// crash on double stack was happening here
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
                vc.mapVC = self
                
                let transition = CATransition()
                transition.duration = 0.3
                transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                transition.type = CATransitionType.push
                transition.subtype = CATransitionSubtype.fromTop
                self.navigationController?.view.layer.add(transition, forKey: kCATransition)
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
    
    @objc func profileTap(_ sender: Any){
        let profileVC = ProfileViewController(userProfile: nil)
        sheetView = DrawerView(present: profileVC, drawerConrnerRadius: 22, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        sheetView?.present(to: .Top)
        sheetView?.canInteract = false
        sheetView?.showCloseButton = false
        profileVC.containerDrawerView = sheetView
    }
            
    @objc func openNotis(_ sender: UIButton) {
        let notifVC = NotificationsController()
        
        sheetView = DrawerView(present: notifVC, drawerConrnerRadius: 22, detentsInAscending: [.Top], closeAction: {
            self.sheetView = nil
        })
        
        sheetView?.swipeDownToDismiss = false
        sheetView?.canInteract = false
        sheetView?.present(to: .Top)
        sheetView?.showCloseButton = false
        
        notifVC.contentDrawer = sheetView
    }
    
    
    /// custom reset nav bar (patch fix for CATransition)
    func uploadMapReset() {
        DispatchQueue.main.async {
            self.setUpNavBar()
            UIView.animate(withDuration: 0.25) { self.navigationController?.navigationBar.alpha = 1.0 }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.addPostAnnotationManager()
            }
        }
    }
}

extension MapController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status != .authorizedWhenInUse {
            Mixpanel.mainInstance().track(event: "LocationServicesDenied")
            presentLocationAlert()
        } else {
            Mixpanel.mainInstance().track(event: "LocationServicesAllowed")
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else { return }
        
        UserDataModel.shared.currentLocation = location
        
        // might want to do this every time locations update
        if (firstTimeGettingLocation) {
            
            /// set current location to show while feed loads
            let options = CameraOptions(center: location.coordinate, padding: mapView.cameraState.padding, anchor: CGPoint(), zoom: 18, bearing: mapView.cameraState.bearing, pitch: 75)
            mapView.mapboxMap.setCamera(to: options)
            
            firstTimeGettingLocation = false
            
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
        }
    }
    
    func addPostAnnotationManager() {
        postAnnotationManager = mapView.annotations.makePointAnnotationManager()
        postAnnotationManager.iconAllowOverlap = false
        postAnnotationManager.iconIgnorePlacement = false
        postAnnotationManager.iconOptional = true
        postAnnotationManager.annotations = pointAnnotations
    }
    
    func checkLocationAuth() {

        switch locationManager.authorizationStatus {
        
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
            
        //prompt user to open their settings if they havent allowed location services
        case .restricted, .denied:
            presentLocationAlert()
            break
            
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            break
            
        @unknown default:
            fatalError()
        }
    }
    
    func presentLocationAlert() {
        let alert = UIAlertController(title: "Spot needs your location to find spots near you", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
            switch action.style{
            
            case .default:
                Mixpanel.mainInstance().track(event: "LocationServicesSettingsOpen")
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:]) { (allowed) in
                }

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
    }
}

extension MapController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        if otherGestureRecognizer.view?.tag == 16 || otherGestureRecognizer.view?.tag == 23 || otherGestureRecognizer.view?.tag == 30 {
            return false
        }
        return true
    }
}

//functions for loading nearby spots in nearby view
extension MapController {

    
    func checkFeedLocations() {
        /// zoom out map on spot page select to show all annotations in view
        /// need to set a max distance here
        /*
        var farthestDistance: CLLocationDistance = 0
        
        for post in postsList {
            
            let postLocation = CLLocation(latitude: post.postLat, longitude: post.postLong)
            let postDistance = postLocation.distance(from: UserDataModel.shared.currentLocation)
            if postDistance < 1500000 && postDistance > farthestDistance { farthestDistance = postDistance }
            
            if post.id == postsList.last?.id ?? "" {
                /// max distance = 160 in all directions
                
                var region = MKCoordinateRegion(center: UserDataModel.shared.currentLocation.coordinate, latitudinalMeters: farthestDistance * 2.5, longitudinalMeters: farthestDistance * 2.5)
                
                /// adjust if invalid region
                if region.span.latitudeDelta > 50 { region.span.latitudeDelta = 50 }
                if region.span.longitudeDelta > 50 { region.span.longitudeDelta = 50 }
                
                let offset: CGFloat = UserDataModel.shared.largeScreen ? 100 : 130
                self.offsetCenterCoordinate(selectedCoordinate: UserDataModel.shared.currentLocation.coordinate, offset: offset, animated: true, region: region)
            }
        }
        
        closeFeedDrawer()
        */
    }
}


// supplementary methods for offsetCenterCoordinate
extension CLLocationCoordinate2D {
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    private func radians(from degrees: CLLocationDegrees) -> Double {
        return degrees * .pi / 180.0
    }
    
    private func degrees(from radians: Double) -> CLLocationDegrees {
        return radians * 180.0 / .pi
    }
    
    func adjust(by distance: CLLocationDistance, at bearing: CLLocationDegrees) -> CLLocationCoordinate2D {
       
        let distanceRadians = distance / 6_371.0   // 6,371 = Earth's radius in km
        let bearingRadians = radians(from: bearing)
        let fromLatRadians = radians(from: latitude)
        let fromLonRadians = radians(from: longitude)
        
        let toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
            + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) )
        
        var toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
            * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                - sin(fromLatRadians) * sin(toLatRadians))
        
        // adjust toLonRadians to be in the range -180 to +180...
        toLonRadians = fmod((toLonRadians + 3.0 * .pi), (2.0 * .pi)) - .pi
        
        let result = CLLocationCoordinate2D(latitude: degrees(from: toLatRadians), longitude: degrees(from: toLonRadians))
        
        return result
    }
}
///https://stackoverflow.com/questions/15421106/centering-mkmapview-on-spot-n-pixels-below-pin

private extension UIView {
    var isPotentiallyInteractive: Bool {
        guard isUserInteractionEnabled else { return false }
        return (isControl || doesContainGestureRecognizer)
    }
    
    var isControl: Bool {
        return self is UIControl
    }
    
    var doesContainGestureRecognizer: Bool {
        return !(gestureRecognizers?.isEmpty ?? true)
    }
}

// Supposed to exclude invalid geoQuery regions. Not sure how well it works
extension MKCoordinateRegion {
    var IsValid: Bool {
        get {
            let latitudeCenter = self.center.latitude
            let latitudeNorth = self.center.latitude + self.span.latitudeDelta/2
            let latitudeSouth = self.center.latitude - self.span.latitudeDelta/2
            
            let longitudeCenter = self.center.longitude
            let longitudeWest = self.center.longitude - self.span.longitudeDelta/2
            let longitudeEast = self.center.longitude + self.span.longitudeDelta/2
            
            let topLeft = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeWest)
            let topCenter = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeCenter)
            let topRight = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeEast)
            
            let centerLeft = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeWest)
            let centerCenter = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeCenter)
            let centerRight = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeEast)
            
            let bottomLeft = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeWest)
            let bottomCenter = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeCenter)
            let bottomRight = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeEast)
            
            return  CLLocationCoordinate2DIsValid(topLeft) &&
                CLLocationCoordinate2DIsValid(topCenter) &&
                CLLocationCoordinate2DIsValid(topRight) &&
                CLLocationCoordinate2DIsValid(centerLeft) &&
                CLLocationCoordinate2DIsValid(centerCenter) &&
                CLLocationCoordinate2DIsValid(centerRight) &&
                CLLocationCoordinate2DIsValid(bottomLeft) &&
                CLLocationCoordinate2DIsValid(bottomCenter) &&
                CLLocationCoordinate2DIsValid(bottomRight) ?
                    true :
            false
        }
    }
}

class MapNavigationController: UINavigationController {
    public var requiredStatusBarStyle: UIStatusBarStyle = .darkContent {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        requiredStatusBarStyle
    }
}

class NotificationsButton: UIButton {
    var bellView: UIImageView!
    var bubbleIcon: UIView!
    var countLabel: UILabel!
    
    lazy var pendingCount: Int = 0 {
        didSet {
            countLabel.text = String(pendingCount)
            bubbleIcon.isHidden = pendingCount == 0
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bellView = UIImageView {
            $0.image = UIImage(named: "NotificationsNavIcon")
            addSubview($0)
        }
        bellView.snp.makeConstraints {
            $0.leading.bottom.equalToSuperview()
            $0.width.equalTo(26.5)
            $0.height.equalTo(29)
        }
        
        bubbleIcon = UIView {
            $0.backgroundColor = UIColor(red: 1, green: 0.4, blue: 0.544, alpha: 1)
            $0.layer.cornerRadius = 16/2
            $0.isHidden = true
            addSubview($0)
        }
        bubbleIcon.snp.makeConstraints {
            $0.trailing.top.equalToSuperview()
            $0.height.width.equalTo(16)
        }
        
        countLabel = UILabel {
            $0.text = ""
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 11.5)
            $0.textAlignment = .center
            bubbleIcon.addSubview($0)
        }
        countLabel.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MapTitleView: UIView {
    var signUpLogo: UIImageView!
    var profileButton: UIButton!
    var notiButton: NotificationsButton!
    var searchButton: UIButton!
    
    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        /* signUpLogo = UIImageView {
            $0.image = UIImage(named: "Signuplogo")
          //  addSubview($0)
        }
        signUpLogo.snp.makeConstraints {
            $0.leading.equalTo(10)
            $0.top.equalTo(5)
            $0.height.width.equalTo(35)
        }
        */
        profileButton = UIButton {
            $0.setImage(UIImage(named: "ProfileNavIcon"), for: .normal)
            addSubview($0)
        }
        profileButton.snp.makeConstraints {
            $0.trailing.equalTo(-30)
            $0.top.equalTo(5)
            $0.width.equalTo(23.5)
            $0.height.equalTo(29)
        }
        
        notiButton = NotificationsButton {
            addSubview($0)
        }
        notiButton.snp.makeConstraints {
            $0.trailing.equalTo(profileButton.snp.leading).offset(-30)
            $0.top.equalTo(0)
            $0.height.equalTo(35)
            $0.width.equalTo(30)
        }

        searchButton = UIButton {
            $0.setImage(UIImage(named: "SearchNavIcon"), for: .normal)
            addSubview($0)
        }
        searchButton.snp.makeConstraints {
            $0.trailing.equalTo(notiButton.snp.leading).offset(-30)
            $0.top.equalTo(5)
            $0.height.width.equalTo(29)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
