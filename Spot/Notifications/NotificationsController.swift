//
//  NotificationsController.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Firebase

import Foundation
import Mixpanel
import UIKit

protocol NotificationsDelegate: AnyObject {
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification]
    // the following functions will include necessary parameters when ready
    func getProfile(userProfile: UserProfile)
    func deleteFriend(friendID: String)
    func reloadTable()
}

class NotificationsController: UIViewController {
    lazy var notifications: [UserNotification] = []
    lazy var pendingFriendRequests: [UserNotification] = []
    
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot?
    lazy var fetchGroup = DispatchGroup()
    lazy var refresh: RefreshStatus = .activelyRefreshing
    
    lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()
    
    lazy var mapService: MapPostServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.mapPostService)
        return service
    }()
    
    unowned var containerDrawerView: DrawerView?
    private lazy var activityIndicator = CustomActivityIndicator()
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .white
        tableView.allowsSelection = true
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.register(ActivityIndicatorCell.self, forCellReuseIdentifier: "IndicatorCell")
        tableView.isUserInteractionEnabled = true
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = true
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        return tableView
    }()
    
    deinit {
        print("notifications deinit")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRequestAccept(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name(rawValue: "DeletePost"), object: nil)
        setupView()
        fetchNotifications(refresh: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        containerDrawerView?.configure(canDrag: false, swipeDownToDismiss: false, startingPosition: .top)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        navigationController?.navigationBar.isTranslucent = false
    }
    
    func setUpNavBar() {
        title = "Notifications"
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.frame.origin = CGPoint(x: 0.0, y: 47.0)
        navigationItem.backButtonTitle = ""
        navigationController?.navigationBar.barTintColor = UIColor.white
        // Nav bar shouldn't be translucent, however we need it to be here to avoid nav bar jumping. will set it back to false in viewDidAppear
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
    }
    
    func setupView() {
        view.backgroundColor = .white
        
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        guard !notifications.isEmpty else {
            return
        }
        
        Task {
            for i in 0...notifications.count - 1 {
                let notification = notifications[i]
                guard let user = try? await userService?.getUserInfo(userID: notification.senderID) else {
                    return
                }
                
                self.notifications[i].userInfo = user
            }
        }
    }
    
    @objc func notifyFriendRequestAccept(_ notification: NSNotification) {
        if !pendingFriendRequests.isEmpty {
            for i in 0...pendingFriendRequests.count - 1 {
                if let noti = notification.userInfo?["notiID"] as? String {
                    if pendingFriendRequests[safe: i]?.id == noti {
                        var newNoti = pendingFriendRequests.remove(at: i)
                        newNoti.status = "accepted"
                        newNoti.timestamp = Timestamp()
                        notifications.append(newNoti)
                    }
                }
            }
        }
        self.sortAndReload()
    }
    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        notifications.removeAll(where: { $0.postID == post.id })
        if mapDelete {
            notifications.removeAll(where: { $0.mapID == post.mapID })
        }
        DispatchQueue.main.async { self.tableView.reloadData() }
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
        if let i1 = pendingFriendRequests.firstIndex(where: { $0.id == friendRequest.id }) {
            pendingFriendRequests.remove(at: i1)
        }
        return pendingFriendRequests
    }
    
    func reloadTable() {
        self.tableView.reloadData()
    }
}

extension NotificationsController {
    @objc func backTap() {
        Mixpanel.mainInstance().track(event: "NotificationsBackTap")
        containerDrawerView?.closeAction()
    }
    
    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user, presentedDrawerView: containerDrawerView)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }
    
    func openPost(post: MapPost, commentNoti: Bool) {
        let postVC = PostController(parentVC: .Notifications, postsList: [post])
        postVC.containerDrawerView = containerDrawerView
        postVC.openComments = commentNoti
        DispatchQueue.main.async { self.navigationController?.pushViewController(postVC, animated: true) }
    }
    
    func openMap(mapID: String) {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
        navigationController?.pushViewController(customMapVC, animated: true)
    }
}
