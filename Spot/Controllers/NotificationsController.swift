//
//  NotificationsController.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseMessaging
import Geofirestore

protocol notificationDelegateProtocol: AnyObject{
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification]
    //the following functions will include necessary parameters when ready
    func getProfile(userProfile: UserProfile)
    func showPost()
    func deleteFriend(friendID: String)
    func reloadTable()
}

class NotificationsController: UIViewController, UITableViewDelegate {
    var activityIndicator: CustomActivityIndicator!
    
    var notifications: [UserNotification] = []
    var pendingFriendRequests: [UserNotification] = []
    
    var tableView = UITableView()
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot!
    
    var refresh: RefreshStatus = .activelyRefreshing
    var containerDrawerView: DrawerView?
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName: String?, bundle: Bundle?){
        super.init(nibName: nibName, bundle: bundle)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.fetchNotifications(refresh: false)
        }
    }
    
    deinit {
        print("notifications deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendRequestAccept(_:)), name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil)
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        configureDrawerView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //navigationController?.navigationBar.isTranslucent = false
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        setUpNavBar()

    }
    
    func configureDrawerView() {
        containerDrawerView?.canInteract = false
        containerDrawerView?.swipeDownToDismiss = false
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .Top) }
    }
    
    func setUpNavBar() {
        self.title = "Notifications"
        navigationItem.backButtonTitle = ""

        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = false
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black
        navigationController?.view.backgroundColor = .white

        navigationController!.navigationBar.titleTextAttributes = [
                .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
                .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
               
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrow-1"),
            style: .plain,
            target: self,
            action: #selector(leaveNotifs)
        )
        
    }
    
    
    func setupView(){
        //for some reason setting up the view like it says in the guidelines was causing issues
        //tableView = UITableView(frame: (self.view.bounds), style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.allowsSelection = true
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.register(ActivityIndicatorCell.self, forCellReuseIdentifier: "IndicatorCell")
        tableView.isUserInteractionEnabled = true
        self.tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = true
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        view.addSubview(self.tableView)
        
        tableView.snp.makeConstraints{
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
        
    }
    
    
    // MARK: Notification fetch
    func fetchNotifications(refresh: Bool) {
        /// fetchGroup is the high-level dispatch for both fetches
        let fetchGroup = DispatchGroup()
        
        let friendReqRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReqRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        
        fetchGroup.enter()
        friendRequestQuery.getDocuments { [weak self] (snap, err) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else {fetchGroup.leave(); return }
            // checking if all pending friend requests have been queried
            if allDocs.count == 0 || allDocs.count == self.pendingFriendRequests.count {
                fetchGroup.leave();
                return
            }
            
            let friendRequestGroup = DispatchGroup()
            for doc in allDocs {
                /// friendRequestGroup is the dispatch for pending friend requests fetch
                friendRequestGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { friendRequestGroup.leave(); continue }
                    notification.id = doc.documentID
                                        
                    if !notification.seen {
                      DispatchQueue.main.async { doc.reference.updateData(["seen" : true]) }
                    }
                                 

                    self.getUserInfo(userID: notification.senderID) { [weak self] (user) in
                        guard let self = self else { return }
                        notification.userInfo = user
                        self.pendingFriendRequests.append(notification)
                        friendRequestGroup.leave()
                    }
                    
                } catch {
                    friendRequestGroup.leave() }
            }
            /// leave friend request group once all friend requests are appended
            friendRequestGroup.notify(queue: .main) {
                fetchGroup.leave()
            }
        }

        let notiRef = db.collection("users").document(uid).collection("notifications").limit(to: 15)
        var notiQuery = notiRef.order(by: "timestamp", descending: true)
        
        if endDocument != nil && !refresh {
            notiQuery = notiQuery.start(atDocument: endDocument)
        }
        
        fetchGroup.enter()
        notiQuery.getDocuments{ [weak self] (snap, err) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }
                        
            if allDocs.count == 0{
                fetchGroup.leave(); return }
            
            if(allDocs.count < 15){
                self.refresh = .refreshDisabled
            }
           
            self.endDocument = allDocs.last
                
            
            let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()
            
            
            let notiGroup = DispatchGroup()
            for doc in docs {
                notiGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { notiGroup.leave(); continue }
                    notification.id = doc.documentID
                    
                    if !notification.seen {
                      DispatchQueue.main.async { doc.reference.updateData(["seen" : true]) }
                    }
                    
                    if notification.status == "pending" {
                        notiGroup.leave(); continue }
                    
                    /// enter user group to ensure that both getUserInfo and getPost have both returned before appending the new notification
                    let userGroup = DispatchGroup()
                    
                    userGroup.enter()
                    self.getUserInfo(userID: notification.senderID) { user in
                        notification.userInfo = user
                        userGroup.leave()
                    }
                    
                    if (notification.type != "friendRequest") {
                        userGroup.enter()
                        let post = notification.postID
                        self.getPost(postID: post!) { post in
                            notification.postInfo = post
                            userGroup.leave()
                        }
                    }
            
                    userGroup.notify(queue: .main) { [weak self] in
                        guard let self = self else { return }
                        self.notifications.append(notification)
                        notiGroup.leave()
                    }
                } catch { notiGroup.leave() }
            }
            notiGroup.notify(queue: .main) {
                fetchGroup.leave()
            }
        }
                
        fetchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            self.sortAndReload()
        }
    }
    
    func sortAndReload() {
        self.notifications = self.notifications.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.pendingFriendRequests = self.pendingFriendRequests.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        //so notfications aren't empty if the user is pendingFriendRequest heavy
        ///REVISIT THISSS
        if((pendingFriendRequests.count == 0 && notifications.count < 11) || (pendingFriendRequests.count > 0 && notifications.count < 7)) && refresh == .refreshEnabled{
            fetchNotifications(refresh: false)
        }
        if(self.refresh != .refreshDisabled){ self.refresh = .refreshEnabled }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    @objc func notifyFriendsLoad(_ notification: NSNotification){
        if(notifications.count != 0){
            for i in 0...notifications.count-1{
                self.getUserInfo(userID: self.notifications[i].senderID) { [weak self] (user) in
                guard let self = self else { return }
                self.notifications[i].userInfo = user
                }
            }
        }
    }
    
    @objc func notifyFriendRequestAccept(_ notification: NSNotification){
        if(pendingFriendRequests.count != 0){
            for i in 0...pendingFriendRequests.count-1{
                if let noti = notification.userInfo?["notiID"] as? String {
                    if(pendingFriendRequests[i].id == noti){
                    var newNotif = pendingFriendRequests.remove(at: i)
                        newNotif.status = "accepted"
                        notifications.append(newNotif)
                    }
                }
            }
        }
        self.sortAndReload()
    }
    
    @objc func leaveNotifs() {
        if navigationController?.viewControllers.count == 1 {
            containerDrawerView?.closeAction()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    ///modified copy from global functions
    func getTimeString(postTime: Firebase.Timestamp) -> String {
        let seconds = postTime.seconds
        let current = NSDate().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds
        
            if (timeSincePost <= 86400) {
                if (timeSincePost <= 3600) {
                    if (timeSincePost <= 60) {
                        return "\(timeSincePost)s"
                    } else {
                        let minutes = timeSincePost / 60
                        return "\(minutes)m"
                    }
                } else {
                    let hours = timeSincePost / 3600
                    return "\(hours)h"
                }
            } else {
                let days = timeSincePost / 86400
                return "\(days)d"
            }
    }
        
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //tries to query more data when the user is about 5 cells from hitting the end
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 350)) && refresh == .refreshEnabled {
            fetchNotifications(refresh: false)
            refresh = .activelyRefreshing
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - UITableViewDataSource
extension NotificationsController: UITableViewDataSource {
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) is ActivityCell {
            if let post = notifications[indexPath.row].postInfo {
                let comment = notifications[indexPath.row].type.contains("comment")
                openPost(post: post, commentNoti: comment)
            } else if let user = notifications[indexPath.row].userInfo {
                openProfile(user: user)
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if pendingFriendRequests.count == 0 || notifications.count == 0 {
            return 1
        } else {
            if(refresh == .activelyRefreshing){ return 1 }
            else {return 2}
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if refresh == .activelyRefreshing{
            return notifications.count + 1
        }
        if pendingFriendRequests.count == 0 {
            return notifications.count
        } else if notifications.count == 0{
            return 1
        } else{
            if (section == 0) {
                return 1
            } else {
                return notifications.count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        if pendingFriendRequests.count == 0 {
            return 70
        } else if notifications.count == 0 {
            return UITableView.automaticDimension
        } else {
            if indexPath.section == 0 {
                return UITableView.automaticDimension
            } else {
                return 70
            }
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if pendingFriendRequests.count == 0 {
            return 70
        } else if notifications.count == 0 {
            return UITableView.automaticDimension
        } else{
            if indexPath.section == 0 {
                return UITableView.automaticDimension
            } else{
                return 70
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if pendingFriendRequests.count == 0 { return 0 }
        return 32
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {        
        let amtFriendReq = pendingFriendRequests.isEmpty ? 0 : 1
        if indexPath.row >= notifications.count + amtFriendReq {
            let cell = tableView.dequeueReusableCell(withIdentifier: "IndicatorCell", for: indexPath) as! ActivityIndicatorCell
            cell.setUp()
            return cell
        }
        if pendingFriendRequests.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
            let notif = notifications[indexPath.row]
            cell.notificationControllerDelegate = self
            cell.set(notification: notif)
            return cell
        } else if notifications.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
            let notifs = pendingFriendRequests
            cell.notificationControllerDelegate = self
            cell.setUp(notifs: notifs)
            return cell
        } else{
            if indexPath.section == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
                let notifs = pendingFriendRequests
                cell.notificationControllerDelegate = self

                cell.setUp(notifs: notifs)
                return cell
            } else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
                let notif = notifications[indexPath.row]
                cell.notificationControllerDelegate = self
                cell.set(notification: notif)
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = .white
            view.textLabel?.backgroundColor = .clear
            view.textLabel?.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.textLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if pendingFriendRequests.count == 0 {
            return "ACTIVITY"
        } else if notifications.count == 0 {
            return "FRIEND REQUESTS"
        } else{
            if(section == 0){
                return "FRIEND REQUESTS"
            } else{
                return "ACTIVITY"
            }
        }
    }
    
}

// MARK: - notificationDelegateProtocol
extension NotificationsController: notificationDelegateProtocol {

    func getProfile(userProfile: UserProfile) {
        openProfile(user: userProfile)
    }
    
    func showPost() {
        print("show posts using this function")
    }
    
    func deleteFriend(friendID: String){
        self.removeFriend(friendID: friendID)
    }
    
    func deleteFriendRequest(friendRequest: UserNotification) -> [UserNotification] {
        guard let i1 = pendingFriendRequests.firstIndex(where: {$0.id == friendRequest.id}) else {
            print("friend Request not found");
            return []}
        pendingFriendRequests.remove(at: i1)
        return pendingFriendRequests
    }
    
    func reloadTable(){
        self.tableView.reloadData()
    }
}

extension NotificationsController {
    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user, presentedDrawerView: containerDrawerView)
        DispatchQueue.main.async { self.navigationController!.pushViewController(profileVC, animated: true) }
    }
    
    func openPost(post: MapPost, commentNoti: Bool) {
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = [post]
        postVC.containerDrawerView = containerDrawerView
        postVC.openComments = commentNoti
        DispatchQueue.main.async { self.navigationController!.pushViewController(postVC, animated: true) }
    }
}

class ActivityIndicatorCell: UITableViewCell {
    
    lazy var activityIndicator: CustomActivityIndicator = CustomActivityIndicator(frame: CGRect.zero)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp() {
        activityIndicator.removeFromSuperview()
        activityIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30)/2), y: 35, width: 30, height: 30)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = true
        contentView.addSubview(activityIndicator)
    }
}
