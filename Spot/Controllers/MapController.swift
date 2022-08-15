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
import FirebaseMessaging

class MapController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var mapView: MKMapView!
    var titleView: MapTitleView!
    var bottomMapMask: UIView!
    
    var newPostsButton: NewPostsButton!
    var mapsCollection: UICollectionView!
    var selectedItemIndex = 0
    
    let locationManager = CLLocationManager()
    lazy var imageManager = SDWebImageManager()
    var userListener, newPostListener: ListenerRegistration!
    
    let homeFetchGroup = DispatchGroup()
    let mapPostsGroup = DispatchGroup()
    
    var firstTimeGettingLocation = true
    var feedLoaded = false
    var shouldCluster = true /// should cluster is false when nearby (tab index 1) selected and max zoom enabled
    
    lazy var friendsPostsDictionary = [String: MapPost]()
    lazy var postAnnotations = [String: PostAnnotation]()
    
    /// use to avoid deleted documents entering from cache
    lazy var deletedSpotIDs: [String] = []
    lazy var deletedPostIDs: [String] = []
    lazy var deletedFriendIDs: [String] = []
    
    var notiListener: ListenerRegistration!
    
    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled
    
    var startTime: Int64!
    
    /// sheet view: Must declare outside to listen to UIEvent
    private var sheetView: DrawerView? {
        didSet {
            let hidden = sheetView != nil
            navigationController?.setNavigationBarHidden(hidden, animated: false)
            toggleHomeAppearance(hidden: hidden)
            animateHomeAlphas()
        }
    }
    
    override func viewDidLoad() {
        setUpViews()
        checkLocationAuth()
        getAdmins() /// get admin users to exclude from analytics
        addNotifications()
        runMapFetches()
        setUpNavBar()
        
        locationManager.delegate = self
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "MapOpen")
    }
        
    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name(("UserProfileLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostOpen(_:)), name: NSNotification.Name(("PostOpen")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChange(_:)), name: NSNotification.Name(("PostChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)

        //  NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
    }
    
    func setUpViews() {
        addMapView()
        addMapsCollection()
        addNewPostsButton()
    }
    
    func addMapView() {
        mapView = MKMapView {
            $0.delegate = self
            $0.mapType = .mutedStandard
            $0.overrideUserInterfaceStyle = .light
            $0.pointOfInterestFilter = .excludingAll
            $0.showsCompass = false
            $0.showsTraffic = false
            $0.tag = 13
            $0.register(FriendPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "FriendsPost")
            $0.register(SpotPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotPost")
            $0.register(SpotNameAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotName")
            view.addSubview($0)
        }
        makeMapHomeConstraints()
                        
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
    
    func makeMapHomeConstraints() {
        mapView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
         //   $0.top.equalTo(mapsCollection.snp.bottom)
            $0.bottom.equalToSuperview().offset(65)
        }
    }
    
    func addMapsCollection() {
        let layout = UICollectionViewFlowLayout {
            $0.minimumInteritemSpacing = 5
            $0.scrollDirection = .horizontal
        }
        mapsCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        mapsCollection.backgroundColor = .white
        mapsCollection.showsHorizontalScrollIndicator = false
        mapsCollection.contentInset = UIEdgeInsets(top: 5, left: 9, bottom: 0, right: 9)
        mapsCollection.delegate = self
        mapsCollection.dataSource = self
        mapsCollection.register(MapHomeCell.self, forCellWithReuseIdentifier: "MapCell")
        mapsCollection.register(MapLoadingCell.self, forCellWithReuseIdentifier: "MapLoadingCell")
        view.addSubview(mapsCollection)
        mapsCollection.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(115)
        }
    }
    
    func addNewPostsButton() {
        newPostsButton = NewPostsButton {
            $0.isHidden = true
            view.addSubview($0)
        }
        newPostsButton.snp.makeConstraints {
            $0.top.equalTo(mapsCollection.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }
    }
    
    func setUpNavBar() {
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(false, animated: true)
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
                } else {
                    self.titleView.notiButton.pendingCount = 0
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
        profileVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
    }
    
    @objc func openNotis(_ sender: UIButton) {
        let notifVC = NotificationsController()
        
        sheetView = DrawerView(present: notifVC, drawerConrnerRadius: 22, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        notifVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
    }
    
    func openPost(posts: [MapPost]) {
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, drawerConrnerRadius: 22, detentsInAscending: [.Top], closeAction: {
            self.sheetView = nil
        })
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
    }
    
    func openSelectedMap() {
        let map = getSelectedMap()
        let unsortedPosts = map == nil ? friendsPostsDictionary.map{$0.value} : map!.postsDictionary.map{$0.value}
        let posts = sortPosts(unsortedPosts)
        let mapType: MapType = map == nil ? .friendsMap : .customMap
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: posts, presentedDrawerView: nil, mapType: mapType)
        sheetView = DrawerView(present: customMapVC, drawerConrnerRadius: 22, detentsInAscending: [.Top], closeAction: {
            self.sheetView = nil
        })
        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .Middle)
    }
    
    func toggleHomeAppearance(hidden: Bool) {
        mapsCollection.isHidden = hidden
        newPostsButton.isHidden = hidden
    }
    
    func animateHomeAlphas() {
        navigationController?.navigationBar.alpha = 0.0
        mapsCollection.alpha = 0.0
        newPostsButton.alpha = 0.0
        
        UIView.animate(withDuration: 0.15) {
            self.navigationController?.navigationBar.alpha = 1
            self.mapsCollection.alpha = 1
            self.newPostsButton.alpha = 1
        }
    }
    
    /// custom reset nav bar (patch fix for CATransition)
    func uploadMapReset() {
        DispatchQueue.main.async {
            self.setUpNavBar()
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
        if (firstTimeGettingLocation) {
            /// set current location to show while feed loads
            mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 400000, longitudinalMeters: 400000), animated: false)
            firstTimeGettingLocation = false
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
        }
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
    var profileButton: UIButton!
    var notiButton: NotificationsButton!
    var searchButton: UIButton!
    
    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
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

class NewPostsButton: UIButton {
    var contentArea: UIView!
    var textLabel: UILabel!
    var newPostsIndicator: UIImageView!
    var carat: UIImageView!
    
    var unseenPosts: Int = 0 {
        didSet {
            if unseenPosts > 0 {
                let text = unseenPosts > 1 ? "\(unseenPosts) new posts" : "\(unseenPosts) new post"
                textLabel.text = text
                textLabel.snp.updateConstraints({$0.trailing.equalToSuperview().inset(38)})
                newPostsIndicator.isHidden = false
                carat.isHidden = true
            } else {
                textLabel.text = "See all posts"
                textLabel.snp.updateConstraints({$0.trailing.equalToSuperview().inset(32)})
                newPostsIndicator.isHidden = true
                carat.isHidden = false
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)
        
        contentArea = UIView {
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.95)
            $0.layer.cornerRadius = 18
            addSubview($0)
        }
        contentArea.snp.makeConstraints({$0.leading.trailing.top.bottom.equalToSuperview().inset(5)})
        
        textLabel = UILabel {
            $0.textColor = UIColor(red: 0.663, green: 0.663, blue: 0.663, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 14)
            $0.clipsToBounds = true
            contentArea.addSubview($0)
        }
        textLabel.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.top.equalTo(12)
            $0.bottom.equalToSuperview().inset(11)
            $0.trailing.equalToSuperview().inset(32)
        }
        
        newPostsIndicator = UIImageView {
            $0.image = UIImage(named: "NewPostsIcon")
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        newPostsIndicator.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(10)
            $0.width.height.equalTo(23)
            $0.centerY.equalToSuperview()
        }
        
        carat = UIImageView {
            $0.image = UIImage(named: "SideCarat")
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        carat.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.width.equalTo(8.9)
            $0.height.equalTo(15)
            $0.centerY.equalToSuperview()
        }
    }
    
    @objc func tap() {
        guard let mapVC = viewContainingController() as? MapController else { return }
        if unseenPosts > 0 {
            mapVC.animateToMostRecentPost()
        } else {
            mapVC.openSelectedMap()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
