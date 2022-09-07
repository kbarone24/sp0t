
import UIKit
import SnapKit
import Mixpanel
import Firebase
import SDWebImage
import Contacts
import MapKit

enum MapType {
    case myMap
    case friendsMap
    case customMap
}

class CustomMapController: UIViewController {
    private var topYContentOffset: CGFloat?
    private var middleYContentOffset: CGFloat?
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot!
    var refresh: RefreshStatus = .activelyRefreshing
    
    private var collectionView: UICollectionView!
    private var floatBackButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
  //  private var addButton: UIButton!
    private var drawerViewIsDragging = false
    
    private var userProfile: UserProfile?
    public var mapData: CustomMap? {
        didSet {
            if collectionView != nil { DispatchQueue.main.async { self.collectionView.reloadData()} }
          //  if addButton != nil { addButton.isHidden = !(mapData?.memberIDs.contains(uid) ?? false) }
        }
    }
    private var firstMaxFourMapMemberList: [UserProfile] = []
    private lazy var postsList: [MapPost] = []
    
    public unowned var containerDrawerView: DrawerView? {
        didSet {
            configureDrawerView()
            if !ranSetUp { runInitialFetches() }
        }
    }
    
    private unowned var mapController: MapController?
    private lazy var imageManager = SDWebImageManager()
    
    private var mapType: MapType!
    var centeredMap = false
    var fullScreenOnDismissal = false
    var ranSetUp = false
    
    private var currentContainerCanDragStatus: Bool? = nil
    
    init(userProfile: UserProfile? = nil, mapData: CustomMap?, postsList: [MapPost], presentedDrawerView: DrawerView?, mapType: MapType) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile
        self.mapData = mapData
        self.postsList = postsList
        self.mapType = mapType
        self.containerDrawerView = presentedDrawerView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("CustomMapController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
        if barView != nil {  barView.removeFromSuperview() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
        if let mapNav = window as? UINavigationController {
            guard let mapVC = mapNav.viewControllers[0] as? MapController else { return }
            mapController = mapVC
        }
        if !ranSetUp && containerDrawerView != nil { runInitialFetches() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        configureDrawerView()
        if barView != nil { barView.isHidden = false }

        mapController?.mapView.delegate = self
        mapController?.mapView.spotMapDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "CustomMapOpen")
        DispatchQueue.main.async { self.addInitialAnnotations(posts: self.postsList) }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mapController?.mapView.removeAllAnnos()
        if barView != nil { barView.isHidden = true }
    }
}

extension CustomMapController {
    private func runInitialFetches() {
        ranSetUp = true
        addInitialPosts()

        switch mapType {
        case .customMap:
            getMapInfo()
        case .friendsMap:
            viewSetup()
            getPosts()
        case .myMap:
            viewSetup()
            getPosts()
        default: return
        }
    }
    
    private func addInitialPosts() {
        if !(mapData?.postGroup.isEmpty ?? true) {
            postsList = mapData!.postsDictionary.map{$0.value}.sorted(by: {$0.timestamp.seconds > $1.timestamp.seconds})
            if self.collectionView != nil { DispatchQueue.main.async { self.collectionView.reloadData() } }
        }
    }
    
    private func getMapInfo() {
        /// map passed through
        if mapData?.founderID ?? "" != "" {
            runMapSetup()
            return
        }
        getMap(mapID: mapData?.id ?? "") { [weak self] map in
            guard let self = self else { return }
            self.mapData = map
            self.runMapSetup()
        }
    }
    
    private func runMapSetup() {
        if mapData == nil { return }
        mapData!.addSpotGroups()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMapMembers()
            self.getPosts()
        }
        DispatchQueue.main.async { self.viewSetup() }
    }
    
    private func setUpNavBar() {
        navigationController!.setNavigationBarHidden(false, animated: true)
        navigationController!.navigationBar.isTranslucent = true
    }
    
    private func configureDrawerView() {
        if containerDrawerView == nil { return }
        containerDrawerView?.canInteract = true
        containerDrawerView?.canDrag = currentContainerCanDragStatus ?? true
        currentContainerCanDragStatus = nil
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false
        let position: DrawerViewDetent = fullScreenOnDismissal ? .Top : .Middle
        if position.rawValue != containerDrawerView?.status.rawValue {
            DispatchQueue.main.async { self.containerDrawerView?.present(to: position) }
        }
        fullScreenOnDismissal = false
    }
    
    private func viewSetup() {
        if containerDrawerView == nil { return }
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToTopCompletion), name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToMiddleCompletion), name: NSNotification.Name("DrawerViewToMiddleComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToBottomCompletion), name: NSNotification.Name("DrawerViewToBottomComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)

        view.backgroundColor = .white
        navigationItem.setHidesBackButton(true, animated: true)
        
        collectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(CustomMapHeaderCell.self, forCellWithReuseIdentifier: "CustomMapHeaderCell")
            view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "CustomMapBodyCell")
            view.register(SimpleMapHeaderCell.self, forCellWithReuseIdentifier: "SimpleMapHeaderCell")
            return view
        }()
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        // Need a new pan gesture to react when profileCollectionView scroll disables
        let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        scrollViewPanGesture.delegate = self
        collectionView.addGestureRecognizer(scrollViewPanGesture)
        collectionView.isScrollEnabled = false
        
        floatBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrowDark"), for: .normal)
            $0.backgroundColor = .white
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            $0.layer.cornerRadius = 19
            mapController?.view.insertSubview($0, belowSubview: containerDrawerView!.slideView)
        }
        floatBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(15)
            $0.top.equalToSuperview().offset(49)
            $0.height.width.equalTo(38)
        }
        
        barView = UIView {
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 91)
            $0.isUserInteractionEnabled = false
        }
        titleLabel = UILabel {
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.text = ""
            $0.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.sizeToFit()
            $0.frame = CGRect(origin: CGPoint(x: 0, y: 55), size: CGSize(width: view.frame.width, height: 23))
            barView.addSubview($0)
        }
        barBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrowDark"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            $0.isHidden = true
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.centerY.equalTo(titleLabel)
        }
        
      /*  addButton = AddButton {
            $0.addTarget(self, action: #selector(addAction), for: .touchUpInside)
            $0.isHidden = true
            view.addSubview($0)
        }
        addButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview().inset(35)
            $0.width.height.equalTo(73)
        } */

        containerDrawerView?.slideView.addSubview(barView)
    }
    
    private func getMapMembers() {
        let dispatch = DispatchGroup()
        var memberList: [UserProfile] = []
        firstMaxFourMapMemberList.removeAll()
        
        let communityMap = mapData!.communityMap ?? false
        let members = communityMap ? mapData!.memberIDs.reversed() : mapData!.memberIDs
        // Get the first four map member
        for index in 0...(members.count < 4 ? (members.count - 1) : 3) {
            dispatch.enter()
            getUserInfo(userID: members[index]) { user in
                memberList.insert(user, at: 0)
                dispatch.leave()
            }
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.firstMaxFourMapMemberList = memberList
            if !communityMap { self.firstMaxFourMapMemberList.sort(by: {$0.id == self.mapData!.founderID && $1.id != self.mapData!.founderID}) }
            self.collectionView.reloadData()
        }
    }
    
    private func getPosts() {
        var query = db.collection("posts").order(by: "timestamp", descending: true).limit(to: 21)
        switch mapType {
        case .customMap:
            query = query.whereField("mapID", isEqualTo: mapData!.id!)
        case .myMap:
            query = query.whereField("posterID", isEqualTo: userProfile!.id!)
        case .friendsMap:
            query = query.whereField("friendsList", arrayContains: uid)
        default: return
        }
        if endDocument != nil { query = query.start(atDocument: endDocument) }
        
        DispatchQueue.global().async {
            query.getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                guard let allDocs = snap?.documents else { return }
                if allDocs.count < 21 { self.refresh = .refreshDisabled }
                self.endDocument = allDocs.last
                
                let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()
                let postGroup = DispatchGroup()
                for doc in docs {
                    do {
                        let unwrappedInfo = try doc.data(as: MapPost.self)
                        guard let postInfo = unwrappedInfo else { return }
                        if self.postsList.contains(where: {$0.id == postInfo.id}) { continue }
                        if !self.hasMapPostAccess(post: postInfo) { continue }
                        postGroup.enter()
                        self.setPostDetails(post: postInfo) { [weak self] post in
                            guard let self = self else { return }
                            if post.id ?? "" != "", !self.postsList.contains(where: {$0.id == post.id!}) {
                                DispatchQueue.main.async {
                                    self.postsList.append(post)
                                    self.mapData!.postsDictionary.updateValue(post, forKey: post.id!)
                                    let groupData = self.mapData!.updateGroup(post: post)
                                    if self.mapType == .friendsMap { self.addAnnotation(post: post) } else { self.addAnnotation(group: groupData.group, newGroup: groupData.newGroup) }
                                }
                            }
                            postGroup.leave()
                        }
                        
                    } catch {
                        continue
                    }
                }
                postGroup.notify(queue: .main) {
                    self.postsList.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
                    self.collectionView.reloadData()
                    if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
                    if !self.centeredMap { self.setInitialRegion() }
                }
            }
        }
    }
    
    func hasMapPostAccess(post: MapPost) -> Bool {
        if UserDataModel.shared.deletedPostIDs.contains(post.id!) { return false }
        if mapType == .friendsMap || mapType == .myMap {
            /// show only friends level posts for friends map and my map,
            if post.privacyLevel == "invite" && post.hideFromFeed ?? false {
                return false
            }
            return UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) || uid == post.posterID
        }
        return true
    }
    
    func addAnnotation(post: MapPost) {
        if mapType == .friendsMap {
            mapController?.mapView.addPostAnnotation(post: post)
        }
    }
    
    func addAnnotation(group: MapPostGroup?, newGroup: Bool) {
        if group != nil {
            if newGroup {
                /// add new group
                mapController?.mapView.addSpotAnnotation(group: group!, map: mapData!)
            } else {
                /// update existing group
                if let anno = mapController?.mapView.annotations.first(where: {$0.coordinate.isEqualTo(coordinate: group!.coordinate)}) {
                    mapController?.mapView.removeAnnotation(anno)
                    mapController?.mapView.addSpotAnnotation(group: group!, map: mapData!)
                }
            }
        }
    }
        
    func addInitialAnnotations(posts: [MapPost]) {
        if mapType == .friendsMap {
            for post in posts { mapController?.mapView.addPostAnnotation(post: post) }
        } else {
            for group in mapData!.postGroup { mapController?.mapView.addSpotAnnotation(group: group, map: mapData!) }
        }
    }
    
    @objc func DrawerViewToTopCompletion() {
        guard currentContainerCanDragStatus == nil else { return }
        Mixpanel.mainInstance().track(event: "CustomMapDrawerOpen")
        UIView.transition(with: self.barBackButton, duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: {
            self.barBackButton.isHidden = false
        })
        // When in top position enable collection view scroll
        barView.isUserInteractionEnabled = true
        collectionView.isScrollEnabled = true
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        // Get top y content offset
        if topYContentOffset == nil {
            topYContentOffset = collectionView.contentOffset.y
        }
    }
    @objc func DrawerViewToMiddleCompletion() {
        Mixpanel.mainInstance().track(event: "CustomMapDrawerHalf")
        collectionView.isScrollEnabled = false
        containerDrawerView?.swipeToNextState = true
        barBackButton.isHidden = true
        
        // Get middle y content offset
        if middleYContentOffset == nil {
            middleYContentOffset = collectionView.contentOffset.y
        }
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        barView.backgroundColor = .clear
        titleLabel.text = ""
    }
    @objc func DrawerViewToBottomCompletion() {
        Mixpanel.mainInstance().track(event: "CustomMapDrawerClose")
        collectionView.isScrollEnabled = false
        containerDrawerView?.swipeToNextState = true
        barBackButton.isHidden = true
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        barView.backgroundColor = .clear
        titleLabel.text = ""
    }
    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
      //  guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
   
        /// check if post being deleted from map controllers child and update map if necessary
        let secondVC = navigationController?.viewControllers[safe: (navigationController?.viewControllers.count ?? 2) - 2] is Self
        postsList.removeAll(where: {$0.id == post.id})
        mapData?.removePost(postID: post.id!, spotID: spotDelete ? post.spotID! : "")

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            if secondVC {
                self.mapController?.mapView.removeAllAnnos()
                self.addInitialAnnotations(posts: self.postsList)
            }
        }
    }
    
    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if map.id == mapData!.id {
            mapData = map
            DispatchQueue.global().async { self.getMapMembers() }
        }
    }
    
    @objc func backButtonAction() {
        Mixpanel.mainInstance().track(event: "CustomMapBackTap")
        barBackButton.isHidden = true
        floatBackButton.isHidden = true
        DispatchQueue.main.async {
            if self.navigationController?.viewControllers.count == 1 { self.mapController?.offsetCustomMapCenter() }
            self.containerDrawerView?.closeAction()
        }
    }
    
    @objc func addAction() {
        Mixpanel.mainInstance().track(event: "CustomMapAddTap")
        if navigationController!.viewControllers.contains(where: {$0 is AVCameraController}) { return } /// crash on double stack was happening here
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Upload", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
                vc.mapObject = self.mapData
                self.barView.isHidden = true
                let transition = AddButtonTransition()
                self.navigationController?.view.layer.add(transition, forKey: kCATransition)
                self.navigationController?.pushViewController(vc, animated: false)
            }
        }
    }
    
    @objc func editMapAction() {
        Mixpanel.mainInstance().track(event: "EnterEditMapController")
        let editVC = EditMapController(mapData: mapData!)
        editVC.customMapVC = self
        editVC.modalPresentationStyle = .fullScreen
        present(editVC, animated: true)
    }
}

extension CustomMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 && mapType == .customMap ? "CustomMapHeaderCell" : indexPath.section == 0 ? "SimpleMapHeaderCell" : "CustomMapBodyCell"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(mapData: mapData, fourMapMemberProfile: firstMaxFourMapMemberList)
            if mapData!.memberIDs.contains(UserDataModel.shared.uid) {
                headerCell.actionButton.addTarget(self, action: #selector(editMapAction), for: .touchUpInside)
            }
            return headerCell
            
        } else if let headerCell = cell as? SimpleMapHeaderCell {
            let text = mapType == .friendsMap ? "Friends map" : "@\(userProfile!.username)'s posts"
            headerCell.mapText = text
            return headerCell
            
        } else if let bodyCell = cell as? CustomMapBodyCell {
            bodyCell.cellSetup(postData: postsList[indexPath.row])
            return bodyCell
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 && mapType == .customMap ? CGSize(width: UIScreen.main.bounds.width, height: mapData?.mapDescription != nil ? 180 : 155) : indexPath.section == 0 ? CGSize(width: view.frame.width, height: 35) : CGSize(width: UIScreen.main.bounds.width/2 - 0.5, height: (UIScreen.main.bounds.width/2 - 0.5) * 267 / 194.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 { return }
        openPost(posts: postsList, row: indexPath.item)
        Mixpanel.mainInstance().track(event: "CustomMapOpenPostFromGallery")
    }
    
    func openPost(posts: [MapPost], row: Int) {
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        if containerDrawerView?.status == .Top { fullScreenOnDismissal = true }
        currentContainerCanDragStatus = containerDrawerView?.canDrag
        postVC.postsList = posts
        postVC.selectedPostIndex = row
        postVC.containerDrawerView = containerDrawerView
        DispatchQueue.main.async { self.navigationController!.pushViewController(postVC, animated: true) }
    }
    
    func openSpot(spotID: String, spotName: String) {
        var emptyPost = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp(date: Date()))
        emptyPost.spotID = spotID
        emptyPost.spotName = spotName
        emptyPost.mapID = mapData!.id
        emptyPost.mapName = mapData!.mapName
        let spotVC = SpotPageController(mapPost: emptyPost, presentedDrawerView: containerDrawerView)
        navigationController?.pushViewController(spotVC, animated: true)
    }
}

extension CustomMapController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let itemHeight = UIScreen.main.bounds.width * 1.373
        
        // Check if need to refresh according to content position
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 1.5)) && refresh == .refreshEnabled {
            self.getPosts()
            refresh = .activelyRefreshing
        }
        
        if topYContentOffset != nil && containerDrawerView?.status == .Top {
            // Disable the bouncing effect when scroll view is scrolled to top
            if scrollView.contentOffset.y <= topYContentOffset! {
                scrollView.contentOffset.y = topYContentOffset!
            }
            // Show navigation bar + adjust offset for small header
            if scrollView.contentOffset.y > topYContentOffset! {
                UIView.animate(withDuration: 0.3) {
                    self.barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
                }
                var titleText = ""
                if scrollView.contentOffset.y > 0 {
                    titleText = mapType == .friendsMap ? "Friends map" : mapType == .myMap ? "@\(userProfile!.username)'s posts" : mapData?.mapName ?? ""
                }
                titleLabel.text = titleText
            }
        }
        
        // Set scroll view content offset when in transition
        if
            middleYContentOffset != nil &&
            topYContentOffset != nil &&
            scrollView.contentOffset.y <= middleYContentOffset! &&
            containerDrawerView!.slideView.frame.minY >= (middleYContentOffset! - topYContentOffset!)
        {
            scrollView.contentOffset.y = middleYContentOffset!
        }
    }
}

extension CustomMapController: SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append(mapData!.postsDictionary[id]!) }
        DispatchQueue.main.async { self.openPost(posts: posts, row: 0) }
    }
    
    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }
        
    func openPostFromFriendsPost(view: FriendPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append(mapData!.postsDictionary[id]!) }
        DispatchQueue.main.async { self.openPost(posts: posts, row: 0) }
    }
    
    func centerMapOnPostsInCluster(view: FriendPostAnnotationView) {
        var coordinates: [CLLocationCoordinate2D] = []
        for id in view.postIDs {
            if let post = mapData!.postsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false)
        DispatchQueue.main.async {
            self.containerDrawerView?.present(to: .Bottom)
            self.mapController?.mapView.setRegion(region, animated: true)
        }
    }
}

extension CustomMapController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mapView = mapView as? SpotMapView else { return MKAnnotationView() }
        
        if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.contains(where: {$0 is PostAnnotation}) {
                let posts = getPostsFor(cluster: anno)
                return mapView.getPostClusterAnnotation(anno: anno, posts: posts)
            } else if anno.memberAnnotations.contains(where: {$0 is SpotPostAnnotation}) {
                return mapView.getSpotClusterAnnotation(anno: anno, selectedMap: mapData)
            }
        } else if let anno = annotation as? PostAnnotation {
            guard let post = mapData!.postsDictionary[anno.postID] else { return MKAnnotationView() }
            return mapView.getPostAnnotation(anno: anno, post: post)
            
        } else if let anno = annotation as? SpotPostAnnotation {
            /// set up spot post view with 1 post
            return mapView.getSpotAnnotation(anno: anno, selectedMap: mapData)
            
        }
        return MKAnnotationView()
    }
    
/*    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        print("change visible")
        if refresh == .refreshEnabled {
            getPosts()
            refresh = .activelyRefreshing
        }
    }
    */
    func getPostsFor(cluster: MKClusterAnnotation) -> [MapPost] {
        var posts: [MapPost] = []
        for memberAnno in cluster.memberAnnotations {
            if let member = memberAnno as? PostAnnotation, let post = mapData!.postsDictionary[member.postID] {
                posts.append(post)
            }
        }
        return mapController!.mapView.sortPosts(posts)
    }
    
    func setInitialRegion() {
        let coordinates = postsList.map({$0.coordinate})
        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapController?.mapView.setRegion(region, animated: false)
        mapController?.mapView.setOffsetRegion(region: region, offset: -200, animated: false)
        centeredMap = true
    }
}

extension CustomMapController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Finger swipes up y translation < 0
        // Finger swipes down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y

        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user finger swipe direction
        // Status is top and content is top
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            collectionView.contentOffset.y <= topYContentOffset!
        {
            // Reset drawer view varaiables when user finger swipes down
            if yTranslation > 0 {
                containerDrawerView?.canDrag = true
                barBackButton.isHidden = true
                containerDrawerView?.swipeToNextState = true
            }
        }

        // Preventing the drawer view to be dragged when it's status is top but content is not on top and user finger is swiping up
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            collectionView.contentOffset.y > topYContentOffset! &&
            yTranslation < 0
        {
            containerDrawerView?.canDrag = false
            containerDrawerView?.swipeToNextState = false
            containerDrawerView?.slideView.frame.origin.y = 0
        }

        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
