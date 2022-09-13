
import UIKit
import SnapKit
import Mixpanel
import Firebase
import SDWebImage
import Contacts
import MapKit
import Geofirestore

enum MapType {
    case myMap
    case friendsMap
    case customMap
}

class CustomMapController: UIViewController {
    var topYContentOffset: CGFloat?
    var middleYContentOffset: CGFloat?
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot!
    var refresh: RefreshStatus = .activelyRefreshing
    
    var collectionView: UICollectionView!
    var floatBackButton: UIButton!
    var barView: UIView!
    var titleLabel: UILabel!
    var barBackButton: UIButton!
  //  private var addButton: UIButton!
    
    var userProfile: UserProfile?
    public var mapData: CustomMap? {
        didSet {
            if collectionView != nil { DispatchQueue.main.async { self.collectionView.reloadData()} }
          //  if addButton != nil { addButton.isHidden = !(mapData?.memberIDs.contains(uid) ?? false) }
        }
    }
    var firstMaxFourMapMemberList: [UserProfile] = []
    lazy var postsList: [MapPost] = []
    
    unowned var mapController: MapController?
    unowned var containerDrawerView: DrawerView? {
        didSet {
            configureDrawerView()
            if !ranSetUp { runInitialFetches() }
        }
    }
    var drawerViewIsDragging = false
    var currentContainerCanDragStatus: Bool? = nil
        
    var mapType: MapType!
    var centeredMap = false
    var fullScreenOnDismissal = false
    var ranSetUp = false
    
    var circleQuery: GFSCircleQuery?
    let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("posts"))
    lazy var geoFetchGroup = DispatchGroup()
    
    init(userProfile: UserProfile? = nil, mapData: CustomMap?, postsList: [MapPost], presentedDrawerView: DrawerView?, mapType: MapType) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile
        self.mapData = mapData
        self.postsList = postsList.sorted(by: {$0.timestamp.seconds > $1.timestamp.seconds})
        self.mapType = mapType
        self.containerDrawerView = presentedDrawerView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("CustomMapController(\(self) deinit")
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
        mapController?.mapView.shouldCluster = true
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
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMap(mapID: self.mapData!.id!) { [weak self] map in
                guard let self = self else { return }
                self.mapData = map
                self.runMapSetup()
            }
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
            $0.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 78)
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
    
    @objc func DrawerViewToTopCompletion() {
        guard currentContainerCanDragStatus == nil else { return }
        if containerDrawerView == nil { return }

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
        if containerDrawerView == nil { return }
        Mixpanel.mainInstance().track(event: "CustomMapDrawerHalf")
        // This line of code move the initial load naivgation bar up so it won't block the friend list button
        navigationController?.navigationBar.frame.origin = CGPoint(x: 0, y: 0)

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
        if containerDrawerView == nil { return }
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
   
        postsList.removeAll(where: {$0.id == post.id})
        mapData?.removePost(postID: post.id!, spotID: spotDelete ? post.spotID! : "")
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }
    
    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if map.id == mapData!.id {
            mapData = map
            DispatchQueue.global().async { self.getMapMembers() }
        }
    }
    
    @objc func backButtonAction() {
        centeredMap = false /// will prevent drawer to close on map move
        Mixpanel.mainInstance().track(event: "CustomMapBackTap")
        barBackButton.isHidden = true
        floatBackButton.isHidden = true
        NotificationCenter.default.removeObserver(self) /// remove observer to cancel drawer methods

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

