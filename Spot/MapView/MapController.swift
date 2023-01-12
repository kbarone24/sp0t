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
    weak var homeScreenDelegate: HomeScreenDelegate?
    
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

    private(set) lazy var titleView: MapTitleView = {
        let view = MapTitleView()
        view.searchButton.addTarget(self, action: #selector(searchTap), for: .touchUpInside)
        view.profileButton.addTarget(self, action: #selector(profileTap), for: .touchUpInside)
        view.notificationsButton.addTarget(self, action: #selector(notificationsTap), for: .touchUpInside)
        view.homeTouchArea.addTarget(self, action: #selector(hamburgerTap), for: .touchUpInside)
        return view
    }()
    
    lazy var mapView = SpotMapView()
    lazy var cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 16.5)
        label.textAlignment = .center
        return label
    }()

    lazy var mapActivityIndicator = CustomActivityIndicator(image: UIImage(named: "BeaconActivityIndicator") ?? UIImage())
    lazy var addButton = AddButton()
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
        edgesForExtendedLayout = []
        addMapView()
        addSupplementalViews()
    }

    func addMapView() {
        mapView.delegate = self
        mapView.spotMapDelegate = self

        view.addSubview(mapView)
        mapView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalToSuperview().offset(-228)
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
        mapActivityIndicator.startAnimating(duration: 1.5)
        mapActivityIndicator.snp.makeConstraints {
            $0.width.equalTo(423)
            $0.height.equalTo(625)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-102)
        }

        // all buttons are padded 10px
        inviteFriendsButton.addTarget(self, action: #selector(inviteFriendsTap), for: .touchUpInside)
        view.addSubview(inviteFriendsButton)
        inviteFriendsButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(11)
            $0.bottom.equalTo(-24)
            $0.height.equalTo(79)
        }

        addButton.addTarget(self, action: #selector(addTap), for: .touchUpInside)
        view.addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(inviteFriendsButton.snp.top).offset(-3)
            $0.height.width.equalTo(107)
        }

        currentLocationButton.isHidden = true
        currentLocationButton.addTarget(self, action: #selector(currentLocationTap), for: .touchUpInside)
        view.addSubview(currentLocationButton)
        currentLocationButton.snp.makeConstraints {
            $0.trailing.equalTo(addButton.snp.leading)
            $0.bottom.equalTo(inviteFriendsButton.snp.top).offset(-24)
            $0.height.width.equalTo(60)
        }

        newPostsButton.isHidden = true
        view.addSubview(newPostsButton)
        newPostsButton.snp.makeConstraints {
            $0.bottom.equalTo(currentLocationButton)
            $0.leading.equalTo(addButton.snp.trailing)
            $0.height.equalTo(62)
            $0.width.equalTo(60)
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
        if notiListener != nil { return titleView }
        let notificationRef = self.db.collection("users").document(self.uid).collection("notifications")
        let query = notificationRef.whereField("seen", isEqualTo: false)

        // show green bell on notifications when theres an unseen noti
        notiListener = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] (snap, err) in
            if err != nil || snap?.metadata.isFromCache ?? false {
                return
            } else {
                if !(snap?.documents.isEmpty ?? true) {
                    self?.titleView.notificationsButton.pendingCount = snap?.documents.count ?? 0
                } else {
                    self?.titleView.notificationsButton.pendingCount = 0
                }
            }
        }

        return titleView
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
