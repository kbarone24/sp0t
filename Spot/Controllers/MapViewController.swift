//
//  MapViewController.swift
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

class MapViewController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var firstTimeGettingLocation = true
    
    var customTabBar: CustomTabBar!
    var tabBarLayer: CAShapeLayer!
    var regionQuery: GFSRegionQuery?
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var listener1: ListenerRegistration!
        
    let locationGroup = DispatchGroup()
    let feedGroup = DispatchGroup()
    
    /// need for pangesture methods
    weak var nearbyViewController: NearbyViewController!
    weak var spotViewController: SpotViewController!
    weak var profileViewController: ProfileViewController!
    
    var halfScreenY: CGFloat!
    var tabBarOpenY: CGFloat! /// tabBarOpenY is full screen Y when the tabBar is visible (profile only now)
    var tabBarClosedY: CGFloat! /// tabBarOpenY is full screen Y when  the tabBar is hidden (profile only now)
        
    var friendsLoaded = false
    var feedLoaded = false
    var userSpotsLoaded = false /// used for sending first spot notification
    var shouldUpdateRegion = true /// shouldUpdateRegion is true when circleQuery should update when user changes visible map
    var shouldUpdateCity = true /// shouldUpdateCity is true when nearby drawer should update city when user changes visible map
    var shouldCluster = true /// should cluster is false when nearby (tab index 1) selected and max zoom enabled
    
    var selectedSpotID: String!
    var selectedProfileID: String!
    var postAnnotation: SinglePostAnnotation!
    var nearbyAnnotations = [String: CustomSpotAnnotation]()
    var profileAnnotations = [String: CustomSpotAnnotation]()
    
    lazy var postsList: [MapPost] = []
    
    var prePanY: CGFloat! /// prePanY is the last static drawer location before user interaction
    var bottomBar: UIView! /// bottom bar is a hack to allow more space underneath closed drawer for iPhoneX+
    
    var closeFeedButton: UIButton! /// tap anywhere on map closes feed
    var toggleMapButton, userLocationButton, directionsButton, searchBarButton: UIButton! /// buttons to manipulate map appearance
    var activeFilterView: UIView! /// activeFilterView shows active filters on the map after filterView is closed
    var mapMask: UIView!
    
    lazy var filterTags: [String] = [] /// selected tag filters
    var filterUser: UserProfile! /// selected user to filter by
    
    lazy var tagUsers: [UserProfile] = [] /// users for rows in tagTable
    var tagTable: UITableView! /// tag table that shows after @ throughout app
    var tagParent: TagTableParent! /// active VC where @ was entered
    
    var tutorialView: UIView! /// tutorial view added to Window for different hand tutorials
    var tutorialImage: UIImageView!
    var tutorialText: UILabel!
    
    var imageManager: SDWebImageManager!
    
    /// use to avoid deleted documents entering from cache
    lazy var deletedSpotIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []
        
    /// tag table added over top of view to window then result passed to active VC
    enum TagTableParent {
        case comments
        case upload
        case post
    }
        
    override func viewDidLoad() {
        
        ///add tab bar controller as child -> won't even need to override methods, the tab bar controller height as a whole is manipulated so that the tab bars can be selected naturally
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        NotificationCenter.default.addObserver(self, selector: #selector(postOpen(_:)), name: NSNotification.Name("PostOpen"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectFromPost(_:)), name: NSNotification.Name("OpenSpotFromPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectFromProfile(_:)), name: NSNotification.Name("OpenSpotFromProfile"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectFromNotis(_:)), name: NSNotification.Name("OpenSpotFromNotis"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAcceptFriend(_:)), name: NSNotification.Name(("FriendRequestAccept")), object: nil)
        
        mapView = MKMapView(frame: UIScreen.main.bounds)
        mapView.delegate = self
        mapView.isUserInteractionEnabled = true
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = true
        mapView.userLocation.title = ""
        mapView.tag = 1
        mapView.register(SpotAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(SpotClusterView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.register(StandardPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "Post")
        mapView.register(PostClusterView.self, forAnnotationViewWithReuseIdentifier: "postCluster")
        mapView.register(SinglePostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "singlePost")
        
        // gesture recognizers to close drawer on user interaction with map
        let mapPan = UIPanGestureRecognizer(target: self, action: #selector(mapPan(_:)))
        mapPan.delegate = self
        mapView.addGestureRecognizer(mapPan)
        
        let mapPinch = UIPinchGestureRecognizer(target: self, action: #selector(mapPinch(_:)))
        mapPinch.delegate = self
        mapView.addGestureRecognizer(mapPinch)
        
        view.addSubview(mapView)
        
        overrideUserInterfaceStyle = .dark
        
        locationManager.delegate = self
        imageManager = SDWebImageManager()
        
        addTabBar() /// add customTabBar child
        addMapButtons() /// add map buttons and filter view
        addTagView() /// add tag table for @'ing users
        getAdmins() /// get admin users to exclude from searches (sp0tb0t, black-owned)
        
        navigationController?.navigationBar.addGradientBackground(alpha: 1.0) /// add shadow to nav bar
        
        locationGroup.enter()
        checkLocation()
        
        feedGroup.enter()
        feedGroup.enter()
        
        locationGroup.notify(queue: DispatchQueue.global()) {
            self.getFriends()
            self.getUserCity()
        }
        
        feedGroup.notify(queue: DispatchQueue.main) {
            if !self.feedLoaded {
                NotificationCenter.default.post(Notification(name: Notification.Name("InitialFriendsLoad"))) } /// full friendObjects loaded
            self.loadFeed()
        }
        
        selectedSpotID = ""
        selectedProfileID = ""
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if mapView != nil { mapView.delegate = nil }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Mixpanel.mainInstance().track(event: "MapOpen")
        if mapView != nil { mapView.delegate = self }
        setUpNavBar()
    }
    
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
        
        listener1 = self.db.collection("users").document(self.uid).addSnapshotListener(includeMetadataChanges: true, listener: { (userSnap, err) in
            
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }
            
            do {
                ///get current user info
                let actUser = try userSnap?.data(as: UserProfile.self)
                guard var activeUser = actUser else { return }
                
                activeUser.id = userSnap!.documentID
                let firstLoad = UserDataModel.shared.userInfo.id == ""
                if userSnap!.documentID != self.uid { return } /// logout + object not being destroyed
                
                UserDataModel.shared.userInfo = activeUser
                
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                self.imageManager.loadImage(with: URL(string: activeUser.imageURL), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, data, err, cache, download, url) in
                    
                    UserDataModel.shared.userInfo.profilePic = image ?? UIImage()
                    ///post noti for profile in case user has already selected it
                    if firstLoad {
                        NotificationCenter.default.post(Notification(name: Notification.Name("InitialUserLoad"))) }
                }
                
                UserDataModel.shared.friendIDs = userSnap?.get("friendsList") as? [String] ?? []
                for id in self.deletedFriendIDs { UserDataModel.shared.friendIDs.removeAll(where: {$0 == id}) } /// unfriended friend reentered from cache
                
                var spotsList: [String] = []
                
                /// get full friend objects for whole friends list
                var count = 0
                                
                for friend in UserDataModel.shared.friendIDs {
                    
                    if !UserDataModel.shared.friendsList.contains(where: {$0.id == friend}) {
                        var emptyProfile = UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")
                        emptyProfile.id = friend
                        UserDataModel.shared.friendsList.append(emptyProfile) } /// append empty here so they appear in order
                    
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard var info = friendInfo else { UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                                if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.feedGroup.leave() }; return }
                            
                            info.id = friendSnap!.documentID

                            if let i = UserDataModel.shared.friendsList.firstIndex(where: {$0.id == friend}) {
                                UserDataModel.shared.friendsList[i] = info
                            }
                            
                            count += 1
                            
                            /// load feed and notify nearbyVC that friends are done loading
                            if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.feedGroup.leave() }
                        } catch {
                            /// remove broken friend object
                            UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                            UserDataModel.shared.friendsList.removeAll(where: {$0.id == friend})
                            
                            if count == UserDataModel.shared.friendIDs.count && !self.friendsLoaded { self.feedGroup.leave() }
                            return
                        }
                    }
                }
                
                //get users spots list for nearby query
                self.db.collection("users").document(self.uid).collection("spotsList").getDocuments { (spotsSnap, err) in
                    if err == nil {
                        for doc in spotsSnap!.documents {
                            spotsList.append(doc.documentID)
                            if spotsList.count == spotsSnap?.documents.count {
                                UserDataModel.shared.userSpots = spotsList
                                self.userSpotsLoaded = true 
                                if self.searchPageOpen() { self.loadNearbySpots() }
                            }
                        }
                        
                    }
                }
            } catch {  return }
        })
    }
    
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        friendsLoaded = true
    }
    
    @objc func notifyAcceptFriend(_ notification: NSNotification) {
        /// notify accept so that friendIDs immediately so that the app recognizes the new friend as a friend everywhere, esp profile
        if let friendID = notification.userInfo?.first?.value as? String {
            if !UserDataModel.shared.friendIDs.contains(friendID) { UserDataModel.shared.friendIDs.append(friendID) }
        }
    }
    
    func setUpNavBar() {
        switch customTabBar.selectedIndex {
        case 0:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
            setOpaqueNav()
        case 1:
            navigationController?.setNavigationBarHidden(true, animated: false)
            navigationItem.titleView = nil
        case 3:
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItem = nil
            setOpaqueNav()
            navigationItem.titleView = nil
            navigationItem.title = "Notifications"
        case 4:
            setTranslucentNav()
            
        default:
            print("default")
        }
    }
    
    func setOpaqueNav() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
        navigationController?.navigationBar.addShadow()
    }
    
    func setTranslucentNav() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.removeBackgroundImage()
        navigationController?.navigationBar.removeShadow()
    }
    
    func getCity(completion: @escaping (_ city: String) -> Void) {
        reverseGeocodeFromCoordinate(numberOfFields: 2, location: UserDataModel.shared.currentLocation) { city in
            completion(city)
        }
    }
    
    func getUserCity() {
        getCity { city in
            UserDataModel.shared.userCity = city
            self.feedGroup.leave()
        }
    }
    
    func loadFeed() {
        
        if feedLoaded { return }
        NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
        
        if let feedVC = self.customTabBar.viewControllers?[0] as? FeedViewController {
            feedLoaded = true
            let selectedIndex = UserDataModel.shared.friendIDs.count > 3 ? 0 : 1
            feedVC.addFeedSeg(selectedIndex: selectedIndex)
            feedVC.friendsRefresh = .refreshing
            selectedIndex == 0 ?  feedVC.getFriendPosts(refresh: false) : feedVC.getNearbyPosts(radius: 0.5)
        }
    }
    
    /// close the drawer when user pans the map a decent amount
    @objc func mapPan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: mapView)
        let direction = sender.velocity(in: mapView)
        if (sender.state == .changed && (abs(translation.x) > 120 || abs(translation.y) > 120)) || ((sender.state == .ended || sender.state == .cancelled) && (abs(direction.x) > 300 || abs(direction.y) > 300)) {
            if customTabBar.view.frame.minY == halfScreenY {
                if profileViewController != nil && profileViewController.userInfo.id == uid && UserDataModel.shared.userInfo.spotsList.count == 0 { return } /// patch fix for not closing the drawer on new user
                self.animateClosed()
            }
        }
    }
    
    /// close the drawer on a pinch gesture
    @objc func mapPinch(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .changed && abs(1 - sender.scale) > 0.2 {
            if customTabBar.view.frame.minY == halfScreenY {
                if profileViewController != nil && profileViewController.userInfo.id == uid && UserDataModel.shared.userInfo.spotsList.count == 0 { return } /// patch fix for not closing the drawer on new user
                self.animateClosed()
            }
        }
    }
    
     
    //filterPrivacy true when deselected (filtered)
    
    func addTabBar() {
        
        if let tabBar = storyboard?.instantiateViewController(withIdentifier: "TabBarMain") as? CustomTabBar {
            self.customTabBar = tabBar
            
            self.addChild(customTabBar)
            self.view.addSubview(customTabBar.view)
            customTabBar.didMove(toParent: self)
            customTabBar.delegate = self
            
            if let addLaunch = customTabBar.tabBar.items?[2] {
                addLaunch.image = UIImage(named: "HomeInactive")?.withRenderingMode(.alwaysOriginal)
                addLaunch.selectedImage = UIImage(named: "HomeInactive")?.withRenderingMode(.alwaysOriginal)
            }
            
            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            let safeBottom = window?.safeAreaInsets.bottom ?? 0
            let tabBarHeight = customTabBar.tabBar.frame.height + safeBottom
                
            halfScreenY = UIScreen.main.bounds.height - tabBarHeight - 350
            tabBarOpenY = UserDataModel.shared.largeScreen ? UIScreen.main.bounds.height - (UIScreen.main.bounds.width * 1.72267 + tabBarHeight) : UIScreen.main.bounds.height - (UIScreen.main.bounds.width * 1.5 + tabBarHeight)
            tabBarClosedY = tabBarOpenY + 30

            customTabBar.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: UIScreen.main.bounds.height)
            customTabBar.view.clipsToBounds = true

            //   let tabBarHeight = customTabBar.tabBar.bounds.height
            if UserDataModel.shared.largeScreen {
                customTabBar.view.layer.cornerRadius = 10
                customTabBar.view.layer.cornerCurve = .continuous
            } else {
                tabBarLayer = CAShapeLayer()
                tabBarLayer.path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 10, height: 10)).cgPath
                customTabBar.view.layer.mask = tabBarLayer
            }
                
            self.prePanY = halfScreenY
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
            panGesture.delegate = self
            customTabBar.view.addGestureRecognizer(panGesture)
            
        }
    }
    
    @objc func closeDrawer(_ sender: UIBarButtonItem) {
        self.animateClosed()
    }
    
    func pushUploadPost() {
        
        customTabBar.view.isUserInteractionEnabled = false
        customTabBar.pushCamera()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.customTabBar.view.isUserInteractionEnabled = true
        }
    }
        
    func profileUploadReset(spotID: String, postID: String, tags: [String]) {

        /// patch for hiding feed
        if let feedVC = customTabBar.viewControllers?[0] as? FeedViewController { feedVC.hideFeedSeg() }
        guard let profileVC = customTabBar.viewControllers?[4] as? ProfileViewController else { return }
        
        profileVC.mapVC = self
        profileVC.openSpotID = spotID
        profileVC.openPostID = postID
        profileVC.openSpotTags = tags
        
        profileVC.resetMap()
        profileVC.setUpNavBar()
        if profileVC.selectedIndex != 0 { profileVC.resetIndex(index: 0) }
        customTabBar.selectedIndex = 4
    }
    
    /// custom reset nav bar (patch fix for CATransition)
    func uploadMapReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if self.customTabBar.selectedIndex != 0 { return }
            self.navigationController?.navigationBar.alpha = 1.0
            self.setUpNavBar()
        }
    }
    
    func feedUploadReset() {
        
        customTabBar.selectedIndex = 0
        
        // reset map after post upload
        self.prePanY = 0
        customTabBar.view.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        
        postsList.removeAll()
        hideNearbyButtons()
        
        let annotations = mapView.annotations
        mapView.removeAnnotations(annotations)
        
        if let feedVC = self.customTabBar.viewControllers![0] as? FeedViewController {
            self.postsList = feedVC.selectedSegmentIndex == 0 ? feedVC.friendPosts : feedVC.nearbyPosts
            if feedVC.postVC != nil {
                self.addSelectedPostToMap(index: feedVC.postVC.selectedPostIndex, parentVC: .feed)
            }
        }
    }
    
    
    @objc func feedSegValueChanged(_ sender: UISegmentedControl) {
        print("value changed")
    }
    
    func toggleMapTouch(enable: Bool) {
        
        /// map touch closes the drawer on post page when user interacts with the map
        if enable {
            if closeFeedButton != nil { return }
            closeFeedButton = UIButton(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
            closeFeedButton.backgroundColor = nil
            closeFeedButton.addTarget(self, action: #selector(closeFeedTap(_:)), for: .touchUpInside)
            closeFeedButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(closeFeedPan(_:))))
            closeFeedButton.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(closeFeedPinch(_:))))
            
            mapView.addSubview(closeFeedButton)
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = false
            
        } else {
            
            if closeFeedButton != nil { closeFeedButton.removeFromSuperview() }
            closeFeedButton = nil
            
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
        }
    }
    
    @objc func closeFeedTap(_ sender: UIButton) { /// close feed on tap
        Mixpanel.mainInstance().track(event: "MapCloseFeedTap")
        closeFeed()
    }
    
    @objc func closeFeedPan(_ sender: UIPanGestureRecognizer) { /// close feed on pan
        Mixpanel.mainInstance().track(event: "MapCloseFeedPan")
        closeFeed()
    }
    
    @objc func closeFeedPinch(_ sender: UIPinchGestureRecognizer) { /// close feed on pinch
        Mixpanel.mainInstance().track(event: "MapCloseFeedPinch")
        closeFeed()
    }
    
    func closeFeed() {
        
        if spotViewController != nil {
            guard let postVC = spotViewController.children.first as? PostViewController else { return }
            postVC.closeDrawer(swipe: false)
            
        } else if profileViewController != nil {
            guard let firstVC = self.profileViewController.children.first(where: {$0.isKind(of: ProfilePostsViewController.self)}) as? ProfilePostsViewController else { return }
            guard let postVC = firstVC.children.first as? PostViewController else { return }
            postVC.closeDrawer(swipe: false)
            
        } else if customTabBar.selectedIndex == 0 {
            guard let feedVC = customTabBar.viewControllers?[0] as? FeedViewController else { return }
            guard let postVC = feedVC.children.first as? PostViewController else { return }
            postVC.closeDrawer(swipe: false)
            
        } else if customTabBar.selectedIndex == 3 {
            guard let notificationsVC = customTabBar.viewControllers?[0] as? FeedViewController else { return }
            guard let postVC = notificationsVC.children.first as? PostViewController else { return }
            postVC.closeDrawer(swipe: false)
        }
    }
    
    
    @objc func postOpen(_ sender: NSNotification) {
        
        if let infoPass = sender.userInfo as? [String: Any] {
            /// if selected from nearby posts set postslist from there (only sent from nearby)
            
            guard let firstOpen = infoPass["firstOpen"] as? Bool else { return }
            guard let selectedPost = infoPass["selectedPost"] as? Int else { return }
            guard let parentVC = infoPass["parentVC"] as? PostViewController.parentViewController else { return }
            ///  guard let parentVC = infoPass["parentVC"] as? String else { return }
            self.mapView.removeAnnotations(self.mapView.annotations)
            
            if firstOpen {
                self.animateToFullScreen()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self = self else { return }
                    self.addSelectedPostToMap(index: selectedPost, parentVC: parentVC)}
                
            } else { self.addSelectedPostToMap(index: selectedPost, parentVC: parentVC) }
        }
    }
    
    // add current feed post to map and offset so it shows in the window above drawer
    func addSelectedPostToMap(index: Int, parentVC: PostViewController.parentViewController) {
        
        if index >= postsList.count { return }
        let post = postsList[index]
        let lat = post.postLat
        let long = post.postLong
        let postCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        
        postAnnotation = SinglePostAnnotation()
        postAnnotation.coordinate = postCoordinate
        postAnnotation.id = post.id
        
        self.mapView.addAnnotation(postAnnotation)
        
        var offset = UIScreen.main.bounds.height/2 - self.customTabBar.view.frame.minY/2 - 25
        if !UserDataModel.shared.largeScreen { offset += 20 }
        if self.customTabBar.tabBar.isHidden { offset -= 10 }
        
        var distance: Double = 0
        
        switch parentVC {
        case .spot:
            distance = 750
        default:
            distance = 100000
        }
        
        if locationIsEmpty(location: UserDataModel.shared.currentLocation) { return }
        let adjust = 0.00000845 * distance /// adjust coordinate to show centered above drawer

        let adjustedCoordinate = CLLocationCoordinate2D(latitude: postAnnotation.coordinate.latitude - adjust, longitude: postAnnotation.coordinate.longitude)
        self.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: distance, longitudinalMeters: distance), animated: false)
    }
    
    func searchPageOpen() -> Bool {
        return nearbyViewController != nil
    }
    
    func checkLocation() {

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

extension MapViewController: CLLocationManagerDelegate {
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
            mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 400000, longitudinalMeters: 400000), animated: false)
            var offset = UIScreen.main.bounds.height/2 - customTabBar.view.frame.minY/2 - 25
            if !UserDataModel.shared.largeScreen { offset += 20 }
            offsetCenterCoordinate(selectedCoordinate: location.coordinate, offset: offset, animated: false, region: MKCoordinateRegion())
            
            self.firstTimeGettingLocation = false
            locationGroup.leave()
            
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
        }
    }
    
    func animateToUserLocation(animated: Bool) {

        if locationIsEmpty(location: UserDataModel.shared.currentLocation){ return }
        if nearbyViewController != nil { nearbyViewController.resetToUserCity() }
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude - 0.0085, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)
        DispatchQueue.main.async { self.mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 2000, longitudinalMeters: 2000), animated: animated) }
    }
    
    func animateToProfileLocation(active: Bool, coordinate: CLLocationCoordinate2D) {
        /// for active user profile, animate to current user location
        if active {
            if locationIsEmpty(location: UserDataModel.shared.currentLocation) { return }
            let adjustedCoordinate = CLLocationCoordinate2D(latitude: UserDataModel.shared.currentLocation.coordinate.latitude - 0.0085, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)
            mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 2000, longitudinalMeters: 2000), animated: false)
        } else {
            /// for friend profile, hide user location and animate to most recent post (zoomed out)
            mapView.showsUserLocation = false
            if coordinate.latitude != 0.0 {
                let adjustedCoordinate = CLLocationCoordinate2D(latitude: coordinate.latitude - 0.85, longitude: coordinate.longitude)
                mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 200000, longitudinalMeters: 200000), animated: true)
            }
        }
    }
}

extension MapViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        
        if let feedVC = viewController as? FeedViewController {
            feedVC.mapVC = self
            if customTabBar.selectedIndex == 0 { feedVC.openOrScrollToFirst(animated: true, newPost: false); return true }
            Mixpanel.mainInstance().track(event: "FeedOpen")
            feedUploadReset()
            
            // add all removed annos to map
        } else if viewController.isKind(of: AVCameraController.self) {
            self.pushUploadPost()
            return false
            
        } else if let nearbyVC = viewController as? NearbyViewController {
            
            if customTabBar.selectedIndex == 1 { nearbyVC.resetOffsets() }
            nearbyVC.mapVC = self
            
        } else if let profileVC = viewController as? ProfileViewController {
            
            animateToProfileLocation(active: true, coordinate: CLLocationCoordinate2D())
            if customTabBar.selectedIndex == 4 { profileVC.profileToHalf();  return true }
            
            profileVC.mapVC = self
            profileVC.resetMap()
            profileVC.setUpNavBar()
            
            profileVC.scrollDistance > 0 ? profileVC.expandProfile(reset: false) : profileVC.profileToHalf()
            
        } else if let notiVC = viewController as? NotificationsViewController {

            if customTabBar.selectedIndex != 3 {
                notiVC.mapVC = self
            } else {
                notiVC.scrollToFirstRow()
            }
        }
        
        return true
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        setUpNavBar()
    }
}

extension MapViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.view?.tag == 16 || otherGestureRecognizer.view?.tag == 23 || otherGestureRecognizer.view?.tag == 30 {
            return false
        }
        return true
    }
    
    func drawerIsOffset() -> Bool {
        if customTabBar.view.frame.minY != prePanY { return true }
        return false
    }
    
    func swipeToRemoveBegan() -> Bool {
        let activeView = spotViewController != nil ? spotViewController.view : profileViewController != nil ? profileViewController.view : UIView()
        if activeView == UIView() { return false }
        return activeView?.frame.minX != 0
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        //tab bar view will have 3 states - full-screen, half-screen, closed
        let translation = recognizer.translation(in: view)
        let velocity = recognizer.velocity(in: view)
        
        /// swipe to exit from profile or spot page if swiping to the right
        if abs(translation.y) <= abs(translation.x) || swipeToRemoveBegan() {
            if ((spotViewController != nil && spotViewController.selectedIndex == 0 || (profileViewController != nil && profileViewController.parent != customTabBar && profileViewController.selectedIndex == 0)) && !drawerIsOffset()) || swipeToRemoveBegan() {
            swipeToExit(translation: translation.x, velocity: velocity.x, state: recognizer.state)
            return

            /// else if horizontal swipe only follow pan if user already began offsetting the drawer
            } else if !drawerIsOffset() { return }
        }
        
        /// should recognize gesture recognizer only for Profile, Spot, Nearby -> switch pan type based on
        nearbySwipe(translation: translation.y, velocity: velocity.y, state: recognizer.state)
    }
    
    func nearbySwipe(translation: CGFloat, velocity: CGFloat, state: UIGestureRecognizer.State) {

        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let safeBottom = window?.safeAreaInsets.bottom ?? 0
        let tabBarHeight = customTabBar.tabBar.frame.height + safeBottom
        let closedY = tabBarHeight + 84
        
        func followPan() {
            //need to adjust tableView
            let newHeight = UIScreen.main.bounds.height - prePanY - translation
            self.customTabBar.view.frame = CGRect(x: 0, y: prePanY + translation, width: UIScreen.main.bounds.width, height: newHeight)
            
            if spotViewController != nil {
                let barAlpha: CGFloat = prePanY + translation < halfScreenY ? (halfScreenY - (prePanY + translation))/halfScreenY : 0
                navigationController?.navigationBar.isTranslucent = true
                navigationController?.navigationBar.addGradientBackground(alpha: barAlpha)
            }
            
            if profileViewController != nil {
                /// darken nav bar for smoother profile animation
                let barAlpha: CGFloat = prePanY + translation < halfScreenY ? (halfScreenY - (prePanY + translation))/halfScreenY : 0
                navigationController?.navigationBar.isTranslucent = true
                navigationController?.navigationBar.addGradientBackground(alpha: barAlpha)
                offsetProfile(level: prePanY + translation)
            }
        }
        
        if nearbyViewController == nil && profileViewController == nil && spotViewController == nil { return }
        if profileViewController != nil && profileViewController.addFirstSpotButton != nil { return } /// dont animate on profile empty state
        
        ///if spotvc or profilevc != nil, that vc is active
        if let activeTable = spotViewController != nil ? spotViewController.shadowScroll : profileViewController != nil ? profileViewController.shadowScroll : nearbyViewController != nil ? nearbyViewController.shadowScroll : UITableView() {
            ///hacky fix to avoid nearbyvc = nil
            if activeTable == UITableView() { return }
            
            switch state {
            case .changed:
                /// check first to see if we're moving the drawer - this would follow the standard animations
                if translation < 0 {
                    
                    if self.prePanY >= UIScreen.main.bounds.height - closedY {
                        followPan()
                        activeTable.isScrollEnabled = false
                        
                    } else if self.prePanY == halfScreenY {
                        followPan()
                        activeTable.isScrollEnabled = false
                    } ///else screen is open and we  defer to interior methods
                    
                } else {
                    /// y == 0 and content offset of table view is 0 - sometimes
                    if self.prePanY <= 1 && activeTable.contentOffset.y < 0.1 {
                        followPan()
                        activeTable.isScrollEnabled = false
                        
                        ///else screen already closed
                    } else if self.prePanY == halfScreenY {
                        followPan()
                        activeTable.isScrollEnabled = false
                        
                        /// if profile is at seg view, offset profile or spot
                    } else if profileAt0(activeOffset: activeTable.contentOffset.y) || spotAt0(activeOffset: activeTable.contentOffset.y) {
                        followPan()
                        activeTable.isScrollEnabled = false
                    }
                }
                
            case .ended, .cancelled:
                
                let finalOffset = velocity + translation
                
                if velocity < 0 || velocity == 0 && finalOffset < 0 {
                    
                    /// dont want to recognize up gesture at 0 (table will scroll)
                    if customTabBar.view.frame.minY == prePanY { return }
                    
                    if prePanY > halfScreenY {
                        /// drawer is closed, animate to half screen or full on big swipe
                        prePanY + finalOffset < halfScreenY && translation < -200 ? animateToFullScreen() : abs(finalOffset) > 100 ? animateToHalfScreen() : animateClosed()
                        
                    } else {
                        /// animate back to full screen if swipe is going up, stay at half if not moved enough
                        finalOffset < -100 ? animateToFullScreen() : animateToHalfScreen()
                    }
                    
                } else if activeTable.contentOffset.y < 0.1 || searchShowing() || profileAt0(activeOffset: activeTable.contentOffset.y) || spotAt0(activeOffset: activeTable.contentOffset.y) {
                    /// y == 0 and content offset of table view is 0, or search is showing on nearby, or profile/spot has reached sec0
                    /// animate to half if velocity or displacement is sufficient
                    
                    if prePanY < 200 {

                        if prePanY + finalOffset > halfScreenY && translation > 200 {
                            prePanY + finalOffset > halfScreenY ? animateClosed() : animateToHalfScreen()
                        
                        } else {
                            finalOffset > 100 ? animateToHalfScreen() : animateClosed()
                        }
                        //drawer is full screen, animate to half screen, check for standard and for nearby height
                    } else {
                        animateClosed()
                    }
                }
                
            default:
                return
            }
        }
    }
    
    func swipeToExit(translation: CGFloat, velocity: CGFloat, state: UIGestureRecognizer.State) {
                
        guard let activeTable = spotViewController != nil ? spotViewController.shadowScroll : profileViewController != nil ? profileViewController.shadowScroll : UITableView() else { return }
        guard let activeView = spotViewController != nil ? spotViewController.view : profileViewController.view else { return }

        func resetFrame() {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2) {
                    activeView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                }
            }
        }

        switch state {
                    
        case .changed:
            if (translation <= 0 && activeView.frame.minY == 0) || (activeTable.isDragging || activeTable.isDecelerating) { return } /// don't want to be able to offset in the other direction
            DispatchQueue.main.async { activeView.frame = CGRect(x: translation, y: activeView.frame.minY, width: activeView.frame.width, height: activeView.frame.height) }
            
        case .ended:
            if velocity + translation > UIScreen.main.bounds.width * 3/4 {
                spotViewController != nil ? spotViewController.animateRemoveSpot() : profileViewController.animateRemoveProfile()
            } else {
                resetFrame()
            }
            
        default: return
        }
    }
    
    func animateClosed() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let safeBottom = window?.safeAreaInsets.bottom ?? 0
        let tabBarHeight = customTabBar.tabBar.frame.height

        let closedY = !customTabBar.tabBar.isHidden ? tabBarHeight + 84 : safeBottom + 115
        let largeBar = spotViewController != nil && UserDataModel.shared.largeScreen
        let bottomBarMode = (customTabBar.tabBar.isHidden && UserDataModel.shared.largeScreen) || spotViewController != nil
        /// add bottombar to cover the bottom area on large screens. Always add for spotViewController to cover the friends section header
        if bottomBarMode { addBottomBar(largeBar: largeBar) }
        
        DispatchQueue.main.async {
            
            if self.spotViewController != nil {
                
                self.spotViewController.tableView.isScrollEnabled = false
                self.setSpotSubviews(open: false)
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.navigationBar.removeBackgroundImage()
                self.navigationController?.navigationBar.removeShadow()
                if self.spotViewController.selectedIndex == 0 { self.addToSpotTransition(alpha: 0.0) }
                
            } else if self.profileViewController != nil {
                self.profileViewController.shadowScroll.isScrollEnabled = false
                self.setProfileSubviews(open: false)
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.navigationBar.removeBackgroundImage()
                self.navigationController?.navigationBar.removeShadow()

            } else if self.prePanY <= 1 && self.nearbyViewController != nil {
                self.nearbyViewController.closeSearch() }
                        
            UIView.animate(withDuration: 0.15, animations: {
                self.customTabBar.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - closedY, width: self.view.frame.width, height: closedY)
                if bottomBarMode { self.bottomBar.alpha = 1.0 } /// animate adding of bottom bar to cover content on bottom of the screen
            })
            
            self.prePanY = UIScreen.main.bounds.height - closedY
            
            if self.nearbyViewController != nil {
                self.unhideNearbyButtons(nearby: true)
                self.nearbyViewController.offsetCityName(position: 0)
                
            } else if self.profileViewController != nil {
                self.unhideNearbyButtons(nearby: false)
                
            } else if self.spotViewController != nil {
                self.unhideSpotButtons()
            }
        }
    }
    
    func animateToHalfScreen() {
        
        removeBottomBar()
        DispatchQueue.main.async {
            
            if self.spotViewController != nil {
                self.halfScreenNavBarTransition() /// transtion nav bar background remove
                self.setSpotSubviews(open: false)
                self.spotViewController.tableView.isScrollEnabled = false
                if self.spotViewController.selectedIndex == 0 { self.addToSpotTransition(alpha: 1.0) } /// animate addToSpotButton add
                
            } else if self.profileViewController != nil {
                if self.profileViewController.shadowScroll == nil { return }
                self.profileViewController.shadowScroll.isScrollEnabled = false
                self.setProfileSubviews(open: false)
                self.halfScreenNavBarTransition() /// transtion nav bar background remove
                self.hideNearbyButtons() /// hide map buttons
                
            } else if self.nearbyViewController != nil {
                self.hideNearbyButtons()
                self.nearbyViewController.closeSearch()
            }

            UIView.animate(withDuration: 0.15, animations: { self.customTabBar.view.frame = CGRect(x: 0, y: self.halfScreenY, width: self.view.frame.width, height: self.view.frame.height - self.halfScreenY)
            })
                        
            self.prePanY = self.halfScreenY
        }
    }
    
    func addToSpotTransition(alpha: CGFloat) {
        
        if alpha == 1.0 && spotViewController.addToSpotButton.isHidden {
            spotViewController.addToSpotButton.alpha = 0.0
            spotViewController.addToSpotButton.isHidden = false
        }
        
        UIView.animate(withDuration: 0.15, animations: { self.spotViewController.addToSpotButton.alpha = alpha })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self = self else { return }
            if alpha == 0.0 {
                if self.spotViewController == nil { return }
                self.spotViewController.addToSpotButton.isHidden = true
                self.spotViewController.addToSpotButton.alpha = 0.0
            }
        }
    }
    
    func halfScreenNavBarTransition() {
        /// reset profile nav bar to clear
        UIView.transition(with: self.navigationController!.navigationBar, duration: 0.15, options: .transitionCrossDissolve, animations: {
            self.navigationController?.navigationBar.addGradientBackground(alpha: 0.0)
            self.navigationController?.navigationBar.removeShadow()
            self.navigationController?.navigationBar.isTranslucent = true
        }, completion: { _ in self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default) })
    }
    
    func animateToFullScreen() {
        
        removeBottomBar()
        self.prePanY = 0
        
        DispatchQueue.main.async {
            
            if self.spotViewController != nil {
                self.animateSpotToFull()
                self.hideSpotButtons()
                
            } else if self.profileViewController != nil {
                self.animateProfileToFull()
                self.hideNearbyButtons()
                
            } else if self.nearbyViewController != nil {
                self.nearbyViewController.animateToFull()
                self.hideNearbyButtons()
                
            } else {
                
                self.prePanY = 0
                self.customTabBar.view.frame = CGRect(x: 0, y: self.prePanY, width: self.view.frame.width, height: self.view.frame.height - self.prePanY)
            }
        }
    }
    
    func animateSpotToFull() {
        
        prePanY = 0

        UIView.animate(withDuration: 0.15) {

            self.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            self.navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
            self.navigationController?.navigationBar.removeShadow()
            self.navigationController?.navigationBar.isTranslucent = false
            
            self.spotViewController.shadowScroll.isScrollEnabled = true
            if self.spotViewController.selectedIndex == 0 { self.addToSpotTransition(alpha: 1.0) }
            self.setSpotSubviews(open: true)
        }
    }
    
    func animateProfileToFull() {
    
        UIView.animate(withDuration: 0.15, animations: {
            self.customTabBar.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
            self.navigationController?.navigationBar.addGradientBackground(alpha: 1.0)
            self.navigationController?.navigationBar.isTranslucent = false
            self.setProfileSubviews(open: true)
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            
            guard let self = self else { return }

            if self.profileViewController == nil { return }
            switch self.profileViewController.selectedIndex {
            
            case 0:
                guard let firstVC = self.profileViewController.children.first(where: {$0.isKind(of: ProfileSpotsViewController.self)}) as? ProfileSpotsViewController else { return }
                self.profileViewController.shadowScroll.isScrollEnabled = firstVC.loaded

            case 1:
                guard let secondVC = self.profileViewController.children.first(where: {$0.isKind(of: ProfilePostsViewController.self)}) as? ProfilePostsViewController else { return }
                self.profileViewController.shadowScroll.isScrollEnabled = secondVC.loaded

                
            default:
                return
            }
        }
    }
    
    func searchShowing() -> Bool {
        return nearbyViewController != nil && !nearbyViewController.resultsTable.isHidden
    }
    
    func profileAt0(activeOffset: CGFloat) -> Bool {
        return profileViewController != nil && activeOffset <= profileViewController.sec0Height
    }
    
    func spotAt0(activeOffset: CGFloat) -> Bool {
        return spotViewController != nil && activeOffset <= self.spotViewController.sec0Height
    }
    
    func setSpotSubviews(open: Bool) {
        
        if spotViewController == nil { return }
        let minY = open ? spotViewController.sec0Height : 0

         spotViewController.tableView.setContentOffset(CGPoint(x: spotViewController.tableView.contentOffset.x, y: minY), animated: false)
         spotViewController.shadowScroll.setContentOffset(CGPoint(x: spotViewController.shadowScroll.contentOffset.x, y: minY), animated: false)
    }
        
    func offsetProfile(level: CGFloat) {
        /// incrementally offset profile as drawer drags down
        if profileViewController == nil { return }
        let offset = max(0, profileViewController.sec0Height - level / halfScreenY * profileViewController.sec0Height)
        
        if profileViewController.tableView != nil {  profileViewController.tableView.setContentOffset(CGPoint(x: profileViewController.tableView.contentOffset.x, y: offset), animated: false) }
        if profileViewController.shadowScroll != nil { profileViewController.shadowScroll.setContentOffset(CGPoint(x: profileViewController.shadowScroll.contentOffset.x, y: offset), animated: false) }
    }
        
    func setProfileSubviews(open: Bool) {
        /// reset profile subviews to match drawer state
        if profileViewController == nil { return }
        let minY = open ? profileViewController.sec0Height : 0

        if profileViewController.tableView != nil {  profileViewController.tableView.setContentOffset(CGPoint(x: profileViewController.tableView.contentOffset.x, y: minY), animated: false) }
        if profileViewController.shadowScroll != nil { profileViewController.shadowScroll.setContentOffset(CGPoint(x: profileViewController.shadowScroll.contentOffset.x, y: minY), animated: false) }
        if !open {
            profileViewController.resetSegs()
        }
    }
    
    func addBottomBar(largeBar: Bool) {
        if bottomBar != nil && bottomBar.superview != nil { return }
        let offset: CGFloat = largeBar ? 47 : 40 /// need to cover a larger area for spotVC
        bottomBar = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - offset, width: UIScreen.main.bounds.width, height: offset))
        bottomBar.backgroundColor = UIColor(named: "SpotBlack")
        bottomBar.alpha = 0.0 /// set alpha on animation
        view.addSubview(bottomBar)
    }
    
    func removeBottomBar() {
        if bottomBar != nil { bottomBar.removeFromSuperview() }
    }
}

//functions for loading nearby spots in nearby view
extension MapViewController: MKMapViewDelegate {
    
    func loadNearbySpots() {
        // run circle query to get nearby spots
        let radius = self.mapView.currentRadius()
        
        if !self.nearbyAnnotations.isEmpty { filterSpots(refresh: true) }
        
        if locationIsEmpty(location: UserDataModel.shared.currentLocation) || radius == 0 || radius > 6000 { return }
        
        regionQuery = geoFirestore.query(inRegion: mapView.region)
        DispatchQueue.global(qos: .userInitiated).async { let _ = self.regionQuery?.observe(.documentEntered, with: self.loadSpotFromDB) }
    }
    
    func loadSpotFromDB(key: String?, location: CLLocation?) {
        // 1. check that marker isn't already shown on map
        if key == nil || key == "" || self.nearbyAnnotations.contains(where: {$0.key == key}) { return }

        // 2. prepare new marker -> load all spot-level data needed, ensure user has privacy level access
        let annotation = CustomSpotAnnotation()
        guard let coordinate = location?.coordinate else { return }
        annotation.coordinate = coordinate
        
        self.db.collection("spots").document(key!).getDocument { (spotSnap, err) in
            guard let doc = spotSnap else { return }
            
            do {
                
                let spotIn = try doc.data(as: MapSpot.self)
                guard var spotInfo = spotIn else { return }
                
                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                
                if !self.hasSpotAccess(spot: spotInfo) { return }
                
                annotation.spotInfo = spotInfo
                annotation.title = spotInfo.spotName
                
                // 3. add new marker to map and to markers dictionary/list
                
                // 4. check if any filters have been called on search page that would filter out this spot
                    
                if self.spotFilteredByTag(tags: spotInfo.tags) || self.spotFilteredByLocation(spotCoordinates: CLLocationCoordinate2D(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)) || self.spotFilteredByUser(visitorList: spotInfo.visitorList) || !self.postsList.isEmpty || self.selectedSpotID != "" || self.selectedProfileID != "" {
                    // 5. call method on search page that determines whether this spot will be displayed in drawer
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
            
            if deletedSpotIDs.contains(id) { return }
            
            nearbyAnnotations.updateValue(annotation, forKey: id)
                        
            let rank = getMapRank(spot: annotation.spotInfo)
            annotation.rank = rank
            nearbyAnnotations[id]?.rank = rank
            
            if !hidden  && (self.postsList.isEmpty || self.selectedSpotID != "") {
                self.nearbyAnnotations[id]?.isHidden = false
                
                DispatchQueue.main.async {
                    if self.nearbyViewController != nil {
                        self.mapView.addAnnotation(annotation)
                    }
                }
            }
        }
    }
        
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        if annotation is MKUserLocation { return nil }
      
        //posts list is not empty whenever post page is open
        if postsList.isEmpty && (self.selectedSpotID == "" || self.selectedProfileID != "") {
            
            // spot banner view
            if let anno = annotation as? CustomSpotAnnotation {
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier) as? SpotAnnotationView
                if annotationView == nil {
                    annotationView = SpotAnnotationView(annotation: anno, reuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
                }
                else {
                    annotationView!.annotation = annotation
                }
                
                if self.shouldCluster {
                    annotationView?.clusteringIdentifier = Bundle.main.bundleIdentifier! + ".SpotAnnotationView"
                } else {
                    annotationView?.clusteringIdentifier = nil
                }
                
                var spotInfo: MapSpot!
                /// fetch spot from list of user annos from profile or from list of map spots from nearby
                if let spot = self.nearbyAnnotations.first(where: {$0.value.coordinate.latitude == annotation.coordinate.latitude && $0.value.coordinate.longitude == annotation.coordinate.longitude}) {
                    spotInfo = spot.value.spotInfo
                } else if let spot = self.profileAnnotations.first(where: {$0.value.coordinate.latitude == annotation.coordinate.latitude && $0.value.coordinate.longitude == annotation.coordinate.longitude}) {
                    spotInfo = spot.value.spotInfo
                } else { return annotationView }
                
                let nibView = loadSpotNib()
                nibView.spotNameLabel.lineBreakMode = .byTruncatingTail
                nibView.spotNameLabel.text = spotInfo.spotName
                
                let temp = nibView.spotNameLabel
                temp?.sizeToFit()
                nibView.resizeBanner(width: temp?.frame.width ?? 0)
                
                let nibImage = nibView.asImage()
                annotationView!.image = nibImage
                annotationView!.spotID = spotInfo.id ?? ""
                //   nibView.spotImageView.image =
                return annotationView
                
            } else if annotation is MKClusterAnnotation {
                // spot banner view as cluster
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? SpotClusterView
                
                if annotationView == nil {
                    annotationView = SpotClusterView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
                }
                else { annotationView?.annotation = annotation }
                
                if selectedProfileID == "" {
                    annotationView?.updateImage(annotations: Array(nearbyAnnotations.values))
                } else {
                    annotationView?.updateImage(annotations: Array(profileAnnotations.values))
                }
                
                return annotationView
            } else {
                // generic spot icon on fall through
                let annotationView = MKAnnotationView()
                annotationView.annotation = annotation
                annotationView.image = UIImage(named: "RainbowSpotIcon")
                annotationView.clusteringIdentifier = nil
                return annotationView
            }
            
        } else if annotation is CustomPointAnnotation {
            // post annotation for spot page
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "Post") as? StandardPostAnnotationView
            if annotationView == nil {
                annotationView = StandardPostAnnotationView(annotation: annotation, reuseIdentifier: "Post")
            } else {
                annotationView!.annotation = annotation
            }
            
            if let post = self.postsList.last(where: {$0.postLat == annotation.coordinate.latitude && $0.postLong == annotation.coordinate.longitude}) {
                
                annotationView!.updateImage(post: post)
                annotationView!.spotID = post.id ?? ""
                annotationView!.clusteringIdentifier = "postCluster"
                annotationView!.centerOffset = CGPoint(x: 6.25, y: -26)
                annotationView!.isSelected = true
                return annotationView
            }
            
        } else if let anno = annotation as? MKClusterAnnotation {
            // post cluster for spot page
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "postCluster") as? PostClusterView
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier) as? PostClusterView
            }
            else {
                annotationView!.annotation = annotation
            }
            annotationView?.updateImage(posts: self.postsList, count: anno.memberAnnotations.count)
            annotationView?.centerOffset = CGPoint(x: 6.25, y: -26)
            annotationView!.isSelected = true
            return annotationView
            
        } else if let anno = annotation as? SinglePostAnnotation {
            // single post is for a post when post page is open
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "singlePost") as? SinglePostAnnotationView
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "singlePost") as? SinglePostAnnotationView
            } else { annotationView!.annotation = annotation }

            guard let post = postsList.first(where: {$0.id == anno.id}) else { return annotationView }
            annotationView!.updateImage(post: post)
            annotationView?.centerOffset = CGPoint(x: 0, y: -10)
            annotationView?.alpha = 0.0
            
            return annotationView
        } else {
            // generic spot icon on fall through
            let annotationView = MKAnnotationView()
            annotationView.annotation = annotation
            annotationView.image = UIImage(named: "RainbowSpotIcon")
            annotationView.clusteringIdentifier = nil
            return annotationView
        }
        return nil
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, data, err, cache, download, url) in

            let postImage = image ?? UIImage()
            completion(postImage)
        }
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        let userView = mapView.view(for: mapView.userLocation)
        userView?.isUserInteractionEnabled = false
        userView?.isEnabled = false
        userView?.canShowCallout = false
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
                
        /// only remove clustering for spot banner targets so return otherwise
        if nearbyViewController == nil && profileViewController == nil { return }
        if profileViewController != nil && profileViewController.selectedIndex == 1 { return }
        
        let span = mapView.region.span
        if span.longitudeDelta < 0.002 {
            
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
        
        if !searchPageOpen() { return }

        /// should update region is on a delay so that it doesn't get called constantly on the map pan
        if shouldUpdateRegion {
        
            shouldUpdateRegion = false
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
                
                guard let self = self else { return }
                
                self.shouldUpdateRegion = true
                if !self.searchPageOpen() { return }
                if !mapView.region.IsValid { return }
                
                if self.regionQuery != nil {
                    self.regionQuery?.region = mapView.region
                } else { self.regionQuery = self.geoFirestore.query(inRegion: mapView.region) }
                
                self.filterSpots(refresh: false)
            }
        }
        
        if shouldUpdateCity {
            
            shouldUpdateCity = false
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                
                guard let self = self else { return }
                if !self.searchPageOpen() { return }
                self.nearbyViewController.checkForCityChange()
            }
        }
    }
    
    
    func filterSpots(refresh: Bool) {
        
        if !postsList.isEmpty || self.selectedSpotID != "" || self.selectedProfileID != "" { return }
        
        for anno in nearbyAnnotations {
            
            let info = anno.value.spotInfo!
            if anno.value.rank == 0 {
                continue
            }
            
            if anno.value.isHidden || refresh {
                /// check if we're adding it back on search page reappear or filter values changed
                if !spotFilteredByLocation(spotCoordinates: anno.value.coordinate) && !spotFilteredByTag(tags: info.tags) && !spotFilteredByUser(visitorList: info.visitorList) {
                    DispatchQueue.main.async {
                        anno.value.isHidden = false
                        self.mapView.addAnnotation(anno.value)
                    }
                }
                
            } else {
                /// is spot contained in maps bounding rect
                if spotFilteredByLocation(spotCoordinates: anno.value.coordinate) {
                    anno.value.isHidden = true
                    DispatchQueue.main.async {
                        self.mapView.removeAnnotation(anno.value)
                    }
                    continue
                }
                /// tag selected in nearby drawer
                if spotFilteredByTag(tags: info.tags) {
                    anno.value.isHidden = true
                    DispatchQueue.main.async {
                        self.mapView.removeAnnotation(anno.value)
                    }
                    continue
                }
                /// user selected in nearby drawer
                if spotFilteredByUser(visitorList: info.visitorList) {
                    anno.value.isHidden = true
                    DispatchQueue.main.async {
                        self.mapView.removeAnnotation(anno.value)
                    }
                    continue
                }
            }
        }
    }
    
    func spotFilteredByTag(tags: [String]) -> Bool {
        for filter in filterTags {
            if !tags.contains(filter) { return true }
        }
        return false
    }
    
    func spotFilteredByLocation(spotCoordinates: CLLocationCoordinate2D) -> Bool {
        let coordinates = mapView.region.boundingBoxCoordinates
        if !(spotCoordinates.latitude < coordinates[0].latitude && spotCoordinates.latitude > coordinates[2].latitude && spotCoordinates.longitude > coordinates[0].longitude && spotCoordinates.longitude < coordinates[2].longitude) {
            return true
        }
        return false
    }
    
    func spotFilteredByUser(visitorList: [String]) -> Bool {
        if filterUser != nil && !visitorList.contains(filterUser.id ?? "") { return true }
        return false
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
    
    
    func openPostPage(id: String) {
        if let post = self.postsList.first(where: {$0.id == id})  {
            spotViewController.openPostPage(postID: post.id!, imageIndex: 0)
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        ///full spot annotations, entry points from search page and profile
        
        // spot target select from map
        if let clusterView = view as? SpotClusterView {
            Mixpanel.mainInstance().track(event: "MapSelectSpot")
            
            if selectedProfileID != "" {
                selectProfileFromMap(spotID: clusterView.topSpotID)
            } else {
                selectNearbyFromMap(spotID: clusterView.topSpotID)
            }
        } else if let annoView = view as? SpotAnnotationView {
            Mixpanel.mainInstance().track(event: "MapSelectSpot")
            
            if selectedProfileID != "" {
                selectProfileFromMap(spotID: annoView.spotID)
            } else {
                selectNearbyFromMap(spotID: annoView.spotID)
            }
            ///post annotations
            
        // post select from spot page or profile on map
        } else if let clusterView = view as? PostClusterView {
            Mixpanel.mainInstance().track(event: "MapSelectPost")
            
            if spotViewController != nil {
                openPostPage(id: clusterView.topPostID)
            } else {
                ///open from profile
                let infoPass = ["id": clusterView.topPostID] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostTap"), object: nil, userInfo: infoPass)
            }
            
        } else if let annoView = view as? StandardPostAnnotationView {
            Mixpanel.mainInstance().track(event: "MapSelectPost")
            
            if spotViewController != nil {
                openPostPage(id: annoView.spotID)
            } else {
                ///open from profile
                let infoPass = ["id": annoView.spotID] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostTap"), object: nil, userInfo: infoPass)
            }
            
        } else if view is SinglePostAnnotationView {
            NotificationCenter.default.post(name: Notification.Name("FeedPostTap"), object: nil, userInfo: nil)
        }
    }
    
    func selectProfileFromMap(spotID: String) {

        /// passed camera is where camera was before opening user profile
        if profileViewController == nil { return }
        profileViewController.passedCamera = MKMapCamera(lookingAtCenter: mapView.centerCoordinate, fromDistance: mapView.camera.centerCoordinateDistance, pitch: mapView.camera.pitch, heading: mapView.camera.heading)

        profileViewController = nil
        selectedProfileID = "" 
        selectedSpotID = spotID
        let infoPass = ["id": spotID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("MapSpotOpen"), object: nil, userInfo: infoPass)
    }
    
    func selectNearbyFromMap(spotID: String) {
        
        // clear out all markers, show posts on map
        selectedSpotID = spotID
        if let selected = self.nearbyAnnotations.first(where: {$0.key == self.selectedSpotID}) {
            let selectedCoordinate = selected.value.coordinate
            runSelected(selectedCoordinate: selectedCoordinate, spot: selected.value.spotInfo)
        }
        
    }
    
    func selectFromSearch(spot: MapSpot) {
        /// open spot from nearby search
        
        Mixpanel.mainInstance().track(event: "SelectSpotFromSearch")
        
        selectedSpotID = spot.id ?? "" 
        let selectedCoordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        
        if !self.nearbyAnnotations.contains(where: {$0.key == selectedSpotID}) {
            let anno = CustomSpotAnnotation()
            anno.coordinate = selectedCoordinate
            anno.spotInfo = spot
            nearbyAnnotations[selectedSpotID] = anno
        }
        
        runSelected(selectedCoordinate: selectedCoordinate, spot: spot)
    }
    
    // open spot from post page
    @objc func selectFromPost(_ notification: NSNotification) {
        
        Mixpanel.mainInstance().track(event: "SelectSpotFromPost")
        
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        guard let spot = userInfo["spot"] as? MapSpot else { return }
        self.selectedSpotID = spot.id ?? ""
        let selectedCoordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        
        if !self.nearbyAnnotations.contains(where: {$0.key == selectedSpotID}) {
            let anno = CustomSpotAnnotation()
            anno.coordinate = selectedCoordinate
            anno.spotInfo = spot
            nearbyAnnotations[selectedSpotID] = anno
        }
        
        self.postsList.removeAll()
        
        let annotations = self.mapView.annotations
        mapView.removeAnnotations(annotations)
        let selectedSpotAnno = MKPointAnnotation()
        selectedSpotAnno.coordinate = selectedCoordinate
        mapView.addAnnotation(selectedSpotAnno)
        
        /// larger offset for 3D view
        let offset = mapView.mapType.rawValue == 4 ? 0.003 : 0.0015
        
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: selectedCoordinate.latitude - offset, longitude: selectedCoordinate.longitude)
        mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 300, longitudinalMeters: 300), animated: true)
    }
    
    // open spot from profileSpots
    @objc func selectFromProfile(_ notification: NSNotification) {
        
        Mixpanel.mainInstance().track(event: "SelectSpotFromProfile")

        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        guard let spot = userInfo["spot"] as? MapSpot else { return }
        
        selectedSpotID = spot.id ?? ""
        selectedProfileID = ""
        profileViewController = nil
        postsList.removeAll()
        
        let selectedCoordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        let annotations = self.mapView.annotations
        mapView.removeAnnotations(annotations)
        
        let selectedSpotAnno = MKPointAnnotation()
        selectedSpotAnno.coordinate = selectedCoordinate
        mapView.addAnnotation(selectedSpotAnno)
            
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: selectedCoordinate.latitude - 0.001, longitude: selectedCoordinate.longitude)
        mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 300, longitudinalMeters: 300), animated: true)
    }
    
    @objc func selectFromNotis(_ notification: NSNotification) {
        
        Mixpanel.mainInstance().track(event: "SelectSpotFromNotis")
        
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        guard let spot = userInfo["spot"] as? MapSpot else { return }

        selectedSpotID = spot.id ?? ""
                
        let selectedCoordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
        
        let selectedSpotAnno = MKPointAnnotation()
        selectedSpotAnno.coordinate = selectedCoordinate
        mapView.addAnnotation(selectedSpotAnno)
            
        let adjustedCoordinate = CLLocationCoordinate2D(latitude: selectedCoordinate.latitude - 0.001, longitude: selectedCoordinate.longitude)
        mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 300, longitudinalMeters: 300), animated: true)
    }
    
    func runSelected(selectedCoordinate: CLLocationCoordinate2D, spot: MapSpot) {
        // remove annotations and open spot page
        
        self.postsList.removeAll()
        
        let annotations = self.mapView.annotations
        mapView.removeAnnotations(annotations)
        
        let selectedSpotAnno = MKPointAnnotation()
        selectedSpotAnno.coordinate = selectedCoordinate
        mapView.addAnnotation(selectedSpotAnno)
        
        if nearbyViewController != nil || profileViewController != nil {
            nearbyViewController.passedCamera = MKMapCamera(lookingAtCenter: mapView.centerCoordinate, fromDistance: mapView.camera.centerCoordinateDistance, pitch: mapView.camera.pitch, heading: mapView.camera.heading)
        }

        let adjustedCoordinate = CLLocationCoordinate2D(latitude: selectedCoordinate.latitude - 0.001, longitude: selectedCoordinate.longitude)
        mapView.setRegion(MKCoordinateRegion(center: adjustedCoordinate, latitudinalMeters: 300, longitudinalMeters: 300), animated: true)
        
        openSpotPage(selectedSpot: spot)
    }
    
    
    func offsetCenterCoordinate(selectedCoordinate: CLLocationCoordinate2D, offset: CGFloat, animated: Bool, region: MKCoordinateRegion) {
        // offset center coordinate (offset pts)
        /// setting region for animation into spot page, otherwise just offsetting the center coordinate
        
        let mirrorMap = MKMapView(frame: UIScreen.main.bounds)
        mirrorMap.mapType = .standard
        
        if animated {
           mirrorMap.region = region
        } else {
            mirrorMap.camera = mapView.camera
        }
        
        mirrorMap.setCenter(selectedCoordinate, animated: false)
        
        var point = mirrorMap.convert(mirrorMap.centerCoordinate, toPointTo: mirrorMap)
        
        point.y -= offset

        let coordinate = mirrorMap.convert(point, toCoordinateFrom: mirrorMap)
        let offsetLocation = coordinate.location
        
        let distance = mirrorMap.centerCoordinate.location.distance(from: offsetLocation) / 1000.0
        
        let camera = mirrorMap.camera
        
        let adjustedCenter = mirrorMap.centerCoordinate.adjust(by: distance, at: camera.heading - 180.0)
        mirrorMap.setCenter(adjustedCenter, animated: false)
        
        // adjusted center is off on return from spot page
        
        if animated {
            mapView.setRegion(mirrorMap.region, animated: animated)
        } else {
            mapView.setCenter(adjustedCenter, animated: false)
            
            // patch fix for map setting center coordinate not at true center
            var point = mapView.convert(mapView.centerCoordinate, toPointTo: mapView)
            let trueCenter = UIScreen.main.bounds.height/2
            
            point.y -= trueCenter - point.y
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            if abs(coordinate.latitude) < 180 && abs(coordinate.latitude) > 0 && abs(coordinate.longitude) < 180 && abs(coordinate.longitude) > 0 {
            mapView.setCenter(coordinate, animated: false) }
        }
    }
    
    func openSpotPage(selectedSpot: MapSpot) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(withIdentifier: "SpotPage") as? SpotViewController {
            
            if nearbyViewController == nil { return }
            
            vc.spotID = self.selectedSpotID
            vc.spotObject = selectedSpot
            vc.mapVC = self
            vc.view.frame = UIScreen.main.bounds
            
            hideNearbyButtons()
            searchBarButton.isHidden = true
            nearbyViewController.addTopRadius()
            nearbyViewController.addChild(vc)
            nearbyViewController.view.addSubview(vc.view)
            vc.didMove(toParent: nearbyViewController)
            
            prePanY = halfScreenY
            customTabBar.view.frame = CGRect(x: 0, y: halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - halfScreenY)
            
            self.spotViewController = vc
            self.profileViewController = nil
            self.nearbyViewController = nil
        }
    }
    
    
    func checkPostLocations(spotLocation: CLLocation) {
        /// zoom out map on spot page select to show all annotations in view
        /// need to set a max distance here
        
        var farthestDistance: CLLocationDistance = 0
        
        for post in postsList {
            
            let postLocation = CLLocation(latitude: post.postLat, longitude: post.postLong)
            let postDistance = postLocation.distance(from: spotLocation)
            if postDistance > farthestDistance { farthestDistance = postDistance }
            
            if post.id == postsList.last?.id ?? "" {
                /// max distance = 160 in all directions
                if farthestDistance > 160 {
                    
                    var region = MKCoordinateRegion(center: spotLocation.coordinate, latitudinalMeters: farthestDistance * 2.5, longitudinalMeters: farthestDistance * 2.5)
                    
                    /// adjust if invalid region
                    if region.span.latitudeDelta > 100 { region.span.latitudeDelta = 100 }
                    if region.span.longitudeDelta > 100 { region.span.longitudeDelta = 100 }

                    let offset: CGFloat = UserDataModel.shared.largeScreen ? 240 : 270
                    self.offsetCenterCoordinate(selectedCoordinate: spotLocation.coordinate, offset: offset, animated: true, region: region)
                }
            }
        }
    }
}

extension MKMapView {
    
    func topCenterCoordinate() -> CLLocationCoordinate2D {
        return self.convert(CGPoint(x: self.frame.size.width / 2.0, y: 0), toCoordinateFrom: self)
    }
    
    func currentRadius() -> Double {
        let centerLocation = CLLocation(latitude: self.centerCoordinate.latitude, longitude: self.centerCoordinate.longitude)
        let topCenterCoordinate = self.topCenterCoordinate()
        let topCenterLocation = CLLocation(latitude: topCenterCoordinate.latitude, longitude: topCenterCoordinate.longitude)
        return centerLocation.distance(from: topCenterLocation)/1000
    }
    ///source:  https://stackoverflow.com/questions/29093843/how-to-get-radius-from-visible-area-of-mkmapview
    
    func animatedZoom(zoomRegion:MKCoordinateRegion, duration:TimeInterval) {
        MKMapView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 10, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.setRegion(zoomRegion, animated: true)
        }, completion: nil)
    }
    ///source:  https://stackoverflow.com/questions/6352067/speed-of-setregion-for-mkmapview
}
extension MKCoordinateRegion {
    
    var boundingBoxCoordinates: [CLLocationCoordinate2D] {
        let halfLatDelta = self.span.latitudeDelta / 2
        //make longitude delta same as latitude to match circle query radius
        let halfLngDelta = self.span.longitudeDelta
        
        let topLeft = CLLocationCoordinate2D(
            latitude: self.center.latitude + halfLatDelta,
            longitude: self.center.longitude - halfLngDelta
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: self.center.latitude - halfLatDelta,
            longitude: self.center.longitude + halfLngDelta
        )
        let bottomLeft = CLLocationCoordinate2D(
            latitude: self.center.latitude - halfLatDelta,
            longitude: self.center.longitude - halfLngDelta
        )
        let topRight = CLLocationCoordinate2D(
            latitude: self.center.latitude + halfLatDelta,
            longitude: self.center.longitude + halfLngDelta
        )
        
        return [topLeft, topRight, bottomRight, bottomLeft]
    }
}


class CustomSpotAnnotation: MKPointAnnotation {
    
    var spotInfo: MapSpot!
    var rank: CGFloat = 0
    var isHidden = true
    
    override init() {
        super.init()
    }
}

class SpotClusterAnnotation: MKClusterAnnotation {
    //  var topSpot: ((MapSpot, Int))!
    override init(memberAnnotations: [MKAnnotation]) {
        super.init(memberAnnotations: memberAnnotations)
    }
}

class SpotAnnotationView: MKAnnotationView {
    var spotID = ""
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
        centerOffset = CGPoint(x: 1, y: -18.5)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SpotClusterView: MKAnnotationView {
    var topSpotID = ""
    
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".SpotClusterView"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        self.canShowCallout = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // update spot banner with the top spot in the cluster
    func updateImage(annotations: [CustomSpotAnnotation]) {
        
        let nibView = loadNib()
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            var topSpot: CustomSpotAnnotation!
            
            for member in clusterAnnotation.memberAnnotations {
                if let spot = annotations.first(where: {$0.spotInfo.spotLat == member.coordinate.latitude && $0.spotInfo.spotLong == member.coordinate.longitude}) {
                    if topSpot == nil {
                        topSpot = spot
                    } else if spot.rank > topSpot.rank {
                        topSpot = spot
                    }
                }
            }
            
            if topSpot != nil {
                nibView.spotNameLabel.text = topSpot.spotInfo.spotName
                let temp = nibView.spotNameLabel
                temp?.sizeToFit()
                nibView.resizeBanner(width: temp?.frame.width ?? 0)
                let nibImage = nibView.asImage()
                self.image = nibImage
                self.topSpotID = topSpot.spotInfo.id ?? ""
            } else {
                self.image = UIImage(named: "RainbowSpotIcon")
            }
        }
    }
    
    func loadNib() -> MapTarget {
        let infoWindow = MapTarget.instanceFromNib() as! MapTarget
        infoWindow.clipsToBounds = true
        infoWindow.spotNameLabel.font = UIFont(name: "SFCamera-Regular", size: 13)
        infoWindow.spotNameLabel.numberOfLines = 1
        infoWindow.spotNameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        
        return infoWindow
    }
}

class SinglePostAnnotationView: MKAnnotationView {
    
    lazy var id: String = ""
    lazy var imageManager = SDWebImageManager()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    func updateImage(post: MapPost) {
        
        let nibView = loadNib()
        id = post.id ?? ""
        guard let url = URL(string: post.imageURLs.first ?? "") else { image = nibView.asImage(); return }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
            guard let self = self else { return }
            
            nibView.postImage.image = image
            self.image = nibView.asImage()
        }
    }
    
    func loadNib() -> SinglePostWindow {
        let infoWindow = SinglePostWindow.instanceFromNib() as! SinglePostWindow
        infoWindow.clipsToBounds = true
        infoWindow.postImage.contentMode = .scaleAspectFill
        infoWindow.postImage.clipsToBounds = true
        infoWindow.postImage.layer.cornerRadius = 8
        return infoWindow
    }
    
    override func prepareForReuse() {
        imageManager.cancelAll()
        image = nil
    }
}

class SinglePostAnnotation: MKPointAnnotation {
    
    var id: String!
    
    override init() {
        super.init()
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


class ActiveFilterView: UIView {
    
    var closeButton: UIButton!
    var filterName: UILabel!
    var filterimage: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    deinit {
        filterimage.sd_cancelCurrentImageLoad()
    }
    
    func setUpFilter(name: String, image: UIImage, imageURL: String) {
        
        backgroundColor =  UIColor(red: 0.58, green: 0.58, blue: 0.58, alpha: 0.65)
        layer.borderColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.00).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 7.5

        filterimage = UIImageView(frame: CGRect(x: 8, y: 5, width: 20, height: 20))
        filterimage.backgroundColor = nil
        
        /// get from image url for user profile picture or  tag from db
        if image == UIImage() {
            /// returns same URL for profile pic, fetches new one for tag from DB
            getImageURL(name: name, imageURL: imageURL) { [weak self] url in
                guard let self = self else { return }
                if url == "" { return }
                
                let transformer = SDImageResizingTransformer(size: CGSize(width: 70, height: 70), scaleMode: .aspectFill)
                self.filterimage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, _, _, _) in
                    guard let self = self else { return }
                    if image != nil { self.filterimage.image = image!}
                    self.filterimage.layer.cornerRadius = 10
                    self.filterimage.layer.masksToBounds = true
                }
            }
        } else { filterimage.image = image }
        
        filterimage.contentMode = .scaleAspectFit
        self.addSubview(filterimage)
        
        filterName = UILabel(frame: CGRect(x: filterimage.frame.maxX + 5, y: 8, width: 40, height: 15))
        filterName.text = name
        filterName.font = UIFont(name: "SFCamera-Semibold", size: 12)
        filterName.textColor = .white
        if image == UIImage() { filterName.sizeToFit() }
        self.addSubview(filterName)
        
        closeButton = UIButton(frame: CGRect(x: bounds.width - 29, y: 1, width: 28, height: 28))
        closeButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        closeButton.setImage(UIImage(named: "CheckInX"), for: .normal)
        self.addSubview(closeButton)
    }
    
    func getImageURL(name: String, imageURL: String, completion: @escaping (_ URL: String) -> Void) {
        if imageURL != "" { completion(imageURL); return }
        let tag = Tag(name: name)
        tag.getImageURL { url in
            completion(url)
        }
    }

    required init(coder: NSCoder) {
        fatalError()
    }
    
}

extension MapViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var maxRows = 2
        if tagTable.frame.height > 300 {
            maxRows = 5
        } else if tagTable.frame.height > 250 {
            maxRows = 4
        } else if tagTable.frame.height > 200 {
            maxRows = 3
        }
        return tagUsers.count > maxRows ? maxRows : tagUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsListCell", for: indexPath) as! FriendsListCell
        cell.setUp(friend: tagUsers[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let username = tagUsers[indexPath.row].username
        let infoPass = ["username": username, "tag": tagTable.tag] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("TagSelect"), object: nil, userInfo: infoPass)
        removeTable()
    }
    
    func addTable(text: String, parent: TagTableParent) {
        if tagTable.superview == nil {
            /// add tag table to window
            resizeTable(parent: parent)
            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            window?.addSubview(tagTable)
            
            /// add tag to pass to correct vc on tag select
            switch parent {
            case .comments : tagTable.tag = 0
            case .post : tagTable.tag = 1
            case .upload : tagTable.tag = 2
            }
        }
        runQuery(searchText: text)
    }
    
    func resizeTable(parent: TagTableParent) {
        switch parent {
        case .comments:
            let height: CGFloat = UserDataModel.shared.largeScreen ? 330 : 275
            tagTable.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)
        default:
            let height: CGFloat = UserDataModel.shared.largeScreen ? 175 : 135 /// originally using 220 for large screen but was cutting off for post-to spot
            tagTable.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)
        }
    }
    
    func removeTable() {
        /// remove tag table from super
        tagTable.removeFromSuperview()
        tagUsers.removeAll()
    }
    
    func runQuery(searchText: String) {
        
        tagUsers.removeAll()
        
        var adjustedFriends = UserDataModel.shared.friendsList
        adjustedFriends.removeAll(where: {$0.id == "T4KMLe3XlQaPBJvtZVArqXQvaNT2"}) /// remove bot
        let usernameList = adjustedFriends.map({$0.username})
        let nameList = adjustedFriends.map({$0.name})
        
        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })
        
        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })
        
        for username in filteredUsernames {
            if let friend = adjustedFriends.first(where: {$0.username == username}) { self.tagUsers.append(friend) }
        }
        
        for name in filteredNames {
            if let friend = adjustedFriends.first(where: {$0.name == name}) {
                ///chance that 2 people with same name won't show up in search rn
                if !self.tagUsers.contains(where: {$0.id == friend.id}) { self.tagUsers.append(friend) }
            }
        }
        
        DispatchQueue.main.async { self.tagTable.reloadData() }
    }
}

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
///https://gist.github.com/AJMiller/0def0fd492a09ca22fee095c4526cf68
extension UIView {
    func roundedView() {
        let maskPath1 = UIBezierPath(roundedRect: bounds,
            byRoundingCorners: [.topLeft , .topRight],
            cornerRadii: CGSize(width: 8, height: 8))
        let maskLayer1 = CAShapeLayer()
        maskLayer1.frame = bounds
        maskLayer1.path = maskPath1.cgPath
        layer.mask = maskLayer1
    }
}

// filter extension
extension MapViewController {
    
    func addMapButtons() {
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let safeBottom = window?.safeAreaInsets.bottom ?? 0
        let tabBarHeight = customTabBar.tabBar.frame.height + safeBottom
        let closedY = tabBarHeight + 84

        mapMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))

        activeFilterView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - closedY - 120, width: 120, height: 150))
        activeFilterView.backgroundColor = nil
        activeFilterView.alpha = 0.0
        mapView.addSubview(activeFilterView)

        userLocationButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 61, y: UIScreen.main.bounds.height - closedY - 65, width: 50, height: 50))
        userLocationButton.setImage(UIImage(named: "UserLocationButton"), for: .normal)
        userLocationButton.addTarget(self, action: #selector(userLocationTap(_:)), for: .touchUpInside)
        userLocationButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        userLocationButton.isHidden = true
        mapView.addSubview(userLocationButton)
        
        directionsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 64, y: UIScreen.main.bounds.height - closedY - 65, width: 56, height: 56))
        directionsButton.setImage(UIImage(named: "DirectionsButton"), for: .normal)
        directionsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        directionsButton.isHidden = true
        mapView.addSubview(directionsButton)
        
        toggleMapButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 61, y: userLocationButton.frame.minY - 58, width: 50, height: 50))
        toggleMapButton.setImage(UIImage(named: "ToggleMap3D"), for: .normal)
        toggleMapButton.addTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
        toggleMapButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        toggleMapButton.isHidden = true
        mapView.addSubview(toggleMapButton)
        
        let searchBarY: CGFloat = UserDataModel.shared.largeScreen ? 43 : 33
        searchBarButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 205/2, y: searchBarY, width: 205, height: 48))
        searchBarButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        searchBarButton.setImage(UIImage(named: "SearchBarButton"), for: .normal)
        searchBarButton.addTarget(self, action: #selector(searchBarTap(_:)), for: .touchUpInside)
        searchBarButton.isHidden = true
        mapView.addSubview(searchBarButton)
    }
    
    @objc func searchBarTap(_ sender: UIButton) {
        if nearbyViewController == nil { return }
        Mixpanel.mainInstance().track(event: "NearbySearchBarTap")
        nearbyViewController.searchBar.becomeFirstResponder()
    }
    
    @objc func toggle2D(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "MapToggle2D")
        shouldUpdateRegion = false
        
        mapView.mapType = .mutedStandard
        mapView.camera.pitch = 0
        
        toggleMapButton.setImage(UIImage(named: "ToggleMap3D"), for: .normal)
        toggleMapButton.removeTarget(self, action: #selector(toggle2D(_:)), for: .touchUpInside)
        toggleMapButton.addTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
        
        /// patch fix for geofire map crash when switching map styles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.shouldUpdateRegion = true
        }
    }
    
    @objc func toggle3D(_ sender: UIButton) {
        
        Mixpanel.mainInstance().track(event: "MapToggle3D")
        shouldUpdateRegion = false
        
        mapView.mapType = .hybridFlyover
        mapView.camera.pitch = 60
        
        toggleMapButton.setImage(UIImage(named: "ToggleMap2D"), for: .normal)
        toggleMapButton.removeTarget(self, action: #selector(toggle3D(_:)), for: .touchUpInside)
        toggleMapButton.addTarget(self, action: #selector(toggle2D(_:)), for: .touchUpInside)
        
        /// patch fix for geofire map crash when switching map styles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.shouldUpdateRegion = true
        }
    }
    
    @objc func userLocationTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapUserLocation")
        animateToUserLocation(animated: true)
    }
    
        
    func filterFromNearby() {
        DispatchQueue.main.async { self.addSelectedFilters() }
        DispatchQueue.global(qos: .userInitiated).async { self.filterSpots(refresh: false) }
    }
    
    func addSelectedFilters() {
        
        Mixpanel.mainInstance().track(event: "MapFilterSave", properties: ["tags": filterTags])
        
        for sub in activeFilterView.subviews {
            for s in sub.subviews {
                s.removeFromSuperview()
            }
            sub.removeFromSuperview()
        }
        
        mapView.bringSubviewToFront(activeFilterView)
        
        var minY: CGFloat = 80
        
        if filterUser != nil {
            
            let temp = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 15))
            temp.text = filterUser.username
            temp.font = UIFont(name: "SFCamera-Semibold", size: 12)
            temp.sizeToFit()
            
            let filterView = ActiveFilterView(frame: CGRect(x: 13, y: minY, width: temp.bounds.width + 65, height: 30))
            filterView.setUpFilter(name: filterUser.username, image: UIImage(), imageURL: filterUser.imageURL)
            filterView.closeButton.tag = 10
            filterView.closeButton.addTarget(self, action: #selector(deselectFilter(_:)), for: .touchUpInside)
            activeFilterView.addSubview(filterView)

            minY -= 40
        }
        
        var count = 0
        
        for tag in filterTags {
            
            let filterView = ActiveFilterView(frame: CGRect(x: 13, y: minY, width: 105, height: 30))
            let tag = Tag(name: tag)
            filterView.setUpFilter(name: tag.name, image: tag.image, imageURL: "")
            filterView.closeButton.tag = count
            filterView.closeButton.addTarget(self, action: #selector(deselectFilter(_:)), for: .touchUpInside)
            self.activeFilterView.addSubview(filterView)
            
            count += 1
            minY -= 40
        }
    }
    
    @objc func deselectFilter(_ sender: UIButton) {
        /// need to reconfig
        
        Mixpanel.mainInstance().track(event: "DeselectFilterFromMap")
        if sender.tag == 10 {
            nearbyViewController.deselectUserFromMap()
            filterUser = nil
            
        } else {
            let selectedTag = self.filterTags[sender.tag]
            nearbyViewController.deselectTagFromMap(tag: selectedTag)
            self.filterTags.removeAll(where: {$0 == selectedTag})
        }
        
        DispatchQueue.main.async { self.addSelectedFilters() }
        DispatchQueue.global(qos: .userInitiated).async { self.filterSpots(refresh: false) }
    }
    
    func unhideNearbyButtons(nearby: Bool) {
        toggleMapButton.isHidden = false
        userLocationButton.isHidden = false
        if nearby { UIView.animate(withDuration: 0.3) { self.activeFilterView.alpha = 1.0 } }
    }
    
    func hideNearbyButtons() {
        toggleMapButton.isHidden = true
        userLocationButton.isHidden = true
        UIView.animate(withDuration: 0.3) { self.activeFilterView.alpha = 0.0 }
    }
    
    func unhideSpotButtons() {
        toggleMapButton.isHidden = false
        directionsButton.isHidden = false
        directionsButton.addTarget(self, action: #selector(directionsTap(_:)), for: .touchUpInside)
    }
    
    func hideSpotButtons() {
        toggleMapButton.isHidden = true
        directionsButton.isHidden = true
        directionsButton.removeTarget(self, action: #selector(directionsTap(_:)), for: .touchUpInside)
    }

    @objc func directionsTap(_ sender: UIButton) {
        if spotViewController == nil { return }
        guard let spot = spotViewController.spotObject else { return }
        
        Mixpanel.mainInstance().track(event: "SpotGetDirections")
        UIApplication.shared.open(URL(string: "http://maps.apple.com/?daddr=\(spot.spotLat),\(spot.spotLong)")!)
    }
}

//tag extension
extension MapViewController {
    
    func addTagView() {
        tagTable = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 350))
        tagTable.backgroundColor = UIColor(named: "SpotBlack")
        tagTable.separatorStyle = .none
        tagTable.dataSource = self
        tagTable.delegate = self
        tagTable.isUserInteractionEnabled = true
        tagTable.showsVerticalScrollIndicator = false
        let inset: CGFloat = (UIScreen.main.nativeBounds.height > 2300 || UIScreen.main.nativeBounds.height == 1792) ? 15 : 0
        tagTable.contentInset = UIEdgeInsets(top: inset, left: 0, bottom: 0, right: 0)
        tagTable.register(FriendsListCell.self, forCellReuseIdentifier: "FriendsListCell")
    }
    
}


// tutorial extension
extension MapViewController {
    
    func checkForTutorial(index: Int) {
        
        if tutorialView == nil || tutorialView.superview == nil {
            if UserDataModel.shared.userInfo.id == "" || UserDataModel.shared.userInfo.tutorialList.isEmpty { return }
            if index == 0 && customTabBar.selectedIndex != 0 { return }
            
            if !UserDataModel.shared.userInfo.tutorialList[index] {
                addTutorialView(index: index)
                updateTutorialList(index: index)
            }
        }
    }
        
    func addTutorialView(index: Int) {
        
        mapMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        mapMask.backgroundColor = UIColor.black.withAlphaComponent(0.65)

        DispatchQueue.main.async {
            let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
            keyWindow?.addSubview(self.mapMask)
        }
        
        switch index {
        
        case 0:

            // add feed pull down tutorial
            tutorialView = UIView(frame: CGRect(x: 0, y: tabBarOpenY - 10, width: UIScreen.main.bounds.width, height: 300))
            tutorialView.backgroundColor = nil
            DispatchQueue.main.async { self.mapMask.addSubview(self.tutorialView) }
            
            tutorialImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 30, y: 0, width: 120, height: 120))
            tutorialImage.image = UIImage(named: "Swipe0")
            tutorialImage.contentMode = .scaleAspectFit
            let images: [UIImage] = [UIImage(named: "Swipe0")!, UIImage(named: "Swipe1")!, UIImage(named: "Swipe2")!, UIImage(named: "Swipe3")!, UIImage(named: "Swipe4")!, UIImage(named: "Swipe5")!, UIImage(named: "Swipe6")!, UIImage(named: "Swipe7")!, ]
            tutorialImage.animationImages = images
            tutorialImage.animationDuration = 0.7
            
            DispatchQueue.main.async {
                self.tutorialImage.startAnimating()
                self.tutorialView.addSubview(self.tutorialImage)
            }
            
            tutorialText = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 115, y: tutorialImage.frame.maxY + 5, width: 230, height: 100))
            tutorialText.text = "Pull down the drawer to see the post on the map"
            tutorialText.textColor = .white
            tutorialText.font = UIFont(name: "SFCamera-Semibold", size: 24)
            tutorialText.textAlignment = .center
            tutorialText.lineBreakMode = .byWordWrapping
            tutorialText.numberOfLines = 0
            tutorialText.clipsToBounds = false
            DispatchQueue.main.async { self.tutorialView.addSubview(self.tutorialText) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.firstTutorialTap(_:))))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self = self else { return }
                
                // remove if tap to visit wasn't already added
                if self.tutorialView.superview != nil && self.tutorialImage.frame.minY == 0 {
                    self.addTapToVisit()
                }
            }
            
        case 1:
            
            // add add to spot tutorial
            let smallScreenAdjust: CGFloat = UserDataModel.shared.largeScreen ? 0 : 25
            let minY = UIScreen.main.bounds.height - 140 + smallScreenAdjust
            
            tutorialView = UIView(frame: CGRect(x: 0, y: minY, width: UIScreen.main.bounds.width, height: 145))
            tutorialView.backgroundColor = nil
            DispatchQueue.main.async { self.mapMask.addSubview(self.tutorialView) }
            
            tutorialImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 140, y: 0, width: 120, height: 120))
            tutorialImage.image = UIImage(named: "SpotTap0")
            let images: [UIImage] = [UIImage(named: "SpotTap0")!, UIImage(named: "SpotTap1")!, UIImage(named: "SpotTap2")!, UIImage(named: "SpotTap3")!, UIImage(named: "SpotTap4")!, UIImage(named: "SpotTap5")!, UIImage(named: "SpotTap6")!, UIImage(named: "SpotTap7")!, UIImage(named: "SpotTap8")!]
            tutorialImage.animationImages = images
            tutorialImage.animationDuration = 0.7
            DispatchQueue.main.async {
                self.tutorialImage.startAnimating()
                self.tutorialView.addSubview(self.tutorialImage)
            }
            
            tutorialText = UILabel(frame: CGRect(x: 30, y: 20, width: 220, height: 60))
            tutorialText.text = "Use this button to add to the spot"
            tutorialText.textColor = .white
            tutorialText.font = UIFont(name: "SFCamera-Semibold", size: 24)
            tutorialText.textAlignment = .left
            tutorialText.numberOfLines = 0
            tutorialText.lineBreakMode = .byWordWrapping
            tutorialText.sizeToFit()
            DispatchQueue.main.async { self.tutorialView.addSubview(self.tutorialText) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tutorialMaskTap(_:))))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
                guard let self = self else { return }
                
                if self.tutorialView.superview != nil && self.tutorialView.frame.minY == minY {
                    self.removeTutorialView()
                }
            }

        case 2:
            
            // add tap to place tutorial
            tutorialView = UIView(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 100))
            tutorialView.backgroundColor = nil
            DispatchQueue.main.async { self.mapMask.addSubview(self.tutorialView) }
            
            tutorialImage = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 40, y: tutorialView.bounds.height/2 - 100, width: 120, height: 120))
            tutorialImage.image = UIImage(named: "tap0")
            tutorialImage.animationImages = [UIImage(named: "Tap0")!, UIImage(named: "Tap1")!, UIImage(named: "Tap2")!, UIImage(named: "Tap3")!, UIImage(named: "Tap4")!, UIImage(named: "Tap5")!, UIImage(named: "Tap6")!, UIImage(named: "Tap7")!, UIImage(named: "Tap8")!]
            tutorialImage.animationDuration = 0.7
            DispatchQueue.main.async {
                self.tutorialImage.startAnimating()
                self.tutorialView.addSubview(self.tutorialImage)
            }
            
            tutorialText = UILabel(frame: CGRect(x: UIScreen.main.bounds.width/2 - 80, y:  tutorialImage.frame.maxY, width: 160, height: 60))
            tutorialText.text = "Tap to place on the map"
            tutorialText.textColor = .white
            tutorialText.textAlignment = .center
            tutorialText.lineBreakMode = .byWordWrapping
            tutorialText.numberOfLines = 0
            tutorialText.clipsToBounds = false
            tutorialText.font = UIFont(name: "SFCamera-Semibold", size: 24)
            DispatchQueue.main.async { self.tutorialView.addSubview(self.tutorialText) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tutorialMaskTap(_:))))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                if self.tutorialView.superview != nil && self.tutorialView.frame.minY == 100 {
                    self.removeTutorialView()
                }
            }
            
        case 3:

            let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
            let navBarHeight = statusHeight +
                        (self.navigationController?.navigationBar.frame.height ?? 44.0)

            tutorialView = UIView(frame: CGRect(x: 0, y: navBarHeight - 54, width: UIScreen.main.bounds.width, height: 300))
            tutorialView.backgroundColor = nil
            DispatchQueue.main.async { self.mapMask.addSubview(self.tutorialView) }
            
            tutorialImage = UIImageView(frame: CGRect(x: 0, y: 1, width: 120, height: 120))
            tutorialImage.image = UIImage(named: "Tap0")
            tutorialImage.contentMode = .scaleAspectFit
            tutorialImage.animationImages = [UIImage(named: "Tap0")!, UIImage(named: "Tap1")!, UIImage(named: "Tap2")!, UIImage(named: "Tap3")!, UIImage(named: "Tap4")!, UIImage(named: "Tap5")!, UIImage(named: "Tap6")!, UIImage(named: "Tap7")!, UIImage(named: "Tap8")!]
            tutorialImage.animationDuration = 0.7
            
            DispatchQueue.main.async {
                self.tutorialImage.startAnimating()
                self.tutorialView.addSubview(self.tutorialImage)
            }
            
            tutorialText = UILabel(frame: CGRect(x: 20, y: tutorialImage.frame.maxY, width: 150, height: 90))
            tutorialText.text = "Tap to find and invite friends"
            tutorialText.textColor = .white
            tutorialText.font = UIFont(name: "SFCamera-Semibold", size: 24)
            tutorialText.textAlignment = .left
            tutorialText.lineBreakMode = .byWordWrapping
            tutorialText.numberOfLines = 0
            tutorialText.clipsToBounds = false
            DispatchQueue.main.async { self.tutorialView.addSubview(self.tutorialText) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tutorialMaskTap(_:))))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self = self else { return }
                if self.tutorialView.superview != nil && self.tutorialView.frame.minY == navBarHeight - 50 {
                    self.removeTutorialView()
                }
            }

        default:
            return
        }
        
    }
    
     @objc func firstTutorialTap(_ sender: UITapGestureRecognizer) {
         addTapToVisit()
     }
     
    @objc func secondTutorialTap(_ sender: UITapGestureRecognizer) {
        addSwipeToNext()
    }
    
     
    func addTapToVisit() {
        
        tutorialImage.stopAnimating()
        tutorialImage.frame = CGRect(x: 55, y: 40, width: 120, height: 120)
        tutorialImage.image = UIImage(named: "Tap0")
        tutorialImage.contentMode = .scaleAspectFit
        tutorialImage.animationImages = [UIImage(named: "Tap0")!, UIImage(named: "Tap1")!, UIImage(named: "Tap2")!, UIImage(named: "Tap3")!, UIImage(named: "Tap4")!, UIImage(named: "Tap5")!, UIImage(named: "Tap6")!, UIImage(named: "Tap7")!, UIImage(named: "Tap8")!]
        DispatchQueue.main.async { self.tutorialImage.startAnimating() }
        
        tutorialText.frame = CGRect(x: 20, y: tutorialImage.frame.maxY, width: 125, height: 66)
        tutorialText.textAlignment = .left
        tutorialText.text = "Tap to visit the spot"
        
        for gesture in mapMask.gestureRecognizers! { mapMask.removeGestureRecognizer(gesture) }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self else { return }
            self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.secondTutorialTap(_:))))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            
            guard let self = self else { return }
            
            if self.tutorialImage.frame.minY == 5 {
                self.addSwipeToNext()
            }
        }
    }
    
    func addSwipeToNext() {
        // add feed swipe to next tutorial
        
        let minY = (UIScreen.main.bounds.height - tabBarOpenY)/2 - 70
        
        tutorialImage.stopAnimating()
        tutorialImage.frame = CGRect(x: UIScreen.main.bounds.width/2 - 30, y: minY, width: 120, height: 120)
        tutorialImage.image = UIImage(named: "SwipeDown0")
        tutorialImage.contentMode = .scaleAspectFit
        tutorialImage.animationImages = [UIImage(named: "SwipeDown0")!, UIImage(named: "SwipeDown1")!, UIImage(named: "SwipeDown2")!, UIImage(named: "SwipeDown3")!, UIImage(named: "SwipeDown4")!, UIImage(named: "SwipeDown5")!, UIImage(named: "SwipeDown6")!, UIImage(named: "SwipeDown7")!, UIImage(named: "SwipeDown8")!]
        DispatchQueue.main.async { self.tutorialImage.startAnimating() }
        
        tutorialText.frame = CGRect(x: UIScreen.main.bounds.width/2 - 100, y: tutorialImage.frame.maxY - 20, width: 200, height: 60)
        tutorialText.text = "Swipe up to go to the next post"
        tutorialText.textAlignment = .center
        
        for gesture in mapMask.gestureRecognizers! {  mapMask.removeGestureRecognizer(gesture) }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.mapMask.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tutorialMaskTap(_:))))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self else { return }
            if self.tutorialView.superview != nil && self.tutorialImage.frame.minY == minY {
                self.removeTutorialView()
            }
        }
    }
         
     func updateTutorialList(index: Int) {

        var tutorialList = UserDataModel.shared.userInfo.tutorialList
        tutorialList[index] = true

        UserDataModel.shared.userInfo.tutorialList = tutorialList
        db.collection("users").document(uid).updateData(["tutorialList": tutorialList])
     }
     
     @objc func tutorialMaskTap(_ sender: UITapGestureRecognizer) {
        removeTutorialView()
     }
     
    func removeTutorialView() {
        tutorialView.removeFromSuperview()
        mapMask.removeFromSuperview()
    }
}
