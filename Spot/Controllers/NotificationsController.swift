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
    func getProfile()
    func showPost()
    func reloadTable()
}

class NotificationsController: UIViewController, UITableViewDelegate {
    var notifications: [UserNotification] = []
    var pendingFriendRequests: [UserNotification] = []
    
    var tableView = UITableView()
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var endDocument: DocumentSnapshot!
    
    var refresh: RefreshStatus = .activelyRefreshing
    
    //used if displaying profile as its own drawer view
    private var sheetView: DrawerView? {
        didSet {
            navigationController?.navigationBar.isHidden = sheetView == nil ? false : true
        }
    }
        
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
    
    
    override func viewDidLoad() {
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        
        super.viewDidLoad()
        
        setupView()
        
        self.title = "Notifications"

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
             image: UIImage(named: "BackArrowDark"),
             style: .plain,
             target: self,
             action: #selector(self.leaveNotifs(_:))
         )
    }
    
    func setupView(){
        //for some reason setting up the view like it says in the guidelines was causing issues
        tableView = UITableView(frame: self.view.bounds, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.allowsSelection = true
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.isUserInteractionEnabled = true
        self.tableView.separatorStyle = .none
        view.addSubview(self.tableView)
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
            guard let allDocs = snap?.documents else { print("leave 6"); fetchGroup.leave(); return }
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
                    guard var notification = notif else { print("leave 3"); friendRequestGroup.leave(); continue }
                    notification.id = doc.documentID
                    notification.timeString = self.getTimeString(postTime: notification.timestamp)
                    
                    if !notification.seen {
                      DispatchQueue.main.async { doc.reference.updateData(["seen" : true]) }
                        notification.seen = true
                    }
                                        
                    self.getUserInfo(userID: notification.senderID) { user in
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
        if endDocument != nil && !refresh { notiQuery = notiQuery.start(atDocument: endDocument)}
        fetchGroup.enter()
        notiQuery.getDocuments{ [weak self] (snap, err) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }
            
            if allDocs.count == 0 {
                fetchGroup.leave(); return }
            
            if(allDocs.count < 15){
                self.refresh = .refreshDisabled
            } else {
                self.endDocument = allDocs.last
            }
            
            let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()
            
            let notiGroup = DispatchGroup()
            for doc in docs {
                notiGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { notiGroup.leave(); continue }
                    notification.id = doc.documentID
                    notification.timeString = self.getTimeString(postTime: notification.timestamp)
                    
                    if !notification.seen {
                        doc.reference.updateData(["seen" : true])
                        notification.seen = true
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
            
                    userGroup.notify(queue: .main) {
                        self.notifications.append(notification)
                        notiGroup.leave()
                    }
                } catch { notiGroup.leave() }
            }
            notiGroup.notify(queue: .main) {
                fetchGroup.leave()
            }
        }
                
        fetchGroup.notify(queue: DispatchQueue.main) {
            for noti in self.notifications {
                //to test if notifs were added--will be removed later
                print(noti.type, "\n")
            }
            self.sortAndReload()
        }
    }
    
    func sortAndReload() {
        self.notifications = self.notifications.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.pendingFriendRequests = self.pendingFriendRequests.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        if(self.refresh != .refreshDisabled){ self.refresh = .refreshEnabled }
        //so notfications aren't empty if the user is pendingFriendRequest heavy
        if((pendingFriendRequests.count == 0 && notifications.count < 7) || (pendingFriendRequests.count > 0 && notifications.count < 11)){
            fetchNotifications(refresh: false)
        }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    

    @objc func leaveNotifs(_ sender: Any){
        ///NOT WORKING 😥
        navigationController?.popViewController(animated: true)
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
            print("👻 reached end")
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
        tableView.deselectRow(at: indexPath, animated: true)
        let userinfo = indexPath.row
        //insert code to display post
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if pendingFriendRequests.count == 0 || notifications.count == 0 {
            return 1
        } else { return 2 }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if pendingFriendRequests.count == 0 {
            return notifications.count
        } else if notifications.count == 0{
            return 1
        } else{
            if(section == 0){
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
        if pendingFriendRequests.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
            let notif = notifications[indexPath.row]
            cell.notificationControllerDelegate = self
            cell.selectionStyle = .default
            if notif.type == "friendRequest" && notif.status == "accepted" && notif.seen == false {
                cell.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.2)
            } else if notif.type == "mapInvite" && notif.seen == false {
                cell.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.2)
            } else { cell.backgroundColor = .white }
            cell.set(notification: notif)
            return cell
        } else if notifications.count == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
            let notifs = pendingFriendRequests
            cell.notificationControllerDelegate = self
            cell.selectionStyle = .none
            cell.backgroundColor = .white
            cell.setUp(notifs: notifs)
            return cell
        } else{
            if indexPath.section == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
                let notifs = pendingFriendRequests
                cell.notificationControllerDelegate = self
                cell.selectionStyle = .none
                cell.backgroundColor = .white
                cell.setUp(notifs: notifs)
                return cell
            } else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
                let notif = notifications[indexPath.row]
                cell.notificationControllerDelegate = self
                cell.selectionStyle = .default
                if notif.type == "friendRequest" && notif.status == "accepted" && notif.seen == false {
                    cell.backgroundColor = UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.2)
                } else { cell.backgroundColor = .white }
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

    func getProfile() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    func showPost(){
        print("show posts using this function")
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

