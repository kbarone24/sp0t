import Contacts
import Firebase
import MapKit
import Mixpanel
import SDWebImage
import SnapKit
import UIKit

enum MapType {
    case myMap
    case friendsMap
    case customMap
}

class CustomMapController: UIViewController {
    var topYContentOffset: CGFloat?
    var middleYContentOffset: CGFloat?

    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot?
    var refresh: RefreshStatus = .activelyRefreshing

    var userProfile: UserProfile?
    public var mapData: CustomMap?

    var firstMaxFourMapMemberList: [UserProfile] = []
    lazy var postsList: [MapPost] = []

    unowned var mapController: MapController?
    unowned var containerDrawerView: DrawerView? {
        didSet {
            if !ranSetUp { runInitialFetches() }
        }
    }
    var drawerViewIsDragging = false
    var currentContainerCanDragStatus: Bool?
    var offsetOnDismissal: CGFloat = 0

    var mapType: MapType = .customMap
    var centeredMap = false
    var ranSetUp = false
    var cancelOnDismiss = false

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = .clear
        view.register(CustomMapHeaderCell.self, forCellWithReuseIdentifier: "CustomMapHeaderCell")
        view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "CustomMapBodyCell")
        view.register(SimpleMapHeaderCell.self, forCellWithReuseIdentifier: "SimpleMapHeaderCell")
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()

    private lazy var floatBackButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "BackArrowDark"), for: .normal)
        button.backgroundColor = .white
        button.setTitle("", for: .normal)
        button.layer.cornerRadius = 19
        return button
    }()

    lazy var barView = UIView()

    lazy var barBackButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "BackArrowDark"), for: .normal)
        return button
    }()
    
    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.text = ""
        label.textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.numberOfLines = 1
        label.clipsToBounds = true
        return label
    }()

    init(userProfile: UserProfile? = nil, mapData: CustomMap?, postsList: [MapPost], presentedDrawerView: DrawerView?, mapType: MapType) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile
        self.postsList = postsList.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.mapData = mapData
        self.mapType = mapType
        self.containerDrawerView = presentedDrawerView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("CustomMapController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
        floatBackButton.removeFromSuperview()
        barView.removeFromSuperview()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let window = UIApplication.shared.keyWindow?.rootViewController ?? UIViewController()
        if let mapNav = window as? UINavigationController {
            guard let mapVC = mapNav.viewControllers[0] as? MapController else { return }
            mapController = mapVC
        }
        if !ranSetUp && containerDrawerView != nil { runInitialFetches() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        configureDrawerView(present: !isMovingToParent) // only present when view reappears
        barView.isHidden = false

        mapController?.mapView.delegate = self
        mapController?.mapView.spotMapDelegate = self
        mapController?.mapView.shouldCluster = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CustomMapOpen")
        // only shouldn't be empty if another CustomMapController was stacked
        // Use centered map variable to see if fetch ran yet for stacked VC
        if (mapController?.mapView.annotations.isEmpty ?? true) || !centeredMap {
            DispatchQueue.main.async { self.addInitialAnnotations() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        barView.isHidden = true
    }

    private func runInitialFetches() {
        ranSetUp = true

        switch mapType {
        case .customMap:
            getMapInfo()
        case .friendsMap:
            viewSetup()
            getPosts()
        case .myMap:
            viewSetup()
            getPosts()
        }
    }

    private func getMapInfo() {
        // map passed through
        if mapData?.founderID ?? "" != "" {
            runMapSetup()
            return
        }
        
        Task { [weak self] in
            do {
                guard let mapID = self?.mapData?.id else {
                    return
                }
                
                let mapsService = try ServiceContainer.shared.service(for: \.mapsService)
                let map = try await mapsService.getMap(mapID: mapID)
                self?.mapData = map
                self?.runMapSetup()
                
                DispatchQueue.main.async {
                    self?.addInitialAnnotations()
                }
            } catch {
                return
            }
        }
    }

    private func runMapSetup() {
        if mapData == nil { return }
        mapData?.addSpotGroups()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMapMembers()
            self.getPosts()
        }
        DispatchQueue.main.async { self.viewSetup() }
    }

    private func setUpNavBar() {
        guard let navigationController = navigationController else { return }
        navigationController.setNavigationBarHidden(false, animated: true)
        navigationController.navigationBar.isTranslucent = true
    }

    private func configureDrawerView(present: Bool) {
        if containerDrawerView == nil { return }
        containerDrawerView?.canInteract = true
        containerDrawerView?.canDrag = currentContainerCanDragStatus ?? true
        currentContainerCanDragStatus = nil
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false

        if containerDrawerView?.status.rawValue != DrawerViewDetent.top.rawValue && present {
            DispatchQueue.main.async { self.containerDrawerView?.present(to: .top) }
        }
       // configureFullScreen()
       // collectionView.contentOffset.y = offsetOnDismissal
    }

    private func viewSetup() {
        if containerDrawerView == nil { return }
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToTopCompletion), name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToMiddleCompletion), name: NSNotification.Name("DrawerViewToMiddleComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToBottomCompletion), name: NSNotification.Name("DrawerViewToBottomComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostOpen(_:)), name: NSNotification.Name(("PostOpen")), object: nil)

        view.backgroundColor = .white
        navigationItem.setHidesBackButton(true, animated: true)

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        // Need a new pan gesture to react when profileCollectionView scroll disables
        let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        scrollViewPanGesture.delegate = self
        collectionView.addGestureRecognizer(scrollViewPanGesture)
        collectionView.isScrollEnabled = false

        guard let container = containerDrawerView else { return }
        floatBackButton.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
        mapController?.view.insertSubview(floatBackButton, belowSubview: container.slideView)
        floatBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(15)
            $0.top.equalToSuperview().offset(49)
            $0.height.width.equalTo(38)
        }

        containerDrawerView?.slideView.addSubview(barView)
        let height: CGFloat = UserDataModel.shared.screenSize == 0 ? 65 : 90
        barView.snp.makeConstraints {
            $0.leading.top.width.equalToSuperview()
            $0.height.equalTo(height)
        }

        barBackButton.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
        barView.addSubview(barBackButton)
        barBackButton.snp.makeConstraints {
            $0.leading.equalTo(22)
            $0.bottom.equalTo(-12)
            $0.height.equalTo(21.5)
            $0.width.equalTo(30)
        }

        barView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(60)
            $0.bottom.equalTo(barBackButton)
            $0.height.equalTo(22)
        }
    }

    @objc func DrawerViewToTopCompletion() {
        guard currentContainerCanDragStatus == nil else { return }
        if containerDrawerView == nil { return }
        configureFullScreen()
    }

    func configureFullScreen() {
        barBackButton.alpha = 0.0
        self.barBackButton.isHidden = false
        UIView.transition(with: self.barBackButton, duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: {
            self.barBackButton.alpha = 1.0
        })

        // When in top position enable collection view scroll
        collectionView.isScrollEnabled = true
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        barView.isUserInteractionEnabled = true
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
        barView.isUserInteractionEnabled = false
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
        barView.isUserInteractionEnabled = false
        titleLabel.text = ""
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
      //  guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }

        postsList.removeAll(where: { $0.id == post.id })
        mapData?.removePost(postID: post.id ?? "", spotID: spotDelete ? post.spotID ?? "" : "")
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if map.id == mapData?.id ?? "" {
            mapData = map
            DispatchQueue.main.async { self.collectionView.reloadData() }
            DispatchQueue.global().async { self.getMapMembers() }
        }
    }

    @objc func backButtonAction() {
        cancelOnDismiss = true
        centeredMap = false // will prevent drawer to close on map move
        Mixpanel.mainInstance().track(event: "CustomMapBackTap")
        barBackButton.isHidden = true
        floatBackButton.isHidden = true
        // remove observer to cancel drawer methods before sheetView is set to nil on mapVC (remove remaining observers on deinit)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DrawerViewToBottomComplete"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DrawerViewToMiddleComplete"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)

        DispatchQueue.main.async {
            self.mapController?.mapView.removeAllAnnos()
            if self.navigationController?.viewControllers.count == 1 { self.mapController?.offsetCustomMapCenter() }
            self.containerDrawerView?.closeAction()
            self.mapController?.mapView.delegate = nil
            self.mapController?.mapView.spotMapDelegate = nil
        }
    }

    @objc func addAction() {
        Mixpanel.mainInstance().track(event: "CustomMapAddTap")
        // crash on double stack was happening here
        if navigationController?.viewControllers.contains(where: { $0 is AVCameraController }) ?? false { return }
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
}
