//
//  MapController.swift
//  Spot
//
//  Created by kbarone on 2/15/19.
//   Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Firebase
import GeoFire
import MapKit
import Mixpanel
import UIKit

protocol MapControllerDelegate: AnyObject {
    func displayHeelsMap()
}

final class MapController: UIViewController {
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var spotService: SpotServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.spotService)
        return service
    }()

    let locationManager = CLLocationManager()
    var friendsPostsListener, mapsListener, mapsPostsListener, notiListener, userListener: ListenerRegistration?
    let homeFetchGroup = DispatchGroup()
    let chapelHillLocation = CLLocation(latitude: 35.9132, longitude: -79.0558)

    var geoQueryLimit: Int = 50

    var firstOpen = false
    var firstTimeGettingLocation = true
    var userLoaded = false
    var mapsLoaded = false
    var friendsLoaded = false
    var homeFetchLeaveCount = 0
    var postsFetched: Bool = false {
        didSet {
            DispatchQueue.main.async { self.mapActivityIndicator.stopAnimating() }
        }
    }

    lazy var postDictionary = [String: MapPost]()
    lazy var postGroup: [MapPostGroup] = []
    lazy var mapFetchIDs: [String] = [] // used to track for deleted posts
    lazy var friendsFetchIDs: [String] = [] // used to track for deleted posts

    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled

    var newMapID: String?

    lazy var addFriendsView: AddFriendsView = {
        let view = AddFriendsView()
        view.layer.cornerRadius = 13
        view.isHidden = false
        return view
    }()

    var titleView: MapTitleView?
    lazy var mapView = SpotMapView()
    lazy var cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 16.5)
        label.textAlignment = .center
        return label
    }()

    lazy var mapActivityIndicator = CustomActivityIndicator()
    lazy var newPostsButton = NewPostsButton()
    lazy var currentLocationButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "CurrentLocationButton"), for: .normal)
        return button
    }()
    lazy var inviteFriendsButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "MapInviteFriendsButton"), for: .normal)
        return button
    }()
    lazy var navBarExtender: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    var sheetView: DrawerView? {
        didSet {
            let hidden = sheetView != nil
            DispatchQueue.main.async {
                self.toggleHomeAppearance(hidden: hidden)
                if !hidden { self.animateHomeAlphas() }
                self.navigationController?.setNavigationBarHidden(hidden, animated: false)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        checkLocationAuth()
        getAdmins() /// get admin users to exclude from analytics
        addNotifications()
        runMapFetches()
        setUpNavBar()
        locationManager.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "MapOpen")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name(("UserProfileLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostOpen(_:)), name: NSNotification.Name(("PostOpen")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyLogout), name: NSNotification.Name(("Logout")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRemove), name: NSNotification.Name(("FriendRemove")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func setUpViews() {
        addMapView()
        addSupplementalViews()
    }

    func addMapView() {
        mapView.delegate = self
        mapView.spotMapDelegate = self

        view.addSubview(mapView)
        mapView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(65)
        }
    }

    func addSupplementalViews() {
        view.addSubview(cityLabel)
        cityLabel.snp.makeConstraints {
            $0.top.equalTo(8)
            $0.centerX.equalToSuperview()
        }

        view.addSubview(mapActivityIndicator)
        mapActivityIndicator.startAnimating()
        mapActivityIndicator.snp.makeConstraints {
            $0.top.equalTo(cityLabel.snp.bottom)
            $0.height.width.equalTo(40)
            $0.centerX.equalToSuperview()
        }

        let addButton = AddButton {
            $0.addTarget(self, action: #selector(addTap(_:)), for: .touchUpInside)
            mapView.addSubview($0)
        }
        addButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(23)
            $0.bottom.equalToSuperview().inset(100) /// offset 65 px for portion of map below fold
            $0.height.width.equalTo(109)
        }

        newPostsButton.isHidden = true
        view.addSubview(newPostsButton)
        newPostsButton.snp.makeConstraints {
            $0.bottom.equalTo(addButton.snp.top).offset(-1)
            $0.trailing.equalTo(-21)
            $0.height.equalTo(68)
            $0.width.equalTo(66)
        }

        currentLocationButton.isHidden = true
        currentLocationButton.addTarget(self, action: #selector(currentLocationTap), for: .touchUpInside)
        view.addSubview(currentLocationButton)
        currentLocationButton.snp.makeConstraints {
            $0.leading.equalTo(addButton).offset(-15)
            $0.bottom.equalTo(addButton.snp.top).offset(8)
            $0.height.width.equalTo(58)
        }

        inviteFriendsButton.isHidden = true
        inviteFriendsButton.addTarget(self, action: #selector(inviteFriendsTap), for: .touchUpInside)
        view.addSubview(inviteFriendsButton)
        inviteFriendsButton.snp.makeConstraints {
            $0.leading.equalTo(11)
            $0.bottom.equalTo(-37)
            $0.width.equalTo(231)
            $0.height.equalTo(83)
        }
    }

    func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil

        view.backgroundColor = .white
        navigationController?.navigationBar.addWhiteBackground()
        navigationItem.titleView = getTitleView()
        if let mapNav = navigationController as? MapNavigationController {
            mapNav.requiredStatusBarStyle = .darkContent
        }
    }

    func getTitleView() -> UIView {
        if let titleView { return titleView }

        titleView = MapTitleView {
            $0.searchButton.addTarget(self, action: #selector(searchTap(_:)), for: .touchUpInside)
            $0.profileButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)
            $0.notificationsButton.addTarget(self, action: #selector(openNotis(_:)), for: .touchUpInside)
        }

        let notificationRef = self.db.collection("users").document(self.uid).collection("notifications")
        let query = notificationRef.whereField("seen", isEqualTo: false)

        /// show green bell on notifications when theres an unseen noti
        if notiListener != nil { notiListener?.remove() }
        print("add noti listener")
        notiListener = query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in
            if err != nil || snap?.metadata.isFromCache ?? false {
                return
            } else {
                if !(snap?.documents.isEmpty ?? true) {
                    self.titleView?.notificationsButton.pendingCount = snap?.documents.count ?? 0
                } else {
                    self.titleView?.notificationsButton.pendingCount = 0
                }
            }
        }

        return titleView ?? UIView()
    }

    func openNewMap() {
        Mixpanel.mainInstance().track(event: "MapControllerNewMapTap")
        if navigationController?.viewControllers.contains(where: { $0 is NewMapController }) ?? false {
            return
        }

        DispatchQueue.main.async { [weak self] in
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                UploadPostModel.shared.createSharedInstance()
                vc.presentedModally = true
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    @objc func currentLocationTap() {
        animateToCurrentLocation()
    }

    @objc func inviteFriendsTap() {
        Mixpanel.mainInstance().track(event: "MapInviteFriendsTap")
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "Add me on sp0t 🌎🦦"] as [Any]

        DispatchQueue.main.async {
            let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
            self.present(activityView, animated: true)
            activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                if completed {
                    Mixpanel.mainInstance().track(event: "MapInviteSent", properties: ["type": activityType?.rawValue ?? ""])
                } else {
                    Mixpanel.mainInstance().track(event: "MapInviteCancelled")
                }
            }
        }
    }

    @objc func addTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapControllerAddTap")
        addFriendsView.removeFromSuperview()

        /// crash on double stack was happening here
        if navigationController?.viewControllers.contains(where: { $0 is AVCameraController }) ?? false {
            return
        }

        guard let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController
        else { return }

        let transition = AddButtonTransition()
        self.navigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(vc, animated: false)
    }

    @objc func profileTap(_ sender: Any) {
        if sheetView != nil { return } /// cancel on double tap
        Mixpanel.mainInstance().track(event: "MapControllerProfileTap")
        let profileVC = ProfileViewController(userProfile: nil)

        sheetView = DrawerView(present: profileVC, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        profileVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    @objc func openNotis(_ sender: UIButton) {
        if sheetView != nil { return } /// cancel on double tap
        Mixpanel.mainInstance().track(event: "MapControllerNotificationsTap")
        let notifVC = NotificationsController()
        sheetView = DrawerView(present: notifVC, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        notifVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    @objc func searchTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapControllerSearchTap")
        openFindFriends()
    }

    @objc func findFriendsTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapControllerFindFriendsTap")
        openFindFriends()
    }

    func openFindFriends() {
        if sheetView != nil { return } // cancel on double tap
        let ffvc = FindFriendsController()
        sheetView = DrawerView(present: ffvc, detentsInAscending: [.top, .middle, .bottom]) { [weak self] in
            self?.sheetView = nil
        }
        ffvc.containerDrawerView = sheetView
    }

    func openPost(posts: [MapPost]) {
        if sheetView != nil { return } /// cancel on double tap
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSelectedMap() {
        // TODO: amend or remove this function - can you open friends map in gallery"
        if sheetView != nil { return } /// cancel on double tap
        let unsortedPosts = postDictionary.map { $0.value }
        let posts = mapView.sortPosts(unsortedPosts)
        let mapType: MapType = .friendsMap
        /// create map from current posts for friends map
        let map = getFriendsMapObject()

        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: posts, presentedDrawerView: nil, mapType: mapType)

        sheetView = DrawerView(present: customMapVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }

        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSpot(spotID: String, spotName: String, mapID: String, mapName: String) {
        /// cancel on double tap
        if sheetView != nil {
            return
        }

        let emptyPost = MapPost(spotID: spotID, spotName: spotName, mapID: mapID, mapName: mapName)

        let spotVC = SpotPageController(mapPost: emptyPost, presentedDrawerView: nil)
        sheetView = DrawerView(present: spotVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }

        spotVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openExploreMaps(onboarding: Bool) {
        let fromValue: ExploreMapViewModel.OpenedFrom = onboarding ? .onBoarding : .mapController
        let viewController = ExploreMapViewController(viewModel: ExploreMapViewModel(serviceContainer: ServiceContainer.shared, from: fromValue))
        let transition = AddButtonTransition()
        self.navigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(viewController, animated: false)
    }

    func toggleHomeAppearance(hidden: Bool) {
        newPostsButton.setHidden(hidden: hidden)
        currentLocationButton.isHidden = hidden
        inviteFriendsButton.isHidden = hidden
        cityLabel.isHidden = hidden
        /// if hidden, remove annotations, else reset with selected annotations
        if hidden {
            addFriendsView.removeFromSuperview()
        } else {
            mapView.delegate = self
            mapView.spotMapDelegate = self
            DispatchQueue.main.async { self.addMapAnnotations() }
        }
    }

    func animateHomeAlphas() {
        navigationController?.navigationBar.alpha = 0.0
        newPostsButton.alpha = 0.0
        currentLocationButton.alpha = 0.0
        inviteFriendsButton.alpha = 0.0
        cityLabel.alpha = 0.0

        UIView.animate(withDuration: 0.15) {
            self.navigationController?.navigationBar.alpha = 1
            self.newPostsButton.alpha = 1
            self.currentLocationButton.alpha = 1
            self.inviteFriendsButton.alpha = 1
            self.cityLabel.alpha = 1
        }
    }

    /// custom reset nav bar (patch fix for CATransition)
    func uploadMapReset() {
        DispatchQueue.main.async { self.setUpNavBar() }
    }
}

extension MapController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
