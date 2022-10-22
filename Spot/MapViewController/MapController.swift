//
//  MapController.swift
//  Spot
//
//  Created by kbarone on 2/15/19.
//   Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseMessaging
import FirebaseUI
import Geofirestore
import MapKit
import Mixpanel
import Photos
import UIKit

protocol MapControllerDelegate: AnyObject {
    func displayHeelsMap()
}

final class MapController: UIViewController {

    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    var mapView: SpotMapView!
    var titleView: MapTitleView!
    var bottomMapMask: UIView!

    var newPostsButton: NewPostsButton!
    var mapsCollection: UICollectionView!
    var selectedItemIndex = 0

    let locationManager = CLLocationManager()
    lazy var imageManager = SDWebImageManager()
    var userListener, mapsListener, newPostListener: ListenerRegistration!

    let homeFetchGroup = DispatchGroup()
    let mapPostsGroup = DispatchGroup()

    var firstOpen = false
    var firstTimeGettingLocation = true
    var feedLoaded = false
    var mapsLoaded = false
    var friendsLoaded = false
    
    lazy var friendsPostsDictionary = [String: MapPost]()
    lazy var postGroup: [MapPostGroup] = []

    var notiListener: ListenerRegistration!

    var refresh: RefreshStatus = .activelyRefreshing
    var friendsRefresh: RefreshStatus = .refreshEnabled

    var startTime: Int64!    
    var addFriendsView: AddFriendsView!

    var heelsMapID = "9ECABEF9-0036-4082-A06A-C8943428FFF4"
    var newMapID: String?
    
    var serviceContainer: ServiceContainer?

    /// sheet view: Must declare outside to listen to UIEvent
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
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsListAdd), name: NSNotification.Name(("FriendsListAdd")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRemove), name: NSNotification.Name(("FriendRemove")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func setUpViews() {
        addMapView()
        addMapsCollection()
        addNewPostsButton()
    }

    func addMapView() {
        mapView = SpotMapView {
            $0.delegate = self
            $0.spotMapDelegate = self
            view.addSubview($0)
        }
        makeMapHomeConstraints()

        let addButton = AddButton {
            $0.addTarget(self, action: #selector(addTap(_:)), for: .touchUpInside)
            mapView.addSubview($0)
        }
        addButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(23)
            $0.bottom.equalToSuperview().inset(110) /// offset 65 px for portion of map below fold
            $0.height.width.equalTo(92)
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
        mapsCollection.register(AddMapCell.self, forCellWithReuseIdentifier: "AddMapCell")
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
        if titleView != nil { return titleView }

        titleView = MapTitleView {
            $0.searchButton.addTarget(self, action: #selector(searchTap(_:)), for: .touchUpInside)
            $0.profileButton.addTarget(self, action: #selector(profileTap(_:)), for: .touchUpInside)
            $0.notificationsButton.addTarget(self, action: #selector(openNotis(_:)), for: .touchUpInside)
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
                    self.titleView.notificationsButton.pendingCount = snap!.documents.count
                } else {
                    self.titleView.notificationsButton.pendingCount = 0
                }
            }
        }

        return titleView
    }

    func openNewMap() {
        Mixpanel.mainInstance().track(event: "MapControllerNewMapTap")
        if navigationController!.viewControllers.contains(where: { $0 is NewMapController }) { return }
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(withIdentifier: "NewMap") as? NewMapController {
                UploadPostModel.shared.createSharedInstance()
                vc.presentedModally = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    @objc func addTap(_ sender: UIButton) {
        guard let serviceContainer else { return }
        
        let vmmm = ExploreMapViewController(viewModel: ExploreMapViewModel(serviceContainer: serviceContainer))
        let transition = AddButtonTransition()
        self.navigationController?.view.layer.add(transition, forKey: kCATransition)
        self.navigationController?.pushViewController(vmmm, animated: false)
        
        return

        Mixpanel.mainInstance().track(event: "MapControllerAddTap")

        if addFriendsView != nil {
            addFriendsView.removeFromSuperview()
        }

        /// crash on double stack was happening here
        if navigationController?.viewControllers.contains(where: { $0 is AVCameraController }) ?? false {
            return
        }

        guard let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController
        else { return }

        // let transition = AddButtonTransition()
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
        if sheetView != nil { return } /// cancel on double tap
        let ffvc = FindFriendsController()
        sheetView = DrawerView(present: ffvc, detentsInAscending: [.top], closeAction: {
            self.sheetView = nil
        })
        sheetView?.swipeDownToDismiss = false
        sheetView?.canInteract = false
        sheetView?.present(to: .top)
        ffvc.contentDrawer = sheetView
    }

    func openPost(posts: [MapPost]) {
        if sheetView != nil { return } /// cancel on double tap
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, detentsInAscending: [.bottom, .middle, .top], closeAction: {
            self.sheetView = nil
        })
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSelectedMap() {
        if sheetView != nil { return } /// cancel on double tap
        var map = getSelectedMap()
        let unsortedPosts = map == nil ? friendsPostsDictionary.map { $0.value } : map!.postsDictionary.map { $0.value }
        let posts = mapView.sortPosts(unsortedPosts)
        let mapType: MapType = map == nil ? .friendsMap : .customMap
        /// create map from current posts for friends map
        if map == nil { map = getFriendsMapObject() }

        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: posts, presentedDrawerView: nil, mapType: mapType)
        sheetView = DrawerView(present: customMapVC, detentsInAscending: [.bottom, .middle, .top], closeAction: {
            self.sheetView = nil
        })

        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSpot(spotID: String, spotName: String, mapID: String, mapName: String) {
        if sheetView != nil { return } /// cancel on double tap
        var emptyPost = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp(date: Date()))
        emptyPost.spotID = spotID
        emptyPost.spotName = spotName
        emptyPost.mapID = mapID
        emptyPost.mapName = mapName
        let spotVC = SpotPageController(mapPost: emptyPost, presentedDrawerView: nil)
        sheetView = DrawerView(present: spotVC, detentsInAscending: [.bottom, .middle, .top], closeAction: {
            self.sheetView = nil
        })
        spotVC.containerDrawerView = sheetView
        spotVC.containerDrawerView?.showCloseButton = false
        sheetView?.present(to: .top)
    }

    func toggleHomeAppearance(hidden: Bool) {
        mapsCollection.isHidden = hidden
        newPostsButton.setHidden(hidden: hidden)
        /// if hidden, remove annotations, else reset with selected annotations
        if hidden {
            if addFriendsView != nil {
                self.addFriendsView.removeFromSuperview()
            } /// remove add friends view whenever leaving home screen
        } else {
            mapView.delegate = self
            mapView.spotMapDelegate = self
            DispatchQueue.main.async { self.addMapAnnotations(index: self.selectedItemIndex, reload: true) }
        }
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
        DispatchQueue.main.async { self.setUpNavBar() }
    }
}

extension MapController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            Mixpanel.mainInstance().track(event: "LocationServicesDenied")
        } else if status == .authorizedWhenInUse || status == .authorizedWhenInUse {
            Mixpanel.mainInstance().track(event: "LocationServicesAllowed")
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        UserDataModel.shared.currentLocation = location
        if firstTimeGettingLocation {
            if manager.accuracyAuthorization == .reducedAccuracy { Mixpanel.mainInstance().track(event: "PreciseLocationOff") }
            /// set current location to show while feed loads
            firstTimeGettingLocation = false
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)

            /// map might load before user accepts location services
            if self.mapsLoaded {
                self.displayHeelsMap()
            } else {
                self.mapView.setRegion(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 400_000, longitudinalMeters: 400_000), animated: false)
            }
        }
    }

    func checkLocationAuth() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // prompt user to open their settings if they havent allowed location services

        case .restricted, .denied:
            presentLocationAlert()
            break

        case .authorizedWhenInUse, .authorizedAlways:
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()

        @unknown default:
            return
        }
    }

    func presentLocationAlert() {
        let alert = UIAlertController(
            title: "Spot needs your location to find spots near you",
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "Settings", style: .default) { _ in
                Mixpanel.mainInstance().track(event: "LocationServicesSettingsOpen")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:])
                }
            }
        )

        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
            }
        )

        self.present(alert, animated: true, completion: nil)
    }
}

extension MapController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      /*  if otherGestureRecognizer.view?.tag == 16 || otherGestureRecognizer.view?.tag == 23 || otherGestureRecognizer.view?.tag == 30 {
            return false
        } */
        return true
    }
}
