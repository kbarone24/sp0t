//
//  ProfileViewController.swift
//  Spot
//
//  Created by Kenny Barone on 6/6/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFunctions
import FirebaseFirestore
import Mixpanel
import SDWebImage
import SnapKit
import UIKit

final class ProfileViewController: UIViewController {
    // MARK: Fetched datas
    var userProfile: UserProfile? {
        didSet {
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }
    lazy var refreshStatus: RefreshStatus = .refreshEnabled
    var endDocument: DocumentSnapshot?
    lazy var postsList = [MapPost]()
    var relation: ProfileRelation = .myself

    private var pendingFriendRequestNotiID: String? {
        didSet {
            DispatchQueue.main.async { self.collectionView.reloadData() }
        }
    }

    private lazy var imageManager = SDWebImageManager()

    var postsFetched = false {
        didSet {
            toggleNoPosts()
        }
    }

    lazy var titleView = SpotscoreTitleView()

    let itemWidth: CGFloat = UIScreen.main.bounds.width / 2 - 1
    let itemHeight: CGFloat = (UIScreen.main.bounds.width / 2 - 1) * 1.495
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(ProfileHeaderCell.self, forCellWithReuseIdentifier: "ProfileHeaderCell")
        view.register(CustomMapBodyCell.self, forCellWithReuseIdentifier: "BodyCell")
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
    lazy var activityIndicator = UIActivityIndicatorView()
    
    private lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    lazy var mapPostService: MapPostServiceProtocol? = {
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

    init(userProfile: UserProfile? = nil) {
        super.init(nibName: nil, bundle: nil)
        if UserDataModel.shared.userInfo.blockedBy?.contains(userProfile?.id ?? "") ?? false {
            return
        }
        self.userProfile = userProfile == nil ? UserDataModel.shared.userInfo : userProfile
        if userProfile?.id ?? "" != "" && userProfile?.username != "" {
            titleView.score = userProfile?.spotScore ?? 0
        }

        /// need to add immediately to track active user profile getting fetched
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserLoad(_:)), name: NSNotification.Name(("UserProfileLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyUserUpdate(_:)), name: NSNotification.Name(("UserProfileUpdate")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad), name: NSNotification.Name(("FriendsListLoad")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRequestAccept(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name(("NewPost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(("DeletePost")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChanged(_:)), name: NSNotification.Name(rawValue: "PostChanged"), object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if userProfile?.id ?? "" == "" {
            getUserInfo()
        } else {
            getUserRelation()
            viewSetup()
            runFetches()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "ProfileOpen")
        DispatchQueue.main.async { self.resumeActivityAnimation() }
    }

    private func setUpNavBar() {
        navigationController?.setUpDarkNav(translucent: true)

        if relation != .myself {
            let button = UIBarButtonItem(
                image: UIImage(named: "Elipses"),
                style: .plain,
                target: self,
                action: #selector(elipsesTap))
            button.customView?.backgroundColor = .gray
            button.imageInsets = UIEdgeInsets(top: 4, left: 8, bottom: 8, right: 8)
            navigationItem.rightBarButtonItem = button
        }

        navigationItem.titleView = titleView
    }

    private func toggleNoPosts() {
        DispatchQueue.main.async {
            self.noPostLabel.isHidden = self.postsFetched && self.postsList.isEmpty ? false : true
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

            self.titleView.score = user.spotScore ?? 0
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
        if refreshStatus == .refreshEnabled {
            refreshStatus = .activelyRefreshing
            if postsList.isEmpty {
                DispatchQueue.main.async { self.activityIndicator.startAnimating() }
            }
            DispatchQueue.global(qos: .userInitiated).async { self.getPosts() }
        }
    }

    func viewSetup() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        navigationItem.backButtonTitle = ""
        navigationItem.title = ""

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

        activityIndicator.isHidden = true
        collectionView.addSubview(activityIndicator)
        activityIndicator.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        activityIndicator.snp.makeConstraints {
            $0.width.height.equalTo(30)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }
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
        friendService?.addFriend(receiverID: userProfile?.id ?? "", completion: nil)
        relation = .pending
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    func presentEditProfile() {
        Mixpanel.mainInstance().track(event: "ProfileEditProfileTap")
        let editVC = EditProfileViewController(userProfile: UserDataModel.shared.userInfo)
        editVC.delegate = self
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
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
        let containerVC = UIApplication.shared.keyWindow?.rootViewController ?? UIViewController()
        containerVC.present(alert, animated: true)
    }

    @objc func friendsListTap() {
        Mixpanel.mainInstance().track(event: "ProfileFriendsListTap")
        userProfile?.sortFriends()
        let vc = FriendsListController(
            parentVC: .profile,
            allowsSelection: false,
            showsSearchBar: false,
            canAddFriends: relation != .myself,
            friendIDs: userProfile?.friendIDs ?? [],
            friendsList: userProfile?.friendsList ?? [],
            confirmedIDs: [])
        vc.delegate = self
        present(vc, animated: true)
    }

    @objc func elipsesTap() {
        addOptionsActionSheet()
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
                }
            }
        }
    }

    private func resumeActivityAnimation() {
        // resume frozen activity indicator animation
        if postsList.isEmpty && !activityIndicator.isHidden {
            activityIndicator.startAnimating()
        }
    }
}

extension ProfileViewController: EditProfileDelegate {
    func finishPassing(userInfo: UserProfile) {
        self.userProfile = userInfo
        DispatchQueue.main.async { self.collectionView.reloadItems(at: [IndexPath(row: 0, section: 0)]) }
    }
}

extension ProfileViewController: FriendsListDelegate {
    func finishPassing(openProfile: UserProfile) {
        let profileVC = ProfileViewController(userProfile: openProfile)
        self.navigationController?.pushViewController(profileVC, animated: true)
    }

    func finishPassing(selectedUsers: [UserProfile]) {
        return
    }
}
