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
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var mapView: MapView!
    var bottomMapMask: UIView!
    
    let locationManager = CLLocationManager()
    lazy var imageManager = SDWebImageManager()
    var userListener: ListenerRegistration!
    let friendsListGroup = DispatchGroup()
            
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

    var endDocument: DocumentSnapshot!
    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled
    var nearbyRefresh: RefreshStatus = .refreshEnabled
    var queryReady = false /// circlequery returned
    var friendsListener, nearbyListener, commentListener: ListenerRegistration!
        
    /// post annotations
    var postAnnotationManager: PointAnnotationManager!
    var pointAnnotations: [PointAnnotation] = []
    
    /// sheet view: Must declare outside to listen to UIEvent
    private var sheetView: DrawerView? {
        didSet {
            navigationController?.navigationBar.isHidden = sheetView == nil ? false : true
        }
    }
                    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return UIRectEdge.bottom
    }
      
    override func viewDidLoad() {
        addMapView()
        checkLocationAuth()
        getFriends()
        getAdmins() /// get admin users to exclude from analytics
        addNotifications()
        
        locationManager.delegate = self
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "MapOpen")
        setUpNavBar()
    }
    
    func addNotifications() {
        friendsListGroup.notify(queue: DispatchQueue.global()) {
            NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name(("FriendsListLoad")), object: nil)
      //  NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
    }
    
    func addMapView() {
        let options = MapInitOptions(resourceOptions: ResourceOptions(accessToken: "pk.eyJ1Ijoic3AwdGtlbm55IiwiYSI6ImNrem9tYzhkODAycmUydW50bXVza2JhZmgifQ.Cl0TokRRaMo8UZDImGqp0A"), mapOptions: MapOptions(), cameraOptions: CameraOptions(), styleURI: StyleURI(rawValue: "mapbox://styles/sp0tkenny/ckzpv54l9004114kdu5kcy8w4"))
        mapView = MapView(frame: UIScreen.main.bounds, mapInitOptions: options)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.location.options.puckType = .puck2D()
        view.addSubview(mapView)
                
        addPostAnnotationManager()
        
        let addY = UserDataModel.shared.largeScreen ? UIScreen.main.bounds.height - 130 : UIScreen.main.bounds.height - 94
        let addX = UIScreen.main.bounds.width/2 - 30.5
        let addButton = UIButton(frame: CGRect(x: addX, y: addY, width: 61, height: 61))
        addButton.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
        addButton.addTarget(self, action: #selector(addTap(_:)), for: .touchUpInside)
        view.addSubview(addButton)
    }
    
    
    func setUpNavBar() {
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        
        navigationController?.navigationBar.addWhiteBackground()
        navigationItem.titleView = getTitleView()
    }
    
    func getTitleView() -> UIView {
        let navView = UIView(frame: CGRect(x: 20, y: 0, width: UIScreen.main.bounds.width - 40, height: 35))
        
        let signUpLogo = UIImageView(frame: CGRect(x: 10, y: -5, width: 35, height: 35))
        signUpLogo.image = UIImage(named: "Signuplogo")
        signUpLogo.contentMode = .scaleAspectFill
        navView.addSubview(signUpLogo)
        
        let buttonView = UIView(frame: CGRect(x: navView.bounds.width - 120, y: 0, width: 120, height: 30))
        navView.addSubview(buttonView)
        
        let searchButton = UIButton(frame: CGRect(x: 0, y: 5, width: 20, height: 20))
        searchButton.setImage(UIImage(named: "SearchIcon"), for: .normal)
        buttonView.addSubview(searchButton)
        
        let notiButton = UIButton(frame: CGRect(x: searchButton.frame.maxX + 25, y: 5, width: 20, height: 20))
        notiButton.setImage(UIImage(named: "NotificationsInactive"), for: .normal)
        notiButton.addTarget(self, action: #selector(openNotis(_:)), for: .touchUpInside)
        buttonView.addSubview(notiButton)
        
        let notificationRef = self.db.collection("users").document(self.uid).collection("notifications")
        let query = notificationRef.whereField("seen", isEqualTo: false)
        
        /// show green bell on notifications when theres an unseen noti
        if notiListener != nil { notiListener.remove() }
        notiListener = query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in
            if err != nil || snap?.metadata.isFromCache ?? false {
                return
            } else {
                if snap!.documents.count > 0 {
                    notiButton.setImage(UIImage(named: "NotificationIconActive")?.withRenderingMode(.alwaysOriginal), for: .normal)
                }
            }
        }

        if UserDataModel.shared.userInfo != nil {
            let profileButton = UIButton(frame: CGRect(x: notiButton.frame.maxX + 25, y: 1.5, width: 27.5, height: 27.5))
            profileButton.layer.cornerRadius = profileButton.bounds.width/2
            profileButton.layer.borderColor = UIColor.white.cgColor
            profileButton.layer.borderWidth = 1.8
            profileButton.layer.masksToBounds = true
            profileButton.sd_setImage(with: URL(string: UserDataModel.shared.userInfo.imageURL), for: .normal, completed: nil)
            profileButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)
            buttonView.addSubview(profileButton)
        }
        
        return navView
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
            
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        friendsLoaded = true
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


// extension to allow touches underneath UINavigationBar
extension UINavigationBar {
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard nestedInteractiveViews(in: self, contain: point) else { return false }
        return super.point(inside: point, with: event)
    }
    
    private func nestedInteractiveViews(in view: UIView, contain point: CGPoint) -> Bool {
        if view.isPotentiallyInteractive, view.bounds.contains(convert(point, to: view)) {
            return true
        }
        
        for subview in view.subviews {
            if nestedInteractiveViews(in: subview, contain: point) {
                return true
            }
        }
        
        return false
    }
}

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

// database fetches
extension MapController {
    func getAdmins() {
        
        self.db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, err) in
            if err != nil { return }
            for admin in snap!.documents { UserDataModel.shared.adminIDs.append(admin.documentID) }
        }
        
        ///opt kenny/ellie/tyler/b0t/hog/hog0 out of tracking
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" || uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" || uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" || uid == "QgwnBsP9mlSudEuONsAsyVqvWEZ2" || uid == "X6CB24zc4iZFE8maYGvlxBp1mhb2" {
            Mixpanel.mainInstance().optOutTracking()
        }
    }
    
    func getFriends() {
        
        friendsListGroup.enter()
        friendsListGroup.enter()

        /// can maybe use get function here -> not sure what we're listening for exactly
        userListener = self.db.collection("users").document(self.uid).addSnapshotListener(includeMetadataChanges: true, listener: { (userSnap, err) in
            
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }
            
            do {
                ///get current user info
                let actUser = try userSnap?.data(as: UserProfile.self)
                guard var activeUser = actUser else { return }
                
                activeUser.id = userSnap!.documentID
                if userSnap!.documentID != self.uid { return } /// logout + object not being destroyed
                
                UserDataModel.shared.userInfo = activeUser
                self.getUserProfilePics(firstLoad: UserDataModel.shared.userInfo.id == "")
                
                UserDataModel.shared.friendIDs = userSnap?.get("friendsList") as? [String] ?? []
                for id in self.deletedFriendIDs { UserDataModel.shared.friendIDs.removeAll(where: {$0 == id}) } /// unfriended friend reentered from cache
                
                var spotsList: [String] = []
                
                /// get full friend objects for whole friends list
                var count = 0
                                
                for friend in UserDataModel.shared.friendIDs {
                    
                    if !UserDataModel.shared.friendsList.contains(where: {$0.id == friend}) {
                        var emptyProfile = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
                        emptyProfile.id = friend
                        UserDataModel.shared.friendsList.append(emptyProfile) } /// append empty here so they appear in order
                    
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard var info = friendInfo else { UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                                if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.friendsListGroup.leave() }; return }
                            
                            info.id = friendSnap!.documentID

                            if let i = UserDataModel.shared.friendsList.firstIndex(where: {$0.id == friend}) {
                                UserDataModel.shared.friendsList[i] = info
                            }
                            
                            count += 1
                            
                            /// load feed and notify nearbyVC that friends are done loading
                            if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.friendsListGroup.leave() }
                        } catch {
                            /// remove broken friend object
                            UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                            UserDataModel.shared.friendsList.removeAll(where: {$0.id == friend})
                            
                            if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.friendsListGroup.leave() }
                            return
                        }
                    }
                }
            } catch {  return }
        })
    }
    
    func getUserProfilePics(firstLoad: Bool) {
        
        var count = 0
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: URL(string: UserDataModel.shared.userInfo.imageURL), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, data, err, cache, download, url) in
            
            UserDataModel.shared.userInfo.profilePic = image ?? UIImage()
            ///post noti for profile in case user has already selected it
            
            count += 1
            if count == 2 && firstLoad {
                NotificationCenter.default.post(Notification(name: Notification.Name("InitialUserLoad"))) }
        }

        let avatarURL = UserDataModel.shared.userInfo.avatarURL ?? ""
        if (avatarURL) != "" {
            self.imageManager.loadImage(with: URL(string: avatarURL), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, data, err, cache, download, url) in
                UserDataModel.shared.userInfo.avatarPic = image ?? UIImage()

                count += 1
                if count == 2 && firstLoad {
                    NotificationCenter.default.post(Notification(name: Notification.Name("InitialUserLoad"))) }
            }
            
        } else { count += 1 }
    }
}
