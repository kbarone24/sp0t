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

    var collectionView: UICollectionView!
    private var noPostLabel: UILabel!

    // MARK: Fetched datas
    public var userProfile: UserProfile? {
        didSet {
            if collectionView != nil { DispatchQueue.main.async { self.collectionView.reloadData() } }
        }
    }
    public lazy var maps = [CustomMap]()
    private lazy var posts = [MapPost]()
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
            noPostLabel.isHidden = mapsFetched && (maps.isEmpty && posts.isEmpty) ? false : true
            DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
        }
    }
    var mapsFetched = false {
        didSet {
            noPostLabel.isHidden = postsFetched && (maps.isEmpty && posts.isEmpty) ? false : true
            DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
        }
    }

    lazy var activityIndicator = CustomActivityIndicator()

    deinit {
        print("ProfileViewController(\(self) deinit")
        NotificationCenter.default.removeObserver(self)
    }

    init(userProfile: UserProfile? = nil, presentedDrawerView: DrawerView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        containerDrawerView = presentedDrawerView

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
        if userProfile!.id ?? "" == "" { getUserInfo(); return }
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
            action: #selector(popVC)
        )
    }

    private func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        containerDrawerView?.showCloseButton = false
        containerDrawerView?.present(to: .Top)
    }

    private func getUserInfo() {
        guard let username = userProfile?.username else { return }
        /// username passed through for tagged user not in friends list
        getUserFromUsername(username: username) { [weak self] user in
            guard let self = self else { return }
            self.userProfile = user
            self.getUserRelation()
            self.viewSetup()
            self.runFetches()
        }
    }

    private func getUserRelation() {
        if self.userProfile?.id == UserDataModel.shared.uid {
            relation = .myself
        } else if UserDataModel.shared.userInfo.friendsList.contains(where: { user in
            user.id == userProfile?.id
        }) {
            relation = .friend
        } else if UserDataModel.shared.userInfo.pendingFriendRequests.contains(where: { user in
            user == userProfile?.id
        }) {
            relation = .pending
        } else if ((self.userProfile?.pendingFriendRequests.contains(where: { user in
            user == UserDataModel.shared.uid
        })) != nil) {
            relation = .received
        } else {
            relation = .stranger
        }
    }

    private func runFetches() {
        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMaps()
            self.getNinePosts()
        }
    }

    private func viewSetup() {
        view.backgroundColor = .white
        // inputViewController?.edgesForExtendedLayout = .none
        self.title = ""
        navigationItem.backButtonTitle = ""

        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)

        collectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.delegate = self
            view.dataSource = self
            view.backgroundColor = .clear
            view.register(ProfileHeaderCell.self, forCellWithReuseIdentifier: "ProfileHeaderCell")
            view.register(ProfileMyMapCell.self, forCellWithReuseIdentifier: "ProfileMyMapCell")
            view.register(ProfileBodyCell.self, forCellWithReuseIdentifier: "ProfileBodyCell")
            return view
        }()
        view.addSubview(collectionView)

        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        noPostLabel = UILabel {
            $0.text = "\(userProfile!.username) hasn't posted yet"
            $0.textColor = UIColor(red: 0.613, green: 0.613, blue: 0.613, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
            $0.isHidden = true
            view.addSubview($0)
        }
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
            $0.centerX.equalToSuperview().offset(-100)
        }
    }

    private func getNinePosts() {
        let db = Firestore.firestore()
        let query = db.collection("posts").whereField("posterID", isEqualTo: userProfile!.id!).whereField("friendsList", arrayContains: UserDataModel.shared.uid).order(by: "timestamp", descending: true).limit(to: 9)
        query.getDocuments { (snap, _) in
            guard let snap = snap else { return }
            let dispatch = DispatchGroup()
            if snap.documents.count == 0 && (self.relation == .friend || self.relation == .myself) { self.postsFetched = true }
            for doc in snap.documents {
                do {
                    let unwrappedInfo = try doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if UserDataModel.shared.deletedPostIDs.contains(postInfo.id!) { continue }
                    dispatch.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
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

    private func getMaps() {
        if relation == .myself {
            mapsFetched = true
            maps = UserDataModel.shared.userInfo.mapsList.filter({ $0.posterIDs.contains(UserDataModel.shared.uid) }) /// only show maps user is member of, not follower maps
            sortAndReloadMaps()
            return
        }

        let db = Firestore.firestore()
        let query = db.collection("maps").whereField("posterIDs", arrayContains: userProfile?.id ?? "")
        query.getDocuments { (snap, err) in
            if err != nil { return }
            for doc in snap!.documents {
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

    private func getMyMap() -> CustomMap {
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
            addActionSheet()
        case .pending:
            showRemoveFriendRequestAlert()
        case .received:
            acceptFriendRequest()
        case .stranger:
            addFriendFromProfile()
        }
    }

    func addFriendFromProfile() {
        Mixpanel.mainInstance().track(event: "ProfileHeaderAddFriendTap")
        addFriend(senderProfile: UserDataModel.shared.userInfo, receiverID: userProfile?.id ?? "")
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
        let removeAction = UIAlertAction(title: "Remove", style: .default) { action in
            self.revokePendingRequest()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(removeAction)
        let containerVC = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController ?? UIViewController()
        containerVC.present(alert, animated: true)
    }
    
    @objc func friendsListTap() {
        Mixpanel.mainInstance().track(event: "ProfileFriendsListTap")
        let friendListVC = FriendsListController(fromVC: self, allowsSelection: false, showsSearchBar: false, friendIDs: userProfile!.friendIDs, friendsList: userProfile!.friendsList, confirmedIDs: [], sentFrom: .Profile, presentedWithDrawerView: containerDrawerView!)
        present(friendListVC, animated: true)
    }
    
    @objc func popVC() {
        if navigationController?.viewControllers.count == 1 {
            containerDrawerView?.closeAction()
        } else {
            navigationController?.popViewController(animated: true)
        }
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
        let db = Firestore.firestore()
        /// sender is active user if revoking, receiver is active user if accepting
        let receiver = accepted ? UserDataModel.shared.uid : userProfile!.id!
        let sender = accepted ? userProfile!.id! : UserDataModel.shared.uid
        let query = db.collection("users").document(receiver).collection("notifications").whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").whereField("senderID", isEqualTo: sender)
        query.getDocuments { (snap, err) in
            if let doc = snap?.documents.first {
                if !accepted {
                    Mixpanel.mainInstance().track(event: "ProfileHeaderRemoveFriendConfirm")
                    self.revokeFriendRequest(friendID: self.userProfile!.id!, notificationID: doc.documentID)
                } else {
                    Mixpanel.mainInstance().track(event: "ProfileHeaderAcceptTap")
                    self.acceptFriendRequest(friend: self.userProfile!, notificationID: doc.documentID)
                    /// tableView reload handled by notification
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

/// notifications
extension ProfileViewController {
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        guard let spotRemove = notification.userInfo?["spotRemove"] as? Bool else { return }

        if posts.contains(where: { $0.id == post.id }) {
            posts.removeAll()
            DispatchQueue.main.async { self.collectionView.reloadData() }
            DispatchQueue.global().async { self.getNinePosts() }
        }
        if mapDelete {
            maps.removeAll(where: { $0.id == post.mapID ?? "" })
            DispatchQueue.main.async { self.collectionView.reloadData() }

        } else if post.mapID ?? "" != "" {
            if let i = maps.firstIndex(where: { $0.id == post.mapID! }) {
                maps[i].removePost(postID: post.id!, spotID: spotDelete || spotRemove ? post.spotID! : "")
            }
        }
    }

    @objc func notifyMapChange(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        let mapID = userInfo["mapID"] as! String
        let likers = userInfo["mapLikers"] as! [String]
        if let i = maps.firstIndex(where: { $0.id == mapID }) {
            /// remove if this user
            if !likers.contains(userProfile!.id!) {
                DispatchQueue.main.async {
                    self.maps.remove(at: i)
                    self.collectionView.reloadData()
                }
            } else {
                /// update likers if current user liked map through another users mapsList
                self.maps[i].likers = likers
            }
        } else {
            if likers.contains(self.userProfile!.id!) {
                getMaps()
            }
        }
    }

    @objc func notifyUserLoad(_ notification: NSNotification) {
        if userProfile?.username ?? "" != "" { return }
        userProfile = UserDataModel.shared.userInfo
        getUserRelation()
        viewSetup()
        runFetches()
    }

    @objc func notifyFriendsLoad() {
        // update active user friends list when all friends load on userListener fetch
        guard let userID = userProfile?.id as? String else { return }
        if userID == UserDataModel.shared.uid {
            userProfile!.friendsList = UserDataModel.shared.userInfo.friendsList
        }
    }

    @objc func notifyMapsLoad(_ notification: NSNotification) {
        getMaps()
    }

    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if let i = maps.firstIndex(where: { $0.id == map.id }) {
            maps[i].memberIDs = map.memberIDs
            maps[i].likers = map.likers
            maps[i].memberProfiles = map.memberProfiles
            maps[i].imageURL = map.imageURL
            maps[i].mapName = map.mapName
            maps[i].mapDescription = map.mapDescription
            maps[i].secret = map.secret
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }

    @objc func notifyFriendRequestAccept(_ notification: NSNotification) {
        relation = .friend
        userProfile?.friendIDs.append(UserDataModel.shared.uid)
        userProfile?.friendsList.append(UserDataModel.shared.userInfo)
        userProfile?.topFriends?[UserDataModel.shared.uid] = 0
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.activityIndicator.startAnimating()
        }
        
        /// run get nine posts now that friendslist field has started to be updated
        DispatchQueue.global().async {
            self.getNinePosts()
        }
    }
}

extension ProfileViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : noPostLabel?.isHidden ?? false && (!maps.isEmpty || !posts.isEmpty) ? maps.count + 1 : 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
        if let headerCell = cell as? ProfileHeaderCell {
            headerCell.cellSetup(userProfile: userProfile!, relation: relation)
            headerCell.actionButton.addTarget(self, action: #selector(actionButtonTap), for: .touchUpInside)
            headerCell.friendListButton.addTarget(self, action: #selector(friendsListTap), for: .touchUpInside)
            return headerCell
        } else if let mapCell = cell as? ProfileMyMapCell {
            mapCell.cellSetup(userAccount: userProfile!.username, posts: posts, relation: relation)
            return mapCell
        } else if let bodyCell = cell as? ProfileBodyCell {
            bodyCell.cellSetup(mapData: maps[indexPath.row - 1], userID: userProfile!.id!)
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return section == 0 ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 40) / 2
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 160) : CGSize(width: width, height: 230)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "ProfileMapSelect")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (_) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
            if let _ = cell as? ProfileMyMapCell {
                guard relation == .friend || relation == .myself else { return }
                let mapData = getMyMap()
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: mapData, postsList: [], presentedDrawerView: containerDrawerView, mapType: .myMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            } else if let _ = cell as? ProfileBodyCell {
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: maps[indexPath.row - 1], postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            }
        }
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

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Show navigation bar when user scroll pass the header section
        if scrollView.contentOffset.y > -91.0 {
            navigationController?.navigationBar.isTranslucent = false
            if scrollView.contentOffset.y > 0 {
                self.title = userProfile?.name
            } else { self.title = ""}
        }
    }
}
