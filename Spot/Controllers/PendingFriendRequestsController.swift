//
//  PendingFriendRequestsController.swift
//  Spot
//
//  Created by kbarone on 1/7/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

class PendingFriendRequestsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    lazy var rawRequests: [FriendRequest] = []
    lazy var requests: [(FriendRequest, String)] = []
    lazy var tableView: UITableView = UITableView()
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    let acceptNotificationName = Notification.Name("FriendRequestAccept")
    let deleteNotificationName = Notification.Name("FriendRequestReject")
    unowned var notiVC: NotificationsController!
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Mixpanel.mainInstance().track(event: "PendingFriendsAppear")
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: view.frame.height))
        tableView.contentInset.bottom = 50
        tableView.register(FriendRequestCell.self, forCellReuseIdentifier: "FriendRequestCell")
        tableView.register(PendingHeader.self, forHeaderFooterViewReuseIdentifier: "PendingHeader")
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        rawRequests = rawRequests.sorted(by: {$0.timestamp.seconds > $1.timestamp.seconds})
        
        for request in rawRequests {
         //   if rawRequests.contains(where: {$0.id = request.id})
            if !requests.contains(where: {$0.0.userInfo.id ?? "" == request.userInfo.id ?? ""}) {
                requests.append((request, "pending"))
                self.db.collection("users").document(self.uid).collection("notifications").document(request.notiID).updateData(["seen" : true])
                tableView.reloadData()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAccept(_:)), name: acceptNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyReject(_:)), name: deleteNotificationName, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: acceptNotificationName, object: nil)
        NotificationCenter.default.removeObserver(self, name: deleteNotificationName, object: nil)
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (requests[indexPath.row].1 == "pending") {
            return 140
        } else {
            return 80
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell") as! FriendRequestCell
        
        let currentRequest = requests[indexPath.row].0
        
        cell.setUpAll(request: currentRequest, currentUsername: UserDataModel.shared.userInfo.username)
        
        if (requests[indexPath.row].1 == "pending") {
            cell.setUpPending()
        } else if (requests[indexPath.row].1 == "rejected") {
            cell.setUpRejected()
        } else {
            cell.setUpAccepted()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PendingHeader") as? PendingHeader {
            header.setUp(friendCount: requests.count)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
        
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    // notifications sent form friendRequestCell
    @objc func notifyAccept(_ notification: NSNotification) {
        if let friendID = notification.userInfo?.first?.value as? String {
            if let index = self.requests.firstIndex(where: {$0.0.userInfo.id == friendID}) {
                Mixpanel.mainInstance().track(event: "PendingFriendsAccept")
                self.requests[index].1 = "accepted"
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }
    
    @objc func notifyReject(_ notification: NSNotification) {
        if let friendID = notification.userInfo?.first?.value as? String {
              if let index = self.requests.firstIndex(where: {$0.0.userInfo.id == friendID}) {
                Mixpanel.mainInstance().track(event: "PendingFriendsRemove")
                  self.requests[index].1 = "rejected"
                  DispatchQueue.main.async { self.tableView.reloadData() }
              }
          }
    }
}

class PendingHeader: UITableViewHeaderFooterView {
    var exitButton: UIButton!
    var numRequests: UILabel!
    
    func setUp(friendCount: Int) {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetCell()
        
        numRequests = UILabel(frame: CGRect(x: 30, y: 14, width: UIScreen.main.bounds.width - 60, height: 16))
        var friendText = "\(friendCount) friend requests"
        if friendCount == 1 {friendText = String(friendText.dropLast())}
        numRequests.text = friendText
        numRequests.font = UIFont(name: "SFCompactText-Regular", size: 14)
        numRequests.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        numRequests.textAlignment = .center
        self.addSubview(numRequests)
        
        exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 32, y: 14, width: 20, height: 20))
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        exitButton.addTarget(self, action: #selector(exit(_:)), for: .touchUpInside)
        self.addSubview(exitButton)
    }
        
    override init(reuseIdentifier: String?) {
         super.init(reuseIdentifier: reuseIdentifier)
     }
     
     required init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }
     
    func resetCell() {
         if numRequests != nil { numRequests.text = "" }
         if exitButton != nil { exitButton.setImage(UIImage(), for: .normal) }
     }
     
    @objc func exit(_ sender: UIButton) {
        if let pendingVC = self.viewContainingController() as? PendingFriendRequestsController {
            pendingVC.dismiss(animated: true, completion: nil)
        }
    }
}
