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

class NotificationsController: UIViewController, UITableViewDelegate {
    var notifications: [UserNotification] = []
    var pendingFriendRequests: [UserNotification] = []
    var tableView = UITableView()
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    var friendRequestListener: ListenerRegistration!
    var activityListener: ListenerRegistration!
    var endDocument: DocumentSnapshot!
    
    var refresh: RefreshStatus = .activelyRefreshing
    
    unowned var mapVC: MapController!
    
    var customView: UIView!
    
    func fetchNotifications(refresh: Bool) {
        print("🏃🏽‍♀️ fetching")
        /// fetchGroup is the high-level dispatch for both fetches
        let fetchGroup = DispatchGroup()
        
        let friendReqRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReqRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        
        fetchGroup.enter()
        friendRequestQuery.getDocuments { [weak self] (snap, err) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { print("leave 6"); fetchGroup.leave(); return }
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
                print("✔︎ FRIEND REQUESTS: ", self.pendingFriendRequests.count, "\n")
                fetchGroup.leave()
            }
        }

        let notiRef = db.collection("users").document(uid).collection("notifications").limit(to: 3)
        var notiQuery = notiRef.order(by: "timestamp", descending: true)
        if endDocument != nil && !refresh { notiQuery = notiQuery.start(atDocument: endDocument)}
        fetchGroup.enter()
        notiQuery.getDocuments{ [weak self] (snap, err) in
            //unwrap weak self
            guard let self = self else { return }

            guard let allDocs = snap?.documents else { return }
            
            if allDocs.count == 0 {
                fetchGroup.leave(); return }
            
            if(allDocs.count < 3){
                print("🤥 we NAUUUURRRRR -------------------------")
                self.refresh = .refreshDisabled
            } else {
                print("🤥 we GOOOOOOD -------------------------")
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
                    
                    /// enter user group to ensure that both getUserInfo and getPost have both returned before appending the new notification
                    let userGroup = DispatchGroup()
                    
                    if notification.status == "pending" {
                        notiGroup.leave(); continue }
                    
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
                        self.notifications.append(notification)
                        self.notifications.append(notification)
                        self.notifications.append(notification)
                        self.notifications.append(notification)
                        self.notifications.append(notification)
                        self.notifications.append(notification)
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
                //print notification type for now, will be .reloadData once UI is implemented
                print(noti.type, "\n AAAA")
            }
            
            self.sortAndReload()

        }
   
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.fetchNotifications(refresh: false)
        }
        
        self.title = "Notifications"
        
        setupView()
    }
    
    func sortAndReload() {
        self.notifications = self.notifications.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.pendingFriendRequests = self.pendingFriendRequests.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.refresh = .refreshEnabled
        self.tableView.reloadData()
        
    }
    
    func setupView(){
                
        navigationController!.navigationBar.barTintColor = UIColor.white
        navigationController!.navigationBar.isTranslucent = true
        navigationController!.navigationBar.barStyle = .black
        navigationController!.navigationBar.tintColor = UIColor.black

        
        navigationController!.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            .font: UIFont(name: "SFCompactText-Heavy", size: 20)!
        ]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: "BackArrowDark"),
            style: .plain,
            target: self,
            action: #selector(leave)
        )
        
        /*tableView = UITableView{
            $0.frame = self.view.bounds
            $0.dataSource = self
            $0.delegate = self
            $0.backgroundColor = .white
            $0.rowHeight = 70
            $0.style = .grouped
            $0.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
            $0.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
            $0.separatorStyle = UITableViewCell.SeparatorStyle.none
            view.addSubview($0)
            
        }*/
        
        tableView = UITableView(frame: self.view.bounds, style: .grouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        view.addSubview(tableView)
         
        
    }
    
    @objc func leave(_ sender: Any){
        print("idk yet")
    }
    
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
        //scrollview reloads data when user nears bottom of screen
        print(" ➡️ scrollViewDidScroll")
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 100)) && refresh == .refreshEnabled {
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
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if(pendingFriendRequests.count == 0 || notifications.count == 0 ){
            return 1
        } else {return 2}
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if(pendingFriendRequests.count == 0){
            return notifications.count
        }
        else if (notifications.count == 0){
            return 1
        }
        else{
            if(section == 0){
                return 1
            }
            else{
                return notifications.count
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        
        if(pendingFriendRequests.count == 0){
            return 70
        }
        else if (notifications.count == 0){
            return UITableView.automaticDimension
        }
        else{
            if(indexPath.section == 0){
                return UITableView.automaticDimension
            }
            else{
                return 70
            }
        }
        
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        if(pendingFriendRequests.count == 0){
            return 70
        }
        else if (notifications.count == 0){
            return UITableView.automaticDimension
        }
        else{
            if(indexPath.section == 0){
                return UITableView.automaticDimension
            }
            else{
                return 70
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if(pendingFriendRequests.count == 0){
            return 0
        }
        return 32
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if(pendingFriendRequests.count == 0){
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
            let notif = notifications[indexPath.row]
            cell.selectionStyle = .none
            cell.backgroundColor = .white
            cell.set(notification: notif)
            return cell
        }
        else if (notifications.count == 0){
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
            let notifs = pendingFriendRequests
            cell.selectionStyle = .none
            cell.backgroundColor = .white
            cell.setUp(notifs: notifs)
            return cell
        }
        else{
            if(indexPath.section == 0){
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
                let notifs = pendingFriendRequests
                cell.selectionStyle = .none
                cell.backgroundColor = .white
                cell.setUp(notifs: notifs)
                return cell
            }
            else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
                let notif = notifications[indexPath.row]
                cell.selectionStyle = .none
                cell.backgroundColor = .white
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
        
        if(pendingFriendRequests.count == 0){
            return "ACTIVITY"
        }
        else if (notifications.count == 0){
            return "FRIEND REQUESTS"
        }
        else{
            if(section == 0){
                return "FRIEND REQUESTS"
            }
            else{
                return "ACTIVITY"
            }
        }
    
  // table view data source methods
    }
}
