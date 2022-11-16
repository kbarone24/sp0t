//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFunctions
import Mixpanel
import SDWebImage
import SnapKit
import UIKit

class ProfileViewController: UIViewController {
    // MARK: Fetched datas
    var userProfile: UserProfile? {
        didSet {
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }
    lazy var maps = [CustomMap]()
    lazy var posts = [MapPost]()
    var relation: ProfileRelation = .myself

    private var pendingFriendRequestNotiID: String? {
        didSet {
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }

    private lazy var imageManager = SDWebImageManager()
    public unowned var containerDrawerView: DrawerView? {
        didSet {
            configureDrawerView()
        }
    }

    var postsFetched = false {
        didSet {
            toggleNoPosts()
        }
    }
    var mapsFetched = false {
        didSet {
            toggleNoPosts()
        }
    }

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(ProfileHeaderCell.self, forCellWithReuseIdentifier: "ProfileHeaderCell")
        view.register(ProfileMyMapCell.self, forCellWithReuseIdentifier: "ProfileMyMapCell")
        view.register(ProfileBodyCell.self, forCellWithReuseIdentifier: "ProfileBodyCell")
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return view
    }()
    lazy var noPostLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        label.isHidden = true
        return label
    }()
    lazy var activityIndicator = CustomActivityIndicator()
    
    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    private lazy var mapPostService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()
    
    
    private lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()

    deinit {
        print("ProfileViewController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
    }

    init(userProfile: UserProfile? = nil, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        containerDrawerView = presentedDrawerView
        if UserDataModel.shared.userInfo.blockedBy?.contains(userProfile?.id ?? "") ?? false {
            return
        }
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile

        /// need to add immediately to track active user profile getting fetched
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name(("UserProfileLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyMapsLoad(_:)), name: NSNotification.Name(("UserMapsLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditMap(_:)), name: NSNotification.Name(("EditMap")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRequestAccept(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if userProfile?.id ?? "" == "" { getUserInfo(); return }
        getUserRelation()
        viewSetup()
        runFetches()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        configureDrawerView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ProfileOpen")
    }

    private func setUpNavBar() {
        navigationController?.setNavigationBarHidden(false, animated: false)

        // Hacky way to avoid the nav bar get pushed up, when user go to custom map and drag the drawer to top, to middle and go back to profile
        navigationController?.navigationBar.frame.origin = CGPoint(x: 0.0, y: 47.0)

        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white

        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20) as Any
        ]

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(backTap)
        )

        if relation != .myself {
            let button = UIBarButtonItem(
                image: UIImage(named: "Elipses"),
                style: .plain,
                target: self,
                action: #selector(elipsesTap))
            button.customView?.backgroundColor = .gray
            button.imageInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            navigationItem.rightBarButtonItem = button
        }
    }

    private func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false
        containerDrawerView?.present(to: .top)
    }

    private func toggleNoPosts() {
        DispatchQueue.main.async {
            self.noPostLabel.isHidden = self.postsFetched && (self.maps.isEmpty && self.posts.isEmpty) ? false : true
            self.activityIndicator.stopAnimating()
        }
    }

    private func getUserInfo() {
        guard let username = userProfile?.username, !username.isEmpty else { return }
        
        Task {
            guard let user = try? await userService?.getUserFromUsername(username: username) else {
                return
            }
            self.userProfile = user
            self.getUserRelation()
            self.viewSetup()
            self.runFetches()
        }
    }

    func getUserRelation() {
        guard let userProfile else { return }
        if userProfile.id == UserDataModel.shared.uid {
            relation = .myself
        } else if UserDataModel.shared.userInfo.friendIDs.contains(userProfile.id ?? "") {
            relation = .friend
        } else if userProfile.blockedBy?.contains(UserDataModel.shared.uid) ?? false {
            relation = .blocked
        } else if UserDataModel.shared.userInfo.pendingFriendRequests.contains(userProfile.id ?? "") {
            relation = .pending
        } else if userProfile.pendingFriendRequests.contains(UserDataModel.shared.uid) {
            relation = .received
        } else {
            relation = .stranger
        }
    }

    func runFetches() {
        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMaps()
            self.getNinePosts()
        }
    }

    func viewSetup() {
        view.backgroundColor = .white
        // inputViewController?.edgesForExtendedLayout = .none
        self.title = ""
        navigationItem.backButtonTitle = ""

        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)

        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        noPostLabel.text = "\(userProfile?.username ?? "") hasn't posted yet"
        view.addSubview(noPostLabel)
        noPostLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(243)
        }

        activityIndicator = CustomActivityIndicator {
            $0.isHidden = false
            collectionView.addSubview($0)
        }
        activityIndicator.snp.makeConstraints {
            $0.width.height.equalTo(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }
    }

    func getNinePosts() {
        guard let userID = userProfile?.id else { return }
        let db = Firestore.firestore()
        let q0 = db.collection("posts").whereField("posterID", isEqualTo: userID)
        let query = q0.whereField("friendsList", arrayContains: UserDataModel.shared.uid).order(by: "timestamp", descending: true).limit(to: 9)
        query.getDocuments { [weak self] (snap, _) in
            guard let snap, let self else { return }
            let dispatch = DispatchGroup()
            if snap.documents.isEmpty && (self.relation == .friend || self.relation == .myself) { self.postsFetched = true }
            for doc in snap.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if UserDataModel.shared.deletedPostIDs.contains(postInfo.id ?? "") { continue }
                    dispatch.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { post in
                        self.posts.append(post)
                        self.postsFetched = true
                        dispatch.leave()
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
            dispatch.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.collectionView.reloadData()
            }
        }
    }

    func getMaps() {
        if relation == .myself {
            mapsFetched = true
            maps = UserDataModel.shared.userInfo.mapsList.filter({ $0.posterIDs.contains(UserDataModel.shared.uid) }) /// only show maps user is member of, not follower maps
            sortAndReloadMaps()
            return
        }

        let db = Firestore.firestore()
        let query = db.collection("maps").whereField("posterIDs", arrayContains: userProfile?.id ?? "")
        query.getDocuments { (snap, _) in
            guard let snap = snap else { return }
            for doc in snap.documents {
                do {
                    let unwrappedInfo = try doc.data(as: CustomMap.self)
                    guard let mapInfo = unwrappedInfo else { return }
                    /// friend doesn't have access to secret map
                    if mapInfo.secret && !mapInfo.memberIDs.contains(UserDataModel.shared.uid) { continue }
                    if !self.maps.contains(where: { $0.id == mapInfo.id }) { self.maps.append(mapInfo) }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }
            self.mapsFetched = true
            self.sortAndReloadMaps()
        }
    }

    private func sortAndReloadMaps() {
        maps.sort(by: { $0.userTimestamp.seconds > $1.userTimestamp.seconds })
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func getMyMap() -> CustomMap {
        var mapData = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        mapData.createPosts(posts: posts)
        return mapData
    }
}

/// actions
extension ProfileViewController {
    @objc func actionButtonTap() {
        switch relation {
        case .myself:
            presentEditProfile()
        case .friend:
            addRemoveFriendActionSheet()
        case .pending:
            showRemoveFriendRequestAlert()
        case .received:
            acceptFriendRequest()
        case .stranger:
            addFriendFromProfile()
        case .blocked:
            addOptionsActionSheet()
        }
    }

    func addFriendFromProfile() {
        Mixpanel.mainInstance().track(event: "ProfileHeaderAddFriendTap")
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SendFriendRequest"), object: nil, userInfo: ["userID": userProfile?.id ?? ""])
        friendService?.addFriend(receiverID: userProfile?.id ?? "", completion: nil)
        relation = .pending
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func presentEditProfile() {
        Mixpanel.mainInstance().track(event: "ProfileEditProfileTap")
        let editVC = EditProfileViewController(userProfile: UserDataModel.shared.userInfo)
        editVC.modalPresentationStyle = .fullScreen
        editVC.delegate = self
        present(editVC, animated: true)
    }

    func showRemoveFriendRequestAlert() {
        Mixpanel.mainInstance().track(event: "ProfileHeaderRemoveFriendTap")
        let alert = UIAlertController(title: "Remove friend request?", message: "", preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .light
        let removeAction = UIAlertAction(title: "Remove", style: .default) { _ in
            self.revokePendingRequest()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(removeAction)
        let containerVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIViewController()
        containerVC.present(alert, animated: true)
    }

    @objc func friendsListTap() {
        Mixpanel.mainInstance().track(event: "ProfileFriendsListTap")
        guard let container = containerDrawerView else { return }
        let friendListVC = FriendsListController(
            fromVC: self,
            allowsSelection: false,
            showsSearchBar: false,
            friendIDs: userProfile?.friendIDs ?? [],
            friendsList: userProfile?.friendsList ?? [],
            confirmedIDs: [],
            sentFrom: .Profile,
            presentedWithDrawerView: container)
        present(friendListVC, animated: true)
    }

    @objc func elipsesTap() {
        addOptionsActionSheet()
    }

    @objc func backTap() {
        popVC()
    }

    func popVC() {
        containerDrawerView?.closeAction()
    }

    func acceptFriendRequest() {
        self.relation = .friend
        DispatchQueue.main.async { self.collectionView.reloadData() }
        getNotiIDandRespondToRequest(accepted: true)
    }

    func revokePendingRequest() {
        Mixpanel.mainInstance().track(event: "ProfileHeaderRemoveFriendConfirm")
        getNotiIDandRespondToRequest(accepted: false)
        self.relation = .stranger
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func getNotiIDandRespondToRequest(accepted: Bool) {
        guard let userID = userProfile?.id else { return }
        let db = Firestore.firestore()
        /// sender is active user if revoking, receiver is active user if accepting
        let receiver = accepted ? UserDataModel.shared.uid : userID
        let sender = accepted ? userProfile?.id ?? "" : UserDataModel.shared.uid
        let q0 = db.collection("users").document(receiver).collection("notifications").whereField("type", isEqualTo: "friendRequest")
        let query = q0.whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: sender)
        query.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            if let doc = snap?.documents.first {
                if !accepted {
                    Mixpanel.mainInstance().track(event: "ProfileHeaderRemoveFriendConfirm")
                    self.friendService?.revokeFriendRequest(friendID: userID, notificationID: doc.documentID, completion: nil)
                } else {
                    Mixpanel.mainInstance().track(event: "ProfileHeaderAcceptTap")
                    guard let user = self.userProfile else { return }
                    self.friendService?.acceptFriendRequest(friend: user, notificationID: doc.documentID, completion: nil)
                    // tableView reload handled by notification
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil, userInfo: ["notiID": doc.documentID])
                }
            }
        }
    }
}

extension ProfileViewController: EditProfileDelegate {
    func finishPassing(userInfo: UserProfile) {
        self.userProfile = userInfo
        DispatchQueue.main.async { self.collectionView.reloadItems(at: [IndexPath(row: 0, section: 0)]) }
    }

    func logout() {
        DispatchQueue.main.async { self.containerDrawerView?.closeAction() }
    }
}
