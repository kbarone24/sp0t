//
//  UserDataModel.shared.NotificationsController.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Mixpanel
import UIKit

protocol NotificationsDelegate: AnyObject {
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification]
    func getProfile(userProfile: UserProfile)
    func deleteFriend(friendID: String)
    func reloadTable()
}

class NotificationsController: UIViewController {
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var firstOpen = true

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.allowsSelection = true
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.register(ActivityIndicatorCell.self, forCellReuseIdentifier: "IndicatorCell")
        tableView.isUserInteractionEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = true
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        return tableView
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationsLoaded), name: NSNotification.Name(rawValue: "NotificationsLoad"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setTabBar), name: NSNotification.Name(rawValue: "NotificationsSeenSet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostChanged(_:)), name: NSNotification.Name(rawValue: "PostChanged"), object: nil)

    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        registerForNotifications()

        // Set seen for all visible notifications - all future calls will come from the fetch method
        DispatchQueue.global(qos: .utility).async { UserDataModel.shared.setSeenForDocumentIDs(docIDs: UserDataModel.shared.notifications.map { $0.id ?? "" }) }
        DispatchQueue.main.async { self.resumeActivityAnimation() }
    }
    
    func setUpNavBar() {
        navigationItem.title = "Notifications"
        navigationController?.setUpDarkNav(translucent: true)
    }
    
    func setupView() {
        view.backgroundColor = UIColor(named: "SpotBlack")

        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        view.addSubview(tableView)
        
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    @objc private func notificationsLoaded() {
        print("reload notifications")
        DispatchQueue.main.async { self.tableView.reloadData() }
        setTabBarIcon()
    }

    @objc private func setTabBar() {
        setTabBarIcon()
    }

    @objc private func notifyPostChanged(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        if let i = UserDataModel.shared.notifications.firstIndex(where: { $0.postInfo?.id == post.id }) {
            UserDataModel.shared.notifications[i].postInfo?.likers = post.likers
            UserDataModel.shared.notifications[i].postInfo?.commentList = post.commentList
            UserDataModel.shared.notifications[i].postInfo?.commentCount = post.commentCount
        }
    }

    private func registerForNotifications() {
        if firstOpen {
            UserDataModel.shared.pushManager?.checkNotificationsAuth()
            firstOpen = false
        }
    }

    private func setTabBarIcon() {
        let unseenNoti = UserDataModel.shared.notifications.contains(where: { !$0.seen }) || UserDataModel.shared.pendingFriendRequests.contains(where: { !$0.seen })
        DispatchQueue.main.async {
            let unselectedImage = unseenNoti ? UIImage(named: "NotificationsTabActive") : UIImage(named: "NotificationsTab")
            let selectedImage = unseenNoti ? UIImage(named: "NotificationsTabActiveSelected") : UIImage(named: "NotificationsTabSelected")
            self.navigationController?.tabBarItem = UITabBarItem(
                title: "",
                image: unselectedImage,
                selectedImage: selectedImage
            )
        }
    }

    private func resumeActivityAnimation() {
        // resume frozen activity indicator animation
        if UserDataModel.shared.notifications.isEmpty, let activityCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? ActivityIndicatorCell {
            activityCell.animate()
        }
    }
}

extension NotificationsController: NotificationsDelegate {
    func getProfile(userProfile: UserProfile) {
        openProfile(user: userProfile)
    }
    
    func deleteFriend(friendID: String) {
        guard let friendsService = try? ServiceContainer.shared.service(for: \.friendsService)  else {
            return
        }
        
        friendsService.removeFriend(friendID: friendID)
    }
    
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification] {
        if let i1 = UserDataModel.shared.pendingFriendRequests.firstIndex(where: { $0.id == friendRequest.id }) {
            UserDataModel.shared.pendingFriendRequests.remove(at: i1)
        }
        return UserDataModel.shared.pendingFriendRequests
    }
    
    func reloadTable() {
        self.tableView.reloadData()
    }
}

extension NotificationsController {
    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }
    
    func openPost(post: MapPost, commentNoti: Bool) {
        let vc = GridPostViewController(parentVC: .Notifications, postsList: [post], delegate: nil, title: nil, subtitle: nil)
        vc.openComments = commentNoti
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func openMap(mapID: String) {
        var map = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: "",
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: []
        )
        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [])
        navigationController?.pushViewController(customMapVC, animated: true)
    }
}
