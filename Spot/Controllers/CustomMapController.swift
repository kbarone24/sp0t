
import UIKit
import SnapKit
import Mixpanel
import Firebase
import SDWebImage
import Contacts

enum MapType {
    case myMap
    case friendsMap
    case customMap
}

protocol CustomMapDelegate {
    func finishPassing(updatedMap: CustomMap?)
}


class CustomMapController: UIViewController {
    private var topYContentOffset: CGFloat?
    private var middleYContentOffset: CGFloat?
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot!
    var refresh: RefreshStatus = .activelyRefreshing
    
    private var customMapCollectionView: UICollectionView!
    private var floatBackButton: UIButton!
    private var barView: UIView!
    private var titleLabel: UILabel!
    private var barBackButton: UIButton!
    
    private var userProfile: UserProfile?
    public var mapData: CustomMap? {
        didSet {
            if customMapCollectionView != nil { DispatchQueue.main.async {self.customMapCollectionView.reloadData()}}
        }
    }
    private var firstMaxFourMapMemberList: [UserProfile] = []
    private lazy var postsList: [MapPost] = []
    
    public unowned var containerDrawerView: DrawerView? {
        didSet {
            configureDrawerView()
        }
    }
    
    private unowned var containerDrawerView: DrawerView?
    public unowned var profileVC: ProfileViewController?
    private unowned var mapController: UIViewController?
    private lazy var imageManager = SDWebImageManager()
    
    private var mapType: MapType!
    
    init(userProfile: UserProfile? = nil, mapData: CustomMap?, postsList: [MapPost], presentedDrawerView: DrawerView?, mapType: MapType) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile
        self.mapData = mapData
        self.postsList = postsList
        self.containerDrawerView = presentedDrawerView
        self.mapType = mapType
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("CustomMapController(\(self) deinit")
        floatBackButton.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
        barView.removeFromSuperview()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
        if let mapVC = window as? UINavigationController {
            mapController = mapVC.viewControllers[0]
        }
        
        switch mapType {
        case .customMap:
            getMapInfo()
        case .friendsMap:
            print("friends map")
            viewSetup()
            getPosts()
            /// run post fetch
        case .myMap:
            print("my map")
            viewSetup()
            getPosts()
            /// run post fetch
        default: return
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        configureDrawerView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        Mixpanel.mainInstance().track(event: "CustomMapOpen")
    }
}

extension CustomMapController {
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
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMapMember()
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
        containerDrawerView?.swipeDownToDismiss = false
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .Middle) }
    }
    
    private func viewSetup() {
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToTopCompletion), name: NSNotification.Name("DrawerViewToTopComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToMiddleCompletion), name: NSNotification.Name("DrawerViewToMiddleComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DrawerViewToBottomCompletion), name: NSNotification.Name("DrawerViewToBottomComplete"), object: nil)
        
        view.backgroundColor = .white
        navigationItem.setHidesBackButton(true, animated: true)
        
        customMapCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(CustomMapHeaderCell.self, forCellWithReuseIdentifier: "CustomMapHeaderCell")
            view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "CustomMapBodyCell")
            return view
        }()
        view.addSubview(customMapCollectionView)
        customMapCollectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        // Need a new pan gesture to react when profileCollectionView scroll disables
        let scrollViewPanGesture = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        scrollViewPanGesture.delegate = self
        customMapCollectionView.addGestureRecognizer(scrollViewPanGesture)
        customMapCollectionView.isScrollEnabled = false
        
        floatBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
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
            $0.frame = CGRect(origin: CGPoint(x: 0, y: 55), size: CGSize(width: view.frame.width, height: 18))
            barView.addSubview($0)
        }
        barBackButton = UIButton {
            $0.setImage(UIImage(named: "BackArrow-1"), for: .normal)
            $0.setTitle("", for: .normal)
            $0.addTarget(self, action: #selector(backButtonAction), for: .touchUpInside)
            $0.isHidden = true
            barView.addSubview($0)
        }
        barBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(22)
            $0.centerY.equalTo(titleLabel)
        }
        containerDrawerView?.slideView.addSubview(barView)
    }
    
    private func getMapMember() {
        let dispatch = DispatchGroup()
        var memberList: [UserProfile] = []
        // Get the first four map member
        for index in 0...(mapData!.memberIDs.count < 4 ? (mapData!.memberIDs.count - 1) : 3) {
            dispatch.enter()
            getUserInfo(userID: mapData!.memberIDs[index]) { user in
                memberList.insert(user, at: 0)
                dispatch.leave()
            }
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.firstMaxFourMapMemberList = memberList
            self.firstMaxFourMapMemberList.sort(by: {$0.id == self.mapData!.founderID && $1.id != self.mapData!.founderID})
            self.customMapCollectionView.reloadSections(IndexSet(integer: 0))
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
        
        query.getDocuments { [weak self] snap, err in
            if err != nil { print("err", err)}
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
                    postGroup.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        if post.id ?? "" != "" { self.postsList.append(post) }
                        postGroup.leave()
                    }
                    
                } catch {
                    continue
                }
            }
            postGroup.notify(queue: .main) {
                self.postsList.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
                self.customMapCollectionView.reloadData()
                if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
            }
        }
    }
    
    @objc func DrawerViewToTopCompletion() {
        Mixpanel.mainInstance().track(event: "CustomMapDrawerOpen")
        UIView.transition(with: self.barBackButton, duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: {
            self.barBackButton.isHidden = false
        })
        barView.isUserInteractionEnabled = true
        customMapCollectionView.isScrollEnabled = true
    }
    @objc func DrawerViewToMiddleCompletion() {
        Mixpanel.mainInstance().track(event: "CustomMapDrawerHalf")
        barBackButton.isHidden = true
    }
    @objc func DrawerViewToBottomCompletion() {
        Mixpanel.mainInstance().track(event: "CustomMapDrawerClose")
        barBackButton.isHidden = true
    }
    
    @objc func backButtonAction() {
        barBackButton.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Change `2.0` to the desired number of seconds.
            if self.navigationController?.viewControllers.count == 1 {
                self.containerDrawerView?.closeAction()
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
        delegate?.finishPassing(updatedMap: mapData)
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
        return mapType == .customMap ? 2 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 && mapType == .customMap ? 1 : postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 && mapType == .customMap ? "CustomMapHeaderCell" : "CustomMapBodyCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(mapData: mapData, fourMapMemberProfile: firstMaxFourMapMemberList)
            if mapData!.memberIDs.contains(UserDataModel.shared.userInfo.id!) {
                headerCell.actionButton.addTarget(self, action: #selector(editMapAction), for: .touchUpInside)
            }
            return headerCell
        } else if let bodyCell = cell as? CustomMapBodyCell {
            bodyCell.cellSetup(postData: postsList[indexPath.row])
            return bodyCell
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 && mapType == .customMap ? CGSize(width: view.frame.width, height: mapData?.mapDescription != nil ? 180 : 155) : CGSize(width: view.frame.width/2 - 0.5, height: (view.frame.width/2 - 0.5) * 267 / 194.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 { return }
        let postData = postsList[indexPath.row]
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = [postData]
        postVC.containerDrawerView = containerDrawerView
        DispatchQueue.main.async { self.navigationController!.pushViewController(postVC, animated: true) }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }
}

extension CustomMapController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let itemHeight = UIScreen.main.bounds.width * 1.373
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 3)) && refresh == .refreshEnabled {
            self.getPosts()
            refresh = .activelyRefreshing
        }
        
        if topYContentOffset != nil && containerDrawerView?.status == .Top {
            // Disable the bouncing effect when scroll view is scrolled to top
            if scrollView.contentOffset.y <= topYContentOffset! {
                scrollView.contentOffset.y = topYContentOffset!
                containerDrawerView?.canDrag = false
                containerDrawerView?.swipeToNextState = false
            }
            // Show navigation bar
            if scrollView.contentOffset.y > topYContentOffset! {
                barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
                titleLabel.text = scrollView.contentOffset.y > 0 ? mapData?.mapName : ""
            }
        }
        
        // Get middle y content offset
        if middleYContentOffset == nil {
            middleYContentOffset = scrollView.contentOffset.y
        }
        
        // Set scroll view content offset when in transition
        if
            middleYContentOffset != nil &&
                topYContentOffset != nil &&
                scrollView.contentOffset.y <= middleYContentOffset! &&
                containerDrawerView!.slideView.frame.minY >= middleYContentOffset! - topYContentOffset!
        {
            scrollView.contentOffset.y = middleYContentOffset!
        }
        
        // Whenever drawer view is not in top position, scroll to top, disable scroll and enable drawer view swipe to next state
        if containerDrawerView?.status != .Top {
            //  customMapCollectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            customMapCollectionView.isScrollEnabled = false
            containerDrawerView?.swipeToNextState = true
        }
    }
}

extension CustomMapController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Swipe up y translation < 0
        // Swipe down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
        
        // Get the initial Top y position contentOffset
        if containerDrawerView?.status == .Top && topYContentOffset == nil {
            topYContentOffset = customMapCollectionView.contentOffset.y
        }
        
        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user swipe direction
        if
            topYContentOffset != nil &&
                containerDrawerView?.status == .Top &&
                customMapCollectionView.contentOffset.y <= topYContentOffset!
        {
            containerDrawerView?.swipeToNextState = yTranslation > 0 ? true : false
        }
        
        // Preventing the drawer view to be dragged when it's status is top and user is scrolling down
        if
            containerDrawerView?.status == .Top &&
                customMapCollectionView.contentOffset.y > topYContentOffset ?? -91 &&
                yTranslation > 0 &&
                containerDrawerView?.swipeToNextState == false
        {
            containerDrawerView?.canDrag = false
            containerDrawerView?.slideView.frame.origin.y = 0
        }
        
        // Reset drawer view varaiables when the drawer view is on top and user swipes down
        if customMapCollectionView.contentOffset.y <= topYContentOffset ?? -91 && yTranslation > 0 {
            containerDrawerView?.canDrag = true
            barBackButton.isHidden = true
        }
        
        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
