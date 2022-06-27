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
    
    unowned var mapVC: MapController!
    
    var customView: UIView!
    
    func fetchNotifications() {

        /// fetchGroup is the high-level dispatch for both fetches
        let fetchGroup = DispatchGroup()
        
        let friendReqRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReqRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        
        fetchGroup.enter()
        friendRequestQuery.getDocuments { [weak self] (snap, err) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { print("leave 6"); fetchGroup.leave(); return }
            if allDocs.count == 0 {
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
        let notiQuery = notiRef.order(by: "timestamp", descending: true)
        //if endDocument != nil && !refresh { notiQuery = notiQuery.start(atDocument: endDocument)}
        fetchGroup.enter()
        notiQuery.getDocuments{ [weak self] (snap, err) in
            //unwrap weak self
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }
            if allDocs.count == 0 {
                fetchGroup.leave(); return }
            
            let notiGroup = DispatchGroup()
            for doc in allDocs {
                notiGroup.enter()
                
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { notiGroup.leave(); continue }
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
                print(noti.type, "\n")
            }
            self.tableView.reloadData()
        }
   
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.fetchNotifications()
        }
        
        setupView()

    }
    
    func setupView(){
        
    
        tableView = UITableView(frame: self.view.bounds)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .white
        tableView.rowHeight = 70
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(FriendRequestCollectionCell.self, forCellReuseIdentifier: "FriendRequestCollectionCell")
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        view.addSubview(tableView)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
   
}

// MARK: - UITableViewDataSource
extension NotificationsController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if(pendingFriendRequests.count == 0){
            return 1
        } else {return 2}
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sections = numberOfSections(in: self.tableView)
        var rows = 0
        if(sections < 2){
            if(section == 0){
                rows = notifications.count
            }
        }
        else{
            if(section == 0){
                rows = 1
            }
            else{
                rows = notifications.count
            }
        }
        
        return rows
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        let sections = numberOfSections(in: self.tableView)
        var height = 0.0
        if(sections < 2){
            if(indexPath.section == 0){
                height = UITableView.automaticDimension
            }
        }
        else{
            if(indexPath.section == 0){
                height = UITableView.automaticDimension
            }
            else{
                return 70
            }
        }
        
        return height
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let sections = numberOfSections(in: self.tableView)
        var height = 0.0
        if(sections < 2){
            if(indexPath.section == 0){
                height = UITableView.automaticDimension
            }
        }
        else{
            if(indexPath.section == 0){
                height = UITableView.automaticDimension
            }
            else{
                return 70
            }
        }
        
        return height
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sections = numberOfSections(in: self.tableView)
        if(sections == 1){
            return 0
        }
        return 32
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let sections = numberOfSections(in: self.tableView)
        
        if(sections < 2){
            if(indexPath.section == 0){
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
                let notif = notifications[indexPath.row]
                cell.selectionStyle = .none
                cell.backgroundColor = .white
                cell.set(notification: notif)
                return cell
            }
        }
        else{
            if(indexPath.section == 0){
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
                let notif = pendingFriendRequests[indexPath.row]
                cell.selectionStyle = .none
                cell.backgroundColor = .white
                cell.setUp(notif: notif)
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
        
        return UITableViewCell()
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {

        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = .white
            view.textLabel?.backgroundColor = .clear
            view.textLabel?.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            //add font and size
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        let sections = numberOfSections(in: self.tableView)
        if(sections < 2){
            if(section == 0){
                return "ACTIVITY"
            }
        }
        else{
            if(section == 0){
                return "FRIEND REQUESTS"
            }
            else{
                return "ACTIVITY"
            }
        }
        
        return ""
    
  // table view data source methods
    }
}
