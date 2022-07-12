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
        return .lightContent
    }
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
   // var mapView: MapView!
    
    var topMapMask, bottomMapMask: UIView!
    
    let locationManager = CLLocationManager()
    var firstTimeGettingLocation = true
    
    var feedLayer: CAShapeLayer!
    var regionQuery: GFSRegionQuery?
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("spots"))
    
    var userListener: ListenerRegistration!
        
    let locationGroup = DispatchGroup()
    let feedGroup = DispatchGroup()
    
    var halfScreenY: CGFloat!
    var tabBarOpenY: CGFloat! /// tabBarOpenY is full screen Y when the tabBar is visible (profile only now)
    var tabBarClosedY: CGFloat! /// tabBarOpenY is full screen Y when  the tabBar is hidden (profile only now)
        
    var friendsLoaded = false
    var feedLoaded = false
    var userSpotsLoaded = false /// used for sending first spot notification
    var shouldCluster = true /// should cluster is false when nearby (tab index 1) selected and max zoom enabled
        
    lazy var postsList: [MapPost] = []
    lazy var friendsPostsDictionary = [String: MapPost]()
    lazy var friendsPostsGroup: [FriendsPostGroup] = []
    
    lazy var tagUsers: [UserProfile] = [] /// users for rows in tagTable
    var tagTable: UITableView! /// tag table that shows after @ throughout app
    var tagParent: TagTableParent! /// active VC where @ was entered
    
    lazy var imageManager = SDWebImageManager()
    
    /// use to avoid deleted documents entering from cache
    lazy var deletedSpotIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []
    
    var notiListener: ListenerRegistration!

    /// nearby feed fetch
    var selectedSegmentIndex = 0
    var nearbyPosts: [MapPost] = []
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyEscapeCount = 0
    var currentNearbyPosts: [MapPost] = [] /// keep track of posts for the current circleQuery to reload all at once
    var activeRadius = 0.75
    var circleQuery: GFSCircleQuery?

    var endDocument: DocumentSnapshot!
    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled
    var nearbyRefresh: RefreshStatus = .refreshEnabled
    var queryReady = false /// circlequery returned
    var friendsListener, nearbyListener, commentListener: ListenerRegistration!
    
    var feedTableContainer: UIView!
    var feedTableHighlight: UIView!
    var feedTable: UITableView!
    lazy var loadingIndicator = CustomActivityIndicator()
    var statusBarMask: UIView!
    
    var originalOffset: CGFloat = 0
    var feedRowOffset: CGFloat = 0
    var selectedFeedIndex = -1

    /// post annotations
    var postAnnotationManager: PointAnnotationManager!
    var pointAnnotations: [PointAnnotation] = []
    var nearbyAnnotations: [PointAnnotation] = []
    var friendAnnotations: [PointAnnotation] = []
    
    /// sheet view: Must declare outside to listen to UIEvent
    private var sheetView: DrawerView? {
        didSet {
            navigationController?.navigationBar.isHidden = sheetView == nil ? false : true
        }
    }
                
    /// tag table added over top of view to window then result passed to active VC
    enum TagTableParent {
        case comments
        case upload
        case post
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return UIRectEdge.bottom
    }
      
    override func viewDidLoad() {
        
        ///add tab bar controller as child -> won't even need to override methods, the tab bar controller height as a whole is manipulated so that the tab bars can be selected naturally
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        
        NotificationCenter.default.addObserver(self, selector: #selector(postIndexChange(_:)), name: NSNotification.Name("PostOpen"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostLike(_:)), name: Notification.Name("PostLike"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostComment(_:)), name: Notification.Name("PostComment"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAcceptFriend(_:)), name: NSNotification.Name(("FriendRequestAccept")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)

        
        addMapView()
        addFeedTable()
        
        overrideUserInterfaceStyle = .dark
        
        locationManager.delegate = self
        imageManager = SDWebImageManager()
        
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
                
        feedGroup.notify(queue: DispatchQueue.global()) {
            if !self.feedLoaded { self.loadFeed() }
            self.getNearbyPosts(radius: 0.5)
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Mixpanel.mainInstance().track(event: "MapOpen")
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
                self.setUpNavBar()
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
                            }
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
    
    func addMapView() {
        
        let options = MapInitOptions(resourceOptions: ResourceOptions(accessToken: "pk.eyJ1Ijoic3AwdGtlbm55IiwiYSI6ImNrem9tYzhkODAycmUydW50bXVza2JhZmgifQ.Cl0TokRRaMo8UZDImGqp0A"), mapOptions: MapOptions(), cameraOptions: CameraOptions(), styleURI: StyleURI(rawValue: "mapbox://styles/sp0tkenny/ckzpv54l9004114kdu5kcy8w4"))
        UserDataModel.shared.mapView = MapView(frame: UIScreen.main.bounds, mapInitOptions: options)
        UserDataModel.shared.mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        UserDataModel.shared.mapView.ornaments.options.compass.visibility = .hidden
        UserDataModel.shared.mapView.ornaments.options.scaleBar.visibility = .hidden
        UserDataModel.shared.mapView.location.options.puckType = .puck2D()
        view.addSubview(UserDataModel.shared.mapView)
        
        topMapMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 134))
        topMapMask.isUserInteractionEnabled = false
        UserDataModel.shared.mapView.addSubview(topMapMask)
        
        addPostAnnotationManager()
        
        let addY = UserDataModel.shared.largeScreen ? UIScreen.main.bounds.height - 130 : UIScreen.main.bounds.height - 94
        let addX = UIScreen.main.bounds.width/2 - 30.5
        let addButton = UIButton(frame: CGRect(x: addX, y: addY, width: 61, height: 61))
        addButton.setImage(UIImage(named: "AddToSpotButton"), for: .normal)
        addButton.addTarget(self, action: #selector(addTap(_:)), for: .touchUpInside)
        view.addSubview(addButton)
        
        let friendsButton = UIButton(frame: CGRect(x: addX - 61, y: addY, width: 45, height: 45))
        friendsButton.setImage(UIImage(named: "FriendsFeedIcon"), for: .normal)
        friendsButton.addTarget(self, action: #selector(friendsTap(_:)), for: .touchUpInside)
        view.addSubview(friendsButton)
    }
    
    func addFeedTable() {
        
        if feedTableContainer != nil { feedTableContainer.isHidden = false; return }
        feedTableContainer = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height * 1/8, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 7/8))
        feedTableContainer.backgroundColor = UIColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 1)
        feedTableContainer.layer.cornerRadius = 20
        feedTableContainer.isHidden = true
        view.addSubview(feedTableContainer)
        
        let friendsIcon = UIImageView(frame: CGRect(x: 13, y: 18, width: 53, height: 53))
        friendsIcon.image = UIImage(named: "FriendsFeedIcon")
        feedTableContainer.addSubview(friendsIcon)
                
        let friendsLabel = UILabel(frame: CGRect(x: friendsIcon.frame.maxX + 9, y: 27, width: 77, height: 17))
        friendsLabel.text = "Friends"
        friendsLabel.textColor = .black
        friendsLabel.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
        feedTableContainer.addSubview(friendsLabel)
        
        let detailLabel = UILabel(frame: CGRect(x: friendsIcon.frame.maxX + 9, y: friendsLabel.frame.maxY + 3, width: 200, height: 17))
        detailLabel.text = "Your friends latest posts"
        detailLabel.textColor = UIColor(red: 0.742, green: 0.742, blue: 0.742, alpha: 1)
        detailLabel.font = UIFont(name: "SFCompatText-Semibold", size: 15.5)
        feedTableContainer.addSubview(detailLabel)
        
        let feedTableButton = UIButton(frame: CGRect(x: friendsLabel.frame.maxX, y: 7, width: 28, height: 28))
      //  feedTableButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        feedTableButton.setImage(UIImage(named: "MapFeedMinimize"), for: .normal)
        feedTableButton.addTarget(self, action: #selector(feedButtonTap(_:)), for: .touchUpInside)
      //  feedTableContainer.addSubview(feedTableButton)
        
        let exitFriendsButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 81, y: 10, width: 71, height: 71))
        exitFriendsButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exitFriendsButton.setImage(UIImage(named: "FeedExit"), for: .normal)
        exitFriendsButton.addTarget(self, action: #selector(exitFriendsTap(_:)), for: .touchUpInside)
        feedTableContainer.addSubview(exitFriendsButton)
        
        let bottomLine = UIView(frame: CGRect(x: 0, y: 82, width: UIScreen.main.bounds.width, height: 1))
        bottomLine.backgroundColor = UIColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1)
        feedTableContainer.addSubview(bottomLine)
        
        feedTableHighlight = UIView(frame: CGRect(x: 12, y: 84, width: UIScreen.main.bounds.width - 101, height: 48))
        feedTableHighlight.backgroundColor =  UIColor(red: 0.18, green: 0.778, blue: 0.817, alpha: 0.15)
        feedTableHighlight.layer.borderWidth = 1.5
        feedTableHighlight.layer.cornerRadius = 12
        feedTableHighlight.layer.borderColor = UIColor(red: 0.096, green: 0.249, blue: 0.258, alpha: 1).cgColor
        feedTableHighlight.isHidden = selectedFeedIndex == -1
      //  feedTableContainer.addSubview(feedTableHighlight)
        feedTable = UITableView(frame: CGRect(x: 0, y: 84, width: UIScreen.main.bounds.width, height: feedTableContainer.frame.height - 41))
        feedTable.tag = 0
        feedTable.backgroundColor = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1)
        feedTable.separatorStyle = .none
        feedTable.delegate = self
        feedTable.dataSource = self
        feedTable.allowsSelection = true
        feedTable.register(MapFeedCell.self, forCellReuseIdentifier: "FeedCell")
        feedTable.register(MapFeedLoadingCell.self, forCellReuseIdentifier: "FeedLoadingCell")
        feedTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        feedTableContainer.addSubview(feedTable)
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        statusBarMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: statusHeight + 10))
        statusBarMask.backgroundColor = .black
        statusBarMask.alpha = 0.0
        view.addSubview(statusBarMask)
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
        let profileVC = ProfileViewController()
        sheetView = DrawerView(present: profileVC, drawerConrnerRadius: 22, detentsInAscending: [.Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        sheetView?.swipeDownToDismiss = true
        sheetView?.present(to: .Middle)
    }
    
    @objc func friendsTap(_ sender: UIButton) {
        selectedSegmentIndex = 1
        feedTableContainer.isHidden = false
        navigationController?.navigationBar.isHidden = true
        postAnnotationManager.annotations = friendAnnotations
        getFriendPosts(refresh: !friendAnnotations.isEmpty)
    }
    
    @objc func exitFriendsTap(_ sender: UIButton) {
        selectedSegmentIndex = 0
        feedTableContainer.isHidden = true
        navigationController?.navigationBar.isHidden = false
        postAnnotationManager.annotations = nearbyAnnotations
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
    
    func getTitleView() -> UIView {
        let navView = UIView(frame: CGRect(x: 20, y: 0, width: UIScreen.main.bounds.width - 40, height: 35))
        
        let signUpLogo = UIImageView(frame: CGRect(x: 10, y: -5, width: 35, height: 35))
        signUpLogo.image = UIImage(named: "Signuplogo")
        signUpLogo.contentMode = .scaleAspectFill
        navView.addSubview(signUpLogo)
        
        let buttonView = UIView(frame: CGRect(x: navView.bounds.width - 120, y: 0, width: 100, height: 30))
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
    
    func setUpNavBar() {
        
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        
        setTranslucentNav()
        navigationItem.titleView = getTitleView()
    }
    
    @objc func openNotis(_ sender: UIButton) {
        if let notificationsVC = UIStoryboard(name: "Notifications", bundle: nil).instantiateViewController(withIdentifier: "NotificationsVC") as? NotificationsController {
            navigationController?.pushViewController(notificationsVC, animated: true)
        }
    }
    
    func setOpaqueNav() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.addBlackBackground()
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
        feedLoaded = true
        
        /// full friendObjects loaded
        NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
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
    
    func addPostAnnotationManager() {
        postAnnotationManager = UserDataModel.shared.mapView.annotations.makePointAnnotationManager()
        postAnnotationManager.iconAllowOverlap = false
        postAnnotationManager.iconIgnorePlacement = false
        postAnnotationManager.iconOptional = true
        postAnnotationManager.annotations = pointAnnotations
    }
        
    @objc func notifyPostLike(_ sender: NSNotification) {
        /*
        if let info = sender.userInfo as? [String: Any] {
            guard let post = info["post"] as? MapPost else { return }
            guard let index = self.postsList.firstIndex(where: {$0.id == post.id}) else { return }
            self.postsList[index] = post
            
            guard let anno = postAnnotations.first(where: {$0.key == post.id}) else { return }
            
            if let annoView = UserDataModel.shared.mapView.view(for: anno.value) as? StandardPostAnnotationView  {
                annoView.updateLargeImage(post: post, animated: false)
            } else if let annoView = UserDataModel.shared.mapView.view(for: anno.value) as? TextPostAnnotationView {
                annoView.updateLargeImage(post: post, animated: false)
            }
        } */
    }
    
    @objc func notifyPostComment(_ sender: NSNotification) {
        /*
        if let info = sender.userInfo as? [String: Any] {
            guard let commentList = info["commentList"] as? [MapComment] else { return }
            guard let postID = info["postID"] as? String else { return }
            guard let index = self.postsList.firstIndex(where: {$0.id == postID}) else { return }
            self.postsList[index].commentList = commentList
            
            guard let anno = postAnnotations.first(where: {$0.key == postID}) else { return }
            guard let annoView = UserDataModel.shared.mapView.view(for: anno.value) as? StandardPostAnnotationView else { return }
            annoView.updateLargeImage(post: self.postsList[index], animated: false)
        } */
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
            let options = CameraOptions(center: location.coordinate, padding: UserDataModel.shared.mapView.cameraState.padding, anchor: CGPoint(), zoom: 18, bearing: UserDataModel.shared.mapView.cameraState.bearing, pitch: 75)
            UserDataModel.shared.mapView.mapboxMap.setCamera(to: options)
            
            firstTimeGettingLocation = false
            locationGroup.leave()
            
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
        }
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

extension MapController: UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 0: return refresh == .activelyRefreshing ? friendsPostsGroup.count + 1 : friendsPostsGroup.count
        case 1:
            var maxRows = 2
            if tagTable.frame.height > 300 {
                maxRows = 5
            } else if tagTable.frame.height > 250 {
                maxRows = 4
            } else if tagTable.frame.height > 200 {
                maxRows = 3
            }
            return tagUsers.count > maxRows ? maxRows : tagUsers.count
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView.tag {
            
        case 0:
            if indexPath.row < friendsPostsGroup.count {
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! MapFeedCell
                let postIDs = friendsPostsGroup[indexPath.row].postIDs
                
                var posts: [MapPost] = []
                for id in postIDs {
                    posts.append(friendsPostsDictionary[id.0]!)
                }
                
                var newCount = 0
                for post in posts { if !post.seen! { newCount += 1 }}
                let firstPost = posts.first!

                cell.setUp(post: firstPost, postCount: newCount, row: indexPath.row, selected: indexPath.row == selectedFeedIndex)
                return cell
                
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "FeedLoadingCell", for: indexPath) as! MapFeedLoadingCell
                cell.setUp()
                return cell
            }
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsListCell", for: indexPath) as! FriendsListCell
            cell.setUp(friend: tagUsers[indexPath.row])
            return cell
            
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.tag == 1 ? 52 : 69
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch tableView.tag {
        case 1:
            let username = tagUsers[indexPath.row].username
            let infoPass = ["username": username, "tag": tagTable.tag] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("TagSelect"), object: nil, userInfo: infoPass)
            removeTable()
            
        default: return
        }
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            
            if abs(indexPath.row - selectedFeedIndex) > 3 { return }
            
            guard let post = postsList[safe: indexPath.row] else { return }
            if let _ = PostImageModel.shared.loadingOperations[post.id ?? ""] { return }

            let dataLoader = PostImageLoader(post)
            dataLoader.queuePriority = .high
            PostImageModel.shared.loadingQueue.addOperation(dataLoader)
            PostImageModel.shared.loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {

            if abs(indexPath.row - selectedFeedIndex) < 4 { return }

            guard let post = postsList[safe: indexPath.row] else { return }

            if let imageLoader = PostImageModel.shared.loadingOperations[post.id ?? ""] {
                imageLoader.cancel()
                PostImageModel.shared.loadingOperations.removeValue(forKey: post.id ?? "")
            }
        }
    }

    func checkForFeedReload() {
        if selectedFeedIndex > postsList.count - 4 && refresh == .refreshEnabled {
            refresh = .activelyRefreshing
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.getFriendPosts(refresh: false)
            }
        }
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
     /*   tagTable.removeFromSuperview()
        tagUsers.removeAll() */
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
