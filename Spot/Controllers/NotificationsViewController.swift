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
    var tableData = ["Beach", "Clubs", "Chill", "Dance"]
    
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
    
        let friendReq = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReq.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")
        friendRequestQuery.getDocuments{ [weak self] (snap, err) in
            //check for error (reference video)
            if err != nil  { return }
            //unwrap weak self
            guard let self = self else { return }
            
            for doc in snap!.documents {
                do{
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { return }
                    notification.id = doc.documentID
                    print("😏")
                    self.notifications.append(notification)
                } catch {print(error)}
            }
            
            group.leave()
        }
        
        
        group.enter()
        
        let notiRef = db.collection("users").document(uid).collection("notifications").limit(to: 15)
        var query = notiRef.order(by: "timestamp", descending: true)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument)}
                
        activityListener = query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in
            // check for error
            if err != nil  { return }
            //unwrape weak self
            guard let self = self else { return }
            // check for cached data
            if snap?.metadata.isFromCache ?? false { return }
            // use a for-in loop to cycle through each document
            for doc in snap!.documents {
          // you need to add each notification to the notifications array you created
          // you probably want to do this after fetching the UserProfile for the notification
            // and this notification's PostInfo. You can reference the getMapPost function from old NotificationsController

            // you might want to fetch UserProfile using an closure function ->
            // reference The getUserInfo function in the old NotificationsController as a model
            }
            
            group.leave()
        }
        
        
        group.notify(queue: DispatchQueue.global()) {
            print("---------", self.notifications)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchNotifications()
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
        cell.textLabel?.text = "This is row \(tableData[indexPath.row])"
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    


}
