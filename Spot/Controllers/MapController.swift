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

class MapController: UIViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }

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
        Mixpanel.mainInstance().track(event: "MapControllerAddTap")
        if addFriendsView != nil { addFriendsView.removeFromSuperview() }
        if navigationController!.viewControllers.contains(where: {$0 is AVCameraController}) { return } /// crash on double stack was happening here

        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
                let transition = AddButtonTransition()
                self.navigationController?.view.layer.add(transition, forKey: kCATransition)
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }

    @objc func profileTap(_ sender: Any) {
        if sheetView != nil { return } /// cancel on double tap
        Mixpanel.mainInstance().track(event: "MapControllerProfileTap")
        let profileVC = ProfileViewController(userProfile: nil)
        sheetView = DrawerView(present: profileVC, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        profileVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
    }

    @objc func openNotis(_ sender: UIButton) {
        if sheetView != nil { return } /// cancel on double tap
        Mixpanel.mainInstance().track(event: "MapControllerNotificationsTap")
        let notifVC = NotificationsController()
        sheetView = DrawerView(present: notifVC, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        notifVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
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
        sheetView = DrawerView(present: ffvc, detentsInAscending: [.Top], closeAction: {
            self.sheetView = nil
        })
        sheetView?.swipeDownToDismiss = false
        sheetView?.canInteract = false
        sheetView?.present(to: .Top)
        ffvc.contentDrawer = sheetView
    }

    func openPost(posts: [MapPost]) {
        if sheetView != nil { return } /// cancel on double tap
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
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
        sheetView = DrawerView(present: customMapVC, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })

        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .Top)
    }

    func openSpot(spotID: String, spotName: String, mapID: String, mapName: String) {
        if sheetView != nil { return } /// cancel on double tap
        var emptyPost = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp(date: Date()))
        emptyPost.spotID = spotID
        emptyPost.spotName = spotName
        emptyPost.mapID = mapID
        emptyPost.mapName = mapName
        let spotVC = SpotPageController(mapPost: emptyPost, presentedDrawerView: nil)
        sheetView = DrawerView(present: spotVC, detentsInAscending: [.Bottom, .Middle, .Top], closeAction: {
            self.sheetView = nil
        })
        spotVC.containerDrawerView = sheetView
        spotVC.containerDrawerView?.showCloseButton = false
        sheetView?.present(to: .Top)
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
            break
            // prompt user to open their settings if they havent allowed location services
        case .restricted, .denied:
          //  presentLocationAlert()
            break
        case .authorizedWhenInUse, .authorizedAlways:
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()
            break
        @unknown default:
            fatalError()
        }
    }

    func presentLocationAlert() {
        let alert = UIAlertController(title: "Spot needs your location to find spots near you", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
            switch action.style {
            case .default:
                Mixpanel.mainInstance().track(event: "LocationServicesSettingsOpen")
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)! as URL, options: [:]) { (_) in
                }

            case .cancel:
                print("cancel")
            case .destructive:
                print("destruct")
            @unknown default:
                fatalError()
            }}))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            switch action.style {
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
      /*  if otherGestureRecognizer.view?.tag == 16 || otherGestureRecognizer.view?.tag == 23 || otherGestureRecognizer.view?.tag == 30 {
            return false
        } */
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
            $0.backgroundColor = UIColor(red: 1, green: 0.421, blue: 0.873, alpha: 1)
            $0.layer.cornerRadius = 16 / 2
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

class ProfileButton: UIButton {
    var profileImage: UIImageView!
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 39 / 2
        layer.borderColor = UIColor.black.cgColor
        layer.borderWidth = 2

        profileImage = UIImageView {
            $0.layer.cornerRadius = 33 / 2
            $0.layer.masksToBounds = true
            addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(3)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MapTitleView: UIView {
    var spotLogo: UIImageView!
    var profileButton: ProfileButton!
    var notificationsButton: NotificationsButton!
    var searchButton: UIButton!

    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        spotLogo = UIImageView {
            $0.image = UIImage(named: "HomeLogo")
            addSubview($0)
        }
        spotLogo.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.width.equalTo(83.37)
            $0.height.equalTo(36)
            $0.centerY.equalToSuperview()
        }

        profileButton = ProfileButton {
            addSubview($0)
        }
        profileButton.snp.makeConstraints {
            $0.trailing.equalTo(-22)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(39)
        }

        notificationsButton = NotificationsButton {
            addSubview($0)
        }
        notificationsButton.snp.makeConstraints {
            $0.trailing.equalTo(profileButton.snp.leading).offset(-20)
            $0.centerY.equalToSuperview().offset(-3) /// offset for noti indicator
            $0.height.equalTo(35)
            $0.width.equalTo(30)
        }

        searchButton = UIButton {
            $0.setImage(UIImage(named: "FindFriendsNavIcon"), for: .normal)
            addSubview($0)
        }
        searchButton.snp.makeConstraints {
            $0.trailing.equalTo(notificationsButton.snp.leading).offset(-20)
            $0.centerY.equalToSuperview().offset(2.5)
            $0.width.equalTo(45)
            $0.height.equalTo(33.75)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class AddFriendsView: UIView {
    var note: UILabel!
    var profileButton: UIButton!
    var addFriendButton: UIButton!
    var searchButton: UIButton!

    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 17
        self.backgroundColor = .white

        note = UILabel {
            $0.text = "Add friends to your map"
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            addSubview($0)
        }

        note.snp.makeConstraints {
            $0.top.equalToSuperview().offset(11)
            $0.centerX.equalToSuperview()
        }

        let animals = UIImageView {
            $0.contentMode = .scaleToFill
            $0.image = UIImage(named: "FriendsEmptyState")
            addSubview($0)
        }

        animals.snp.makeConstraints {
            $0.height.equalTo(53.12)
            $0.width.equalTo(151)
            $0.centerX.equalToSuperview().offset(-5)
            $0.centerY.equalToSuperview().offset(-10)
        }

        addFriendButton = UIButton {
            $0.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 1)
            $0.layer.cornerRadius = 13
            $0.setImage(UIImage(named: "AddFriendIcon"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 7)
            let customButtonTitle = NSMutableAttributedString(string: "Find Friends", attributes: [
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Bold", size: 15) as Any,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            $0.setAttributedTitle(customButtonTitle, for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = false
            addSubview($0)
        }
        addFriendButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(15)
            $0.bottom.equalToSuperview().offset(-13)
            $0.height.equalTo(39)
        }

        let cancel = UIButton {
            $0.setImage(UIImage(named: "ChooseSpotCancel"), for: .normal)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(self.closeFindFriends(_:)), for: .touchUpInside)
            $0.isHidden = false
            addSubview($0)
        }

        cancel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-5)
            $0.top.equalToSuperview().offset(5)
            $0.height.width.equalTo(30)
        }

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func closeFindFriends(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "MapControllerCloseFindFriends")
        self.removeFromSuperview()
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
                textLabel.snp.updateConstraints({ $0.trailing.equalToSuperview().inset(38) })
                newPostsIndicator.isHidden = false
                carat.isHidden = true
            } else {
                textLabel.text = "See all posts"
                textLabel.snp.updateConstraints({ $0.trailing.equalToSuperview().inset(32) })
                newPostsIndicator.isHidden = true
                carat.isHidden = false
            }
        }
    }

    var totalPosts: Int = 0 {
        didSet {
            if totalPosts == 0 { isHidden = true }
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
        contentArea.snp.makeConstraints({ $0.leading.trailing.top.bottom.equalToSuperview().inset(5) })

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

    func setHidden(hidden: Bool) {
        if totalPosts == 0 {
            isHidden = true
        } else {
            isHidden = hidden
        }
    }

    @objc func tap() {
        guard let mapVC = viewContainingController() as? MapController else { return }
        if unseenPosts > 0 {
            Mixpanel.mainInstance().track(event: "MapControllerAnimateToMostRecentPost")
            mapVC.animateToMostRecentPost()
        } else {
            Mixpanel.mainInstance().track(event: "MapControllerOpenSelectedMap")
            mapVC.openSelectedMap()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
