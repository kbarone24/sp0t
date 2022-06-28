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
import MapKit

struct UserNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var seen: Bool
    var senderID: String
    var timestamp: Timestamp
    var type: String
    var userInfo: UserProfile?
    var postInfo: MapPost? /// only for activity notifications
    var commentID: String?
    var imageURL: String?
    var originalPoster: String?
    var postID: String?
    var senderUsername: String?
    var status: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case seen
        case senderID
        case type
        case timestamp
        case userInfo
        case postInfo
        case commentID
        case imageURL
        case originalPoster
        case postID
        case senderUsername
        case status
    }
}

class NotificationsController: UIViewController {
    
    var notifications: [UserNotification] = []
    var tableView = UITableView()
    var dummyTableData = ["1", "2", "3", "4"]
    
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
            guard let allDocs = snap?.documents else { fetchGroup.leave(); return }
            if allDocs.count == 0 { fetchGroup.leave(); return }
            
            let friendRequestGroup = DispatchGroup()
            for doc in allDocs {
                /// friendRequestGroup is the dispatch for pending friend requests fetch
                friendRequestGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { friendRequestGroup.leave(); continue }
                    notification.id = doc.documentID
                    
                    self.getUserInfo(userID: notification.senderID) { user in
                        notification.userInfo = user
                        self.notifications.append(notification)
                        friendRequestGroup.leave()
                    }
                } catch { friendRequestGroup.leave() }
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
            if allDocs.count == 0 { fetchGroup.leave(); return }
            
            let notiGroup = DispatchGroup()
            for doc in allDocs {
                notiGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { notiGroup.leave(); continue }
                    if notification.status == "pending" { notiGroup.leave(); continue }
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
                //print notification type for now, will be .reloadData once UI is implemented
                print(noti.type, "\n")
            }
        }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async { self.fetchNotifications() }
/*
        tableView = UITableView(frame: self.view.bounds, style: UITableView.Style.plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor.white
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "my")
        view.addSubview(tableView)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "my", for: indexPath)
        cell.textLabel?.text = "This is row \(dummyTableData[indexPath.row])"
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dummyTableData.count
    }
    */
    }
}
