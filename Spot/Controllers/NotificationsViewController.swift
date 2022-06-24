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

class NotificationsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
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
    
    

    func fetchNotifications(){

        let group = DispatchGroup()
        
        group.enter()
        let friendReqRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReqRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        friendRequestQuery.getDocuments{ [weak self] (snap, err) in
            //unwrap weak self
            guard let self = self else { return }
            guard let allDocs = snap?.documents else {return}
            for doc in allDocs {
                group.enter()
                do{
                    group.enter()
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { return }
                    notification.id = doc.documentID
                    group.leave()
                    //get sender info
                    group.enter()
                    let sender = notification.senderID
                    self.getUserInfo(userID: sender) { user in
                        notification.userInfo = user
                        group.leave()
                    }
                    self.notifications.append(notification)
                } catch {print(error)}
                group.leave()
            }
            group.leave()
        }

        group.enter()
        let notiRef = db.collection("users").document(uid).collection("notifications").limit(to: 15)
        var notiQuery = notiRef.order(by: "timestamp", descending: true)
        //if endDocument != nil && !refresh { notiQuery = notiQuery.start(atDocument: endDocument)}
        notiQuery.getDocuments{ [weak self] (snap, err) in
            //unwrap weak self
            guard let self = self else { return }
            guard let allDocs = snap?.documents else {return}
            for doc in allDocs {
                group.enter()
                do {
                    group.enter()
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { return }
                    notification.id = doc.documentID
                    group.leave()
                    //getting user info
                    group.enter()
                    let sender = notification.senderID
                    self.getUserInfo(userID: sender) { user in
                        notification.userInfo = user
                        group.leave()
                    }
                    if(notification.type != "friendRequest"){
                        group.enter()
                        let post = notification.postID
                        self.getPost(postID: post!) { post in
                            notification.postInfo = post
                            group.leave()
                        }
                        self.notifications.append(notification)
                    }
                } catch {print(error) }
                
                group.leave()
            }
            group.leave()
        }
        
        group.notify(queue: DispatchQueue.main) {
            for noti in self.notifications {
                //print notification type for now, will be .reloadData once UI is implemented
                print(noti.type, "\n")
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.fetchNotifications()
        }
        
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
    
}


