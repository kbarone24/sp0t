//
//  NotificationsViewController.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreLocation
import Mixpanel
import FirebaseUI


class NotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var activityIndicator: CustomActivityIndicator!
    var tableView: UITableView!
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    
    lazy var friendRequests: [FriendRequest] = []
    lazy var postNotifications: [PostNotification] = []
    lazy var spotNotifications: [SpotNotification] = []
    lazy var notificationList: [(senderID: String, type: String, superType: Int, timestamp: Firebase.Timestamp, notiID: String)] = [] /// supertypes: 0 = friend request, 1 = post, 2 = spot
    lazy var friendRequestsPending: [FriendRequest] = []
    lazy var removedRequestList: [String] = []

    let acceptNotificationName = Notification.Name("FriendRequestAccept")
    let deleteNotificationName = Notification.Name("FriendRequestReject")
    
    var listener1, listener2, listener3, listener4, listener5: ListenerRegistration!
    var endDocument: DocumentSnapshot!
    
    unowned var mapVC: MapViewController!
    
    var refresh: refreshStatus = .refreshing
    
    lazy var sentFromPending = false
    lazy var active = false
    lazy var friendsEmpty = false
    lazy var addedNewNoti = false
    
    enum refreshStatus {
        case yesRefresh
        case refreshing
        case noRefresh
    }
    
    //finish passing method reloads data if friend request action was taken in profile
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAccept(_:)), name: acceptNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyReject(_:)), name: deleteNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFriendsLoad(_:)), name: NSNotification.Name("FriendsListLoad"), object: nil)

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            ///stop indicator freeze after view enters background
            resumeIndicatorAnimation()
        }
        
        setUpViews()
        /// causes profile to freeze if its already been scrolled past 0
        let pushManager = PushNotificationManager(userID: uid)
        pushManager.registerForPushNotifications()
        
        /// wait to run requests after userInfo and friendsList has loaded
        if !mapVC.friendsLoaded {
            friendsEmpty = true
            return
        }
        
        getNotifications(refresh: false)
        getFriendRequests()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(false)
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        
        active = true
        
        /// if appended a new notification while view was in the background, scroll to first row
        if addedNewNoti {
            scrollToFirstRow()
            addedNewNoti = false
        }
        
        if children.count != 0 { return }
        resetView()
        resumeIndicatorAnimation()
        DispatchQueue.global().async { self.markNotisSeen() }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(false)
        active = false
        
       /// mapVC.customTabBar.tabBar.items?[3].image = UIImage(named: "NotificationsInactive")?.withRenderingMode(.alwaysOriginal)
       /// mapVC.customTabBar.tabBar.items?[3].selectedImage = UIImage(named: "NotificationsActive")?.withRenderingMode(.alwaysOriginal)
    }
    
    func setUpViews() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.register(FriendRequestCell.self, forCellReuseIdentifier: "FriendRequestCell")
        tableView.register(PostNotificationCell.self, forCellReuseIdentifier: "PostNotificationCell")
        tableView.register(SpotNotificationCell.self, forCellReuseIdentifier: "SpotNotificationCell")
        tableView.register(FriendRequestHeader.self, forHeaderFooterViewReuseIdentifier: "FriendRequestHeader")
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false 
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: UIScreen.main.bounds.minX + 30, width: UIScreen.main.bounds.width, height: 40))
        tableView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        view.addSubview(tableView)
    }
    
    func resumeIndicatorAnimation() {
        if self.activityIndicator != nil && !self.activityIndicator.isHidden {
            DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        }
    }
    
    func resetView() {
        
        active = true
        
        let annotations = mapVC.mapView.annotations
        mapVC.mapView.removeAnnotations(annotations)
        
        mapVC.hideNearbyButtons()
        mapVC.hideSpotButtons()
        ///mapVC.customTabBar.tabBar.isHidden = false
        mapVC.setUpNavBar()
        
        mapVC.prePanY = 0
        mapVC.removeBottomBar()
        
        UIView.animate(withDuration: 0.15) {
        ///    self.mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        }
    }
    
    func scrollToFirstRow() {
        if tableView != nil && notificationList.count > 1 {
            DispatchQueue.main.async { 
                self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            }
        }
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //scrollview reloads data when user nears bottom of screen
        
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 100)) && refresh == .yesRefresh {
            getNotifications(refresh: false)
            refresh = .refreshing
        }
    }
    
    func getFriendRequests() {
        
        let notiRef = db.collection("users").document(uid).collection("notifications")
        
        let friendRequestQuery = notiRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending").order(by: "timestamp", descending: true)
        
        listener1 = friendRequestQuery.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in

            if err == nil && !(snap?.metadata.isFromCache ?? false) {

                docLoop: for document in snap!.documents {
                    
                    let id = document.get("senderID") as! String
                    let timestamp = document.get("timestamp") as! Timestamp
                    
                    self.addFriendRequest(notiID: document.documentID, userID: id, timestamp: timestamp, accepted: false)
                }
            }
        }
    }
    
    func getNotifications(refresh: Bool) {
        
        let notiRef = db.collection("users").document(uid).collection("notifications")
        var query = notiRef.order(by: "timestamp", descending: true)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument)}
        
        listener2 = query.addSnapshotListener(includeMetadataChanges: true) { (snap, err) in

            if err != nil  { return }
            if snap?.metadata.isFromCache ?? false { return }
            
            else {
                
                if (snap!.documents.count <= 1) {
                    //refresh on 0 if friendrequest query is done (for empty state there will be 1 noti from b0t)
                    self.refresh = .noRefresh
                    self.removeRefresh()
                    self.tableView.reloadData()
                }
                
                var dispatchIndex = 1
                notiLoop: for document in snap!.documents {
                    
                    if dispatchIndex > 8 {
                        if !refresh { self.endDocument = document }
                        return
                    }
                    
                    let type = document.get("type") as? String ?? ""
                    let status = document.get("status") as? String ?? ""
                    
                    if type == "friendRequest" && status == "pending" {
                        continue notiLoop
                    }
                    
                    dispatchIndex += 1
                    
                    if refresh && self.notificationList.contains(where: {$0.notiID == document.documentID}) {
                        continue }
                    
                    let senderID = document.get("senderID") as! String
                    let timestamp = document.get("timestamp") as! Timestamp
                    
                    /// probably just get user info every time to simplify
                    
                    if type == "friendRequest" {
                        //set up friend request cell for accepted request
                        self.addFriendRequest(notiID: document.documentID, userID: senderID, timestamp: timestamp, accepted: true)
                        
                    } else {
                        /// if spotID != nil, get spot notification, if postID != nil, get post notification
                        let originalPoster = document.get("originalPoster") as? String ?? "someone"

                        if let spotID = document.get("spotID") as? String, type == "publicSpotAccepted" || type == "publicSpotRejected" || type == "spotTag" || type == "invite" {
                            self.getSpotForNotification(notiID: document.documentID, userID: senderID, spotID: spotID, timestamp: timestamp, type: type, originalPoster: originalPoster)
                            
                        } else {
                            
                            let postID = document.get("postID") as! String
                            self.getPostForNotification(notiID: document.documentID, userID: senderID, postID: postID, timestamp: timestamp, type: type, originalPoster: originalPoster)
                        }
                    }
                }
            }
        }
    }
    
    func addFriendRequest(notiID: String, userID: String, timestamp: Firebase.Timestamp, accepted: Bool) {
        
        getUserInfo(userID: userID) { (user) in
            let noti = FriendRequest(notiID: notiID, userInfo: user, timestamp: timestamp, accepted: accepted)
            if self.friendRequests.contains(where: { $0.notiID == notiID }) || self.friendRequestsPending.contains(where: {$0.notiID == notiID}) || self.removedRequestList.contains(where: {$0 == notiID}) { return }
            
            if (noti.accepted) {
                let type = "friendRequestAccepted"
                self.friendRequests.append(noti)
                self.notificationList.append((senderID: noti.userInfo.id ?? "", type: type, superType: 0, timestamp: noti.timestamp, notiID: noti.notiID))
                self.sortAndReload()
                
            } else {
                self.friendRequestsPending.append(noti)
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }

    func getPostForNotification(notiID: String, userID: String, postID: String, timestamp: Firebase.Timestamp, type: String, originalPoster: String) {
        
        getUserInfo(userID: userID) { (userInfo) in
            
            self.getMapPost(postID: postID) { (post) in
                
                if userInfo.id == "" { return }
                                
                /// update post notification
                if self.notificationList.contains(where: {$0.notiID == notiID}) {
                    if let i = self.postNotifications.firstIndex(where: {$0.notiID == notiID}) {
                        self.postNotifications[i].post = post
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    }
                    return
                }
                
                /// new content notification
                self.notificationList.append((senderID: userID, type: type, superType: 1, timestamp: timestamp, notiID: notiID))
                self.postNotifications.append(PostNotification(notiID: notiID, userInfo: userInfo, originalPoster: originalPoster, timestamp: timestamp, type: type, post: post))
                self.sortAndReload()
            }
        }
    }
    
    func getSpotForNotification(notiID: String, userID: String, spotID: String, timestamp: Firebase.Timestamp, type: String, originalPoster: String) {
        getUserInfo(userID: userID) { userInfo in
            self.getMapSpot(spotID: spotID) { (spot) in
                
                /// update spot noti
                if self.notificationList.contains(where: {$0.notiID == notiID}) {
                    if let i = self.spotNotifications.firstIndex(where: {$0.notiID == notiID}) {
                        self.spotNotifications[i].spot = spot
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    }
                    return
                }
                
                /// new content notification
                self.notificationList.append((senderID: userID, type: type, superType: 2, timestamp: timestamp, notiID: notiID))
                self.spotNotifications.append(SpotNotification(notiID: notiID, userInfo: userInfo, originalPoster: originalPoster, timestamp: timestamp, type: type, spot: spot))
                self.sortAndReload()
            }
        }
    }
    
    func sortAndReload() {
        notificationList = self.notificationList.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        removeRefresh()
        if refresh == .refreshing { refresh = .yesRefresh }
        if !self.active { self.addedNewNoti = true } /// added a notification when notis was in background, scroll to first row to see it
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func getUserInfo(userID: String, completion: @escaping (_ user: UserProfile) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        
        if let user = UserDataModel.shared.friendsList.first(where: {$0.id == userID}) {
            completion(user)
            
        } else if userID == mapVC.uid {
            completion(UserDataModel.shared.userInfo)
            
        } else {

            db.collection("users").document(userID).getDocument { (doc, err) in
                if err != nil { return }

                do {
                    let userInfo = try doc!.data(as: UserProfile.self)
                    guard var info = userInfo else { return }
                    info.id = doc!.documentID
                    completion(info)
                    
                } catch { print("catch"); completion(UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")); return }
            }
        }
    }
    
    // standard get post methods because we need to get all post data before opening post page
    func getMapPost(postID: String, completion: @escaping (_ post: MapPost) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        let dispatch = DispatchGroup()
        
        db.collection("posts").document(postID).getDocument { [weak self] (doc, err) in
            if err != nil { return }
            
            do {
                
                let info = try doc?.data(as: MapPost.self)
                guard var postInfo = info else { return }
                guard let self = self else { return }
                
                postInfo.id = doc!.documentID
                postInfo = self.setSecondaryPostValues(post: postInfo)
                
                dispatch.enter()
                dispatch.enter()
                
                self.getUserInfo(userID: postInfo.posterID) { (userInfo) in
                    if userInfo.id != "" { postInfo.userInfo = userInfo }
                    dispatch.leave()
                }
                                                
                self.getComments(postID: postID) { (comments) in
                    postInfo.commentList = comments
                    dispatch.leave()
                }
                
                dispatch.notify(queue: .main) { completion(postInfo) }
                                
            } catch { return }
        }
    }
    
    func getMapSpot(spotID: String, completion: @escaping (_ post: MapSpot) -> Void) {
        
        db.collection("spots").document(spotID).getDocument { (snap, err) in
            guard let doc = snap else { return }
            do {

                let spot = try doc.data(as: MapSpot.self)
                guard var spotInfo = spot else { return }
                
                spotInfo.id = doc.documentID
                completion(spotInfo)
                return
                
            } catch { return }
        }
    }
    
    func getComments(postID: String, completion: @escaping (_ comments: [MapComment]) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        var commentList: [MapComment] = []
        
        db.collection("posts").document(postID).collection("comments").order(by: "timestamp", descending: true).getDocuments { [weak self] (commentSnap, err) in
            
            if err != nil { completion(commentList); return }
            if commentSnap!.documents.count == 0 { completion(commentList); return }
            guard let self = self else { return }

            for doc in commentSnap!.documents {
                do {
                    let commentInf = try doc.data(as: MapComment.self)
                    guard var commentInfo = commentInf else { if doc == commentSnap!.documents.last { completion(commentList) }; continue }
                    
                    commentInfo.id = doc.documentID
                    commentInfo.seconds = commentInfo.timestamp.seconds
                    commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                    
                    if !commentList.contains(where: {$0.id == doc.documentID}) {
                        commentList.append(commentInfo)
                        commentList.sort(by: {$0.seconds < $1.seconds})
                    }
                                        
                    if doc == commentSnap!.documents.last { completion(commentList) }
                    
                } catch { if doc == commentSnap!.documents.last { completion(commentList) }; continue }
            }
        }
    }
    
    func removeRefresh() {
        if (self.activityIndicator.isAnimating()) { self.activityIndicator.stopAnimating() }
    }
    
    func markNotisSeen() {
        
        let notiRef = db.collection("users").document(uid).collection("notifications")
        let query = notiRef.whereField("seen", isEqualTo: false)
        
        query.getDocuments { (docs, err) in
            if err == nil {
                for doc in docs!.documents {
                    let type = doc.get("type") as? String ?? ""
                    let status = doc.get("status") as? String ?? ""
                    if !(type == "friendRequest" && status == "pending") {
                        self.db.collection("users").document(self.uid).collection("notifications").document(doc.documentID).updateData(["seen" : true]) }
                }
            }
        }
    }
    
    func checkForRequests() {
        /// pass friend request updates to pendingRequests controller on update from friend vc
        if sentFromPending {
            if !friendRequestsPending.isEmpty {
                if let vc = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "PendingFriends") as? PendingFriendRequestsController {
                    vc.rawRequests = friendRequestsPending
                    vc.notiVC = self
                    self.present(vc, animated: true)
                }
            }
        }
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notificationList.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch notificationList[indexPath.row].superType {
            
        case 0: return 80
            
        // smaller cell for no imageURL
        case 1:
            if (postNotifications.isEmpty) { return 0 }
            let currentNotificationID = notificationList[indexPath.row].notiID
            let currentRequest = postNotifications.first(where: {$0.notiID == currentNotificationID })
            if currentRequest?.post.imageURLs.isEmpty ?? true { return 80 }
            return 170

        case 2:
            if (spotNotifications.isEmpty) { return 0 }
            let currentNotificationID = notificationList[indexPath.row].notiID
            let currentRequest = spotNotifications.first(where: {$0.notiID == currentNotificationID })
            if currentRequest?.spot.imageURL == "" { return 80 }
            return 170
            
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FriendRequestHeader") as! FriendRequestHeader
        header.setUp(friendRequestCount: friendRequestsPending.count)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return friendRequestsPending.count == 0 ? 0 : 42
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let blank = tableView.dequeueReusableCell(withIdentifier: "friendRequestCell")
        blank?.backgroundColor = UIColor(named: "SpotBlack")
        
        if (notificationList.isEmpty) {
            return blank!
        }
        
        /// only accepted friend requests will show up here, pending will appear in header
        if (notificationList[indexPath.row].1 == "friendRequestAccepted") {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell") as? FriendRequestCell else { return blank! }
            
            let currentNotificationID = notificationList[indexPath.row].notiID
            var currentRequest: FriendRequest!
            for request in friendRequests {
                if request.notiID == currentNotificationID {
                    currentRequest = request
                }
            }
            if currentRequest == nil { return blank! }
            cell.setUpAll(request: currentRequest, currentUsername: UserDataModel.shared.userInfo.username)
            cell.setUpAccepted()
            return cell
            
        } else if notificationList[indexPath.row].superType == 1 {
            
            if (postNotifications.isEmpty) { return blank! }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostNotificationCell") as? PostNotificationCell else { return blank! }
            
            let currentNotificationID = notificationList[indexPath.row].notiID
            let currentRequest = postNotifications.first(where: {$0.notiID == currentNotificationID })
            
            if (currentRequest == nil) { return blank! }
            
            cell.setUp(notification: currentRequest!)
            
            return cell
        } else {
            
            if (spotNotifications.isEmpty) { return blank! }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SpotNotificationCell") as? SpotNotificationCell else { return blank! }
            
            let currentNotificationID = notificationList[indexPath.row].notiID
            let currentRequest = spotNotifications.first(where: {$0.notiID == currentNotificationID })
            
            if (currentRequest == nil) { return blank! }
            
            cell.setUp(notification: currentRequest!)
            
            return cell
        }
    }
    
    @objc func notifyFriendsLoad(_ sender: NSNotification) {
        /// run functions once map got userinfo
        if !friendsEmpty { return }
        getNotifications(refresh: false)
        getFriendRequests()
    }
    
    
    @objc func notifyAccept(_ notification:Notification) {
        
        if let friendID = notification.userInfo?.first?.value as? String {
            if let index = self.friendRequestsPending.firstIndex(where: {$0.userInfo.id == friendID}) {
                
                let request = self.friendRequestsPending.remove(at: index)
                self.removedRequestList.append(request.notiID)
                
                let interval = NSDate.now
                let timestamp = Timestamp(date: interval)
                request.timestamp = timestamp
                
                notificationList.insert((senderID: request.userInfo.id!, type: "friendRequestAccepted", superType: 0, timestamp: timestamp, notiID: request.notiID), at: 0)
                friendRequests.insert(request, at: 0)
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }
    
    @objc func notifyReject(_ notification:Notification) {
        
        if let friendID = notification.userInfo?.first?.value as? String {
            if let index = self.friendRequestsPending.firstIndex(where: {$0.userInfo.id == friendID}) {
                
                let request = self.friendRequestsPending.remove(at: index)
                self.removedRequestList.append(request.notiID)
                DispatchQueue.main.async { self.tableView.reloadData() }

            }
        }
    }
    
    func openProfile(user: UserProfile) {
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
         
            vc.userInfo = user
            vc.id = user.id!
            
            vc.mapVC = self.mapVC
            active = false
        ///    mapVC.customTabBar.tabBar.isHidden = true
            
            vc.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - mapVC.tabBarClosedY)
            self.addChild(vc)
            view.addSubview(vc.view)
            vc.didMove(toParent: self)
        }
    }
}

class FriendRequestCell: UITableViewCell {
    
    var usernameLabel: UILabel!
    var userButton: UIButton!
    var profilePic: UIImageView!
    var acceptButton: UIButton!
    var removeButton: UIButton!
    var detail: UILabel!
    var time: UILabel!
    var icon: UIImageView!
    var acceptedLabel: UILabel!
    var rejectedLabel: UILabel!
    var userInfo: UserProfile!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var username: String!
    
    public func setUpAll(request: FriendRequest, currentUsername: String) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        self.contentView.isUserInteractionEnabled = false
        
        self.userInfo = request.userInfo
        self.username = currentUsername
                
        usernameLabel = UILabel(frame: CGRect(x: 103, y: 27, width: 200, height: 20))
        usernameLabel.text = request.userInfo.username
        usernameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)!
        usernameLabel.textColor = UIColor(red:0.82, green:0.82, blue:0.82, alpha:1.0)
        self.addSubview(usernameLabel)
        
        profilePic = UIImageView(frame: CGRect(x: 65, y: 27.5, width: 30, height: 30))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        self.addSubview(profilePic)
        
        let url = request.userInfo.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        userButton = UIButton(frame: CGRect(x: usernameLabel.frame.minX - 40, y: usernameLabel.frame.minY - 5, width: usernameLabel.frame.maxX + 5, height: 40))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(openProfile(_:)), for: .touchUpInside)
        self.addSubview(userButton)
        
        time = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 80, y: 32, width: 40, height: 15))
        time.textColor = UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.0)
        time.textAlignment = .right
        time.font = UIFont(name: "SFCompactText-Regular", size: 12)
        time.text = getNotiTimestamp(timestamp: request.timestamp)
        self.addSubview(time)
        
        let friend = UIImage(named: "FriendNotification") ?? UIImage()
        icon = UIImageView(frame: CGRect(x: 26, y: 33, width: 16, height: 17))
        icon.contentMode = .scaleAspectFit
        icon.image = friend
        self.addSubview(icon)
    }
    
    func setUpPending() {
        
        detail = UILabel(frame: CGRect(x: 103, y: 43, width: 200, height: 15))
        detail.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
        detail.font = UIFont(name: "SFCompactText-regular", size: 14)
        detail.text = "sent you a friend request"
        detail.lineBreakMode = .byWordWrapping
        detail.numberOfLines = 0
        detail.sizeToFit()
        self.addSubview(detail)
        
        acceptButton = UIButton(frame: CGRect(x: 97, y: 85, width: 104, height: 33))
        acceptButton.setImage(UIImage(named: "AcceptButton"), for: UIControl.State.normal)
        acceptButton.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
        self.addSubview(acceptButton)
        
        removeButton = UIButton(frame: CGRect(x: acceptButton.frame.maxX + 10, y: 85, width: 95, height: 30))
        removeButton.backgroundColor = nil
        removeButton.layer.cornerRadius = 15
        removeButton.setTitle("Remove", for: UIControl.State.normal)
        removeButton.setTitleColor(UIColor(red:0.61, green:0.61, blue:0.61, alpha:1), for: UIControl.State.normal)
        removeButton.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        removeButton.addTarget(self, action: #selector(removeTap(_:)), for: .touchUpInside)
        self.addSubview(removeButton)
    }
    
    func setUpAccepted() {
        
        if acceptButton != nil { acceptButton.removeFromSuperview() }
        if removeButton != nil { removeButton.removeFromSuperview() }

        acceptedLabel = UILabel(frame: CGRect(x: 103, y: 44, width: 200, height: 15))
        acceptedLabel.text = "is now your friend!"
        acceptedLabel.textColor = (UIColor(named: "SpotGreen"))
        acceptedLabel.font = UIFont(name: "SFCompactText-regular", size: 14)
        acceptedLabel.numberOfLines = 0
        acceptedLabel.lineBreakMode = .byWordWrapping
        acceptedLabel.sizeToFit()
        self.addSubview(acceptedLabel)
    }
    
    func setUpRejected() {
        
        if acceptButton != nil { acceptButton.removeFromSuperview() }
        if removeButton != nil { removeButton.removeFromSuperview() }

        rejectedLabel = UILabel(frame: CGRect(x: 103, y: 44, width: 200, height: 15))
        rejectedLabel.text = "Friend request removed"
        rejectedLabel.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        rejectedLabel.font = UIFont(name: "SFCompactText-regular", size: 14)
        rejectedLabel.numberOfLines = 0
        rejectedLabel.lineBreakMode = .byWordWrapping
        rejectedLabel.sizeToFit()
        self.addSubview(rejectedLabel)
    }
        
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if usernameLabel != nil { usernameLabel.text = "" }
        if detail != nil { detail.text = "" }
        if acceptButton != nil { acceptButton.setImage(UIImage(), for: .normal) }
        if removeButton != nil { removeButton.setTitle("", for: .normal) }
        if acceptedLabel != nil { acceptedLabel.text = "" }
        if icon != nil { icon.image = UIImage() }
        if time != nil { time.text = "" }
        
        if profilePic != nil {
            profilePic.image = UIImage()
            profilePic.sd_cancelCurrentImageLoad()
        }
    }
    
    @objc func openProfile(_ sender: UIButton) {
        
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
            if let notiVC = self.viewContainingController() as? NotificationsViewController {
                
                notiVC.openProfile(user: self.userInfo!)
                
            } else if let pendingVC = self.viewContainingController() as? PendingFriendRequestsController {
                ///dismiss pending view controller before opening profile
                vc.userInfo = self.userInfo
                vc.id = userInfo.id!
                vc.mapVC = pendingVC.notiVC.mapVC
                
                pendingVC.notiVC.active = false
               /// pendingVC.notiVC.mapVC.customTabBar.tabBar.isHidden = true
                pendingVC.notiVC.sentFromPending = true
                
                pendingVC.dismiss(animated: false, completion: nil)
                
                vc.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - vc.mapVC.tabBarClosedY)
                pendingVC.notiVC.addChild(vc)
                pendingVC.notiVC.view.addSubview(vc.view)
                vc.didMove(toParent: pendingVC.notiVC)
            }
        }
    }
    
    @objc func acceptTap(_ sender: UIButton) {
        /// send notification to notificationsVC + pendingRequestsVC
        Mixpanel.mainInstance().track(event: "NotificationsAcceptRequest")
        self.acceptButton.setImage(UIImage(), for: .normal)
        self.removeButton.setImage(UIImage(), for: .normal)
        
        let friendID = userInfo.id!
        DispatchQueue.global(qos: .userInitiated).async { self.acceptFriendRequest(friendID: friendID) }
        
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("FriendRequestAccept"), object: nil, userInfo: infoPass)
    }
    
    @objc func removeTap(_ sender: UIButton) {
        /// send notification to notificationsVC + pendingRequestsVC
        Mixpanel.mainInstance().track(event: "NotificationsRemoveRequest")
        self.acceptButton.setImage(UIImage(), for: .normal)
        self.removeButton.setImage(UIImage(), for: .normal)
        
        let friendID = userInfo.id!
        removeFriendRequest(friendID: friendID, uid: uid)
        
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("FriendRequestReject"), object: nil, userInfo: infoPass)
    }
}

class PostNotificationCell: UITableViewCell {
    
    var usernameLabel: UILabel!
    var profilePic: UIImageView!
    var userButton: UIButton!
    var detail: UILabel!
    var time: UILabel!
    var contentImage: UIImageView!
    var icon: UIImageView!
    
    var userInfo: UserProfile!
    var notification: PostNotification!
    
    func setUp (notification: PostNotification) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        self.contentView.isUserInteractionEnabled = false
        
        self.userInfo = notification.userInfo
        self.notification = notification
        
        resetCell()
                
        usernameLabel = UILabel(frame: CGRect(x: 103, y: 27, width: 70, height: 20))
        usernameLabel.isHidden = false
        usernameLabel.text = notification.userInfo.username
        usernameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)!
        usernameLabel.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        usernameLabel.sizeToFit()
        self.addSubview(usernameLabel)
        
        profilePic = UIImageView(frame: CGRect(x: 65, y: 27.5, width: 30, height: 30))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        profilePic.isHidden = false
        self.addSubview(profilePic)
        
        let url = notification.userInfo.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        userButton = UIButton(frame: CGRect(x: usernameLabel.frame.minX - 40, y: usernameLabel.frame.minY - 5, width: usernameLabel.frame.maxX + 5, height: 40))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(openProfile(_:)), for: .touchUpInside)
        self.addSubview(userButton)
        
        
        time = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 80, y: 32, width: 40, height: 15))
        time.textColor = UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.0)
        time.textAlignment = .right
        time.font = UIFont(name: "SFCompactText-Regular", size: 12)
        time.isHidden = false
        time.text = getNotiTimestamp(timestamp: notification.timestamp)
        self.addSubview(time)
        
        icon = UIImageView(frame: CGRect(x: 25, y: 31, width: 19.5, height: 13))
        self.addSubview(icon)
        
        detail = UILabel(frame: CGRect(x: 103, y: 43, width: UIScreen.main.bounds.width - 188, height: 15))
        detail.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
        detail.font = UIFont(name: "SFCompactText-regular", size: 14)
        detail.isHidden = false
        detail.numberOfLines = 0
        detail.lineBreakMode = .byWordWrapping
        self.addSubview(detail)
        
        if !(notification.post.imageURLs.isEmpty) {
            contentImage = UIImageView(frame: CGRect(x: 103, y: 78, width: 50, height: 75))
            contentImage.layer.cornerRadius = 3
            contentImage.clipsToBounds = true
            contentImage.contentMode = .scaleAspectFill
            contentImage.isHidden = false
            contentImage.isUserInteractionEnabled = true
            contentImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openPost(_:))))
            self.addSubview(contentImage)
                    
            let contentURL = notification.post.imageURLs.first ?? ""
            if contentURL != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 200), scaleMode: .aspectFill)
                contentImage.sd_setImage(with: URL(string: contentURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
        
        if notification.type == "like" {
            detail.text = "liked your post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.width = 16
            newFrame.size.height = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "LikeNotification") ?? UIImage()
            
        } else if notification.type == "comment" {
            detail.text = "commented on your post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            
            icon.image = UIImage(named: "CommentNotification") ?? UIImage()
        } else if notification.type == "post" {
            detail.text = "posted at \(notification.post.spotName ?? "")"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 18
            icon.frame = newFrame
            icon.image = UIImage(named: "PostNotification") ?? UIImage()
            
        } else if notification.type == "invite" {
            detail.text = "added you to a spot"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.image = UIImage(named: "PrivateNotiIcon") ?? UIImage()
            
        } else if notification.type == "postAdd" {
            detail.text = "added you to a post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 18
            icon.frame = newFrame
            icon.image = UIImage(named: "PostNotification") ?? UIImage()
            
        } else if notification.type == "commentTag" {
            detail.text = "mentioned you in a comment"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "CommentNotification") ?? UIImage()
            
        } else if notification.type == "commentLike" {
            detail.text = "liked your comment"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "LikeNotification") ?? UIImage()

        } else if notification.type == "spotTag" {
            detail.text = "tagged you at a spot"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 20
            newFrame.size.width = 20
            icon.frame = newFrame
            icon.image = UIImage(named: "PlainSpotIcon") ?? UIImage()
            
        } else if notification.type == "postTag" {
            detail.text = "mentioned you in a post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 18
            icon.frame = newFrame
            icon.image = UIImage(named: "PostNotification") ?? UIImage()
            
        } else if notification.type == "commentComment" || notification.type == "commentOnAdd" {
            detail.text = "commented on \(notification.originalPoster)'s post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "CommentNotification") ?? UIImage()
            
        } else if notification.type == "likeOnAdd" {
            detail.text = "liked \(notification.originalPoster)'s post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.width = 16
            newFrame.size.height = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "LikeNotification") ?? UIImage()
            
        } else if notification.type == "publicSpotAccepted" {
            detail.text = "Your public submission was approved!"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.contentMode = .scaleAspectFit
            icon.image = UIImage(named: "PublicSubmissionAccepted") ?? UIImage()
            
        } else if notification.type == "publicSpotRejected" {
            detail.text = "Your spot was not approved for the public map"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.contentMode = .scaleAspectFit
            icon.image = UIImage(named: "PublicSubmissionDenied") ?? UIImage()
        }
        
        if contentImage != nil {
            contentImage.frame = CGRect(x: contentImage.frame.minX, y: detail.frame.maxY + 10, width: contentImage.frame.width, height: contentImage.frame.height)
        }

        usernameLabel.isHidden = false
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if contentImage != nil { contentImage.image = UIImage() }
        if usernameLabel != nil { usernameLabel.text = "" }
        if time != nil { time.text = "" }
        if detail != nil { detail.text = "" }
        if icon != nil { icon.image = UIImage() }
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()
        
        if profilePic != nil {
            profilePic.sd_cancelCurrentImageLoad()
            profilePic.image = UIImage()
        }
        
        if contentImage != nil {
            contentImage.sd_cancelCurrentImageLoad()
            contentImage.image = UIImage()
        }
    }
    
    @objc func openProfile(_ sender: UIButton) {
        if let notiVC = self.viewContainingController() as? NotificationsViewController {
            notiVC.openProfile(user: self.userInfo!)
        }
    }
    
    @objc func openPost(_ sender: UITapGestureRecognizer) {
        
        guard let notiVC = viewContainingController() as? NotificationsViewController else { return }
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            notiVC.active = false
            
            let pList = [notification.post]
            vc.postsList = pList
            vc.selectedPostIndex = 0
            vc.mapVC = notiVC.mapVC
            vc.parentVC = .notifications
            
            if notification.type == "commentComment" || notification.type == "commentTag" || notification.type == "comment" { vc.commentNoti = true }
            
            notiVC.mapVC.navigationItem.title = ""
            /// notiVC.mapVC.customTabBar.tabBar.isHidden = true
            notiVC.mapVC.navigationController?.navigationBar.removeShadow()
            notiVC.mapVC.navigationController?.navigationBar.removeBackgroundImage()
            notiVC.mapVC.toggleMapTouch(enable: true )
            
            vc.view.frame = notiVC.view.frame
            notiVC.addChild(vc)
            notiVC.view.addSubview(vc.view)
            vc.didMove(toParent: notiVC)
            
            notiVC.mapVC.postsList = pList
            let infoPass = ["selectedPost": 0, "firstOpen": true, "parentVC":  PostViewController.parentViewController.notifications] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
        }
    }
}

class SpotNotificationCell: UITableViewCell {
    
    var usernameLabel: UILabel!
    var profilePic: UIImageView!
    var userButton: UIButton!
    var detail: UILabel!
    var time: UILabel!
    var spotImage: UIImageView!
    var icon: UIImageView!
    
    var userInfo: UserProfile!
    var notification: SpotNotification!
    
    func setUp (notification: SpotNotification) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        self.contentView.isUserInteractionEnabled = false
        
        self.userInfo = notification.userInfo
        self.notification = notification
        
        resetCell()
                
        usernameLabel = UILabel(frame: CGRect(x: 103, y: 27, width: 70, height: 20))
        usernameLabel.isHidden = false
        usernameLabel.text = notification.userInfo.username
        usernameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 13)!
        usernameLabel.textColor = UIColor(red:0.88, green:0.88, blue:0.88, alpha:1.0)
        usernameLabel.sizeToFit()
        self.addSubview(usernameLabel)
        
        profilePic = UIImageView(frame: CGRect(x: 65, y: 27.5, width: 30, height: 30))
        profilePic.layer.masksToBounds = false
        profilePic.layer.cornerRadius = profilePic.frame.height/2
        profilePic.clipsToBounds = true
        profilePic.contentMode = UIView.ContentMode.scaleAspectFill
        profilePic.isHidden = false
        self.addSubview(profilePic)
        
        let url = notification.userInfo.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        userButton = UIButton(frame: CGRect(x: usernameLabel.frame.minX - 40, y: usernameLabel.frame.minY - 5, width: usernameLabel.frame.maxX + 5, height: 40))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(openProfile(_:)), for: .touchUpInside)
        self.addSubview(userButton)
        
        
        time = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 80, y: 32, width: 40, height: 15))
        time.textColor = UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.0)
        time.textAlignment = .right
        time.font = UIFont(name: "SFCompactText-Regular", size: 12)
        time.isHidden = false
        time.text = getNotiTimestamp(timestamp: notification.timestamp)
        self.addSubview(time)
        
        icon = UIImageView(frame: CGRect(x: 25, y: 31, width: 19.5, height: 13))
        self.addSubview(icon)
        
        detail = UILabel(frame: CGRect(x: 103, y: 43, width: UIScreen.main.bounds.width - 188, height: 15))
        detail.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
        detail.font = UIFont(name: "SFCompactText-regular", size: 14)
        detail.isHidden = false
        detail.numberOfLines = 0
        detail.lineBreakMode = .byWordWrapping
        self.addSubview(detail)
        
        if (notification.spot.imageURL != "") {
            spotImage = UIImageView(frame: CGRect(x: 103, y: 78, width: 50, height: 75))
            spotImage.layer.cornerRadius = 3
            spotImage.clipsToBounds = true
            spotImage.contentMode = .scaleAspectFill
            spotImage.isHidden = false
            spotImage.isUserInteractionEnabled = true
            spotImage.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openSpot(_:))))
            self.addSubview(spotImage)
                            
            let contentURL = notification.spot.imageURL
            if contentURL != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 200), scaleMode: .aspectFill)
                spotImage.sd_setImage(with: URL(string: contentURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
        
        if notification.type == "invite" {
            detail.text = "added you to \(notification.spot.spotName)"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.image = UIImage(named: "PrivateNotiIcon") ?? UIImage()
            
        } else if notification.type == "spotTag" {
            detail.text = "tagged you at \(notification.spot.spotName)"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 20
            newFrame.size.width = 20
            icon.frame = newFrame
            icon.image = UIImage(named: "PlainSpotIcon") ?? UIImage()
                        
        } else if notification.type == "publicSpotAccepted" {
            detail.text = "Your public submission was approved!"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.contentMode = .scaleAspectFit
            icon.image = UIImage(named: "PublicSubmissionAccepted") ?? UIImage()
            
        } else if notification.type == "publicSpotRejected" {
            detail.text = "Your spot was not approved for the public map"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 22
            newFrame.size.width = 22
            icon.frame = newFrame
            icon.contentMode = .scaleAspectFit
            icon.image = UIImage(named: "PublicSubmissionDenied") ?? UIImage()
        }
        
        spotImage.frame = CGRect(x: spotImage.frame.minX, y: detail.frame.maxY + 10, width: spotImage.frame.width, height: spotImage.frame.height)
        usernameLabel.isHidden = false
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if spotImage != nil { spotImage.image = UIImage() }
        if usernameLabel != nil { usernameLabel.text = "" }
        if time != nil { time.text = "" }
        if detail != nil { detail.text = "" }
        if icon != nil { icon.image = UIImage() }
    }
    
    @objc func openProfile(_ sender: UIButton) {
        if let notiVC = self.viewContainingController() as? NotificationsViewController {
            notiVC.openProfile(user: self.userInfo!)
        }
    }
    
    @objc func openSpot(_ sender: UIButton) {
        guard let notiVC = viewContainingController() as? NotificationsViewController else { return }
        if let spotVC = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "SpotPage") as? SpotViewController {
            
            let spot = notification.spot
            
            spotVC.spotID = spot.id ?? ""
            spotVC.spotObject = spot
            spotVC.mapVC = notiVC.mapVC
            
            spotVC.view.frame = notiVC.view.frame
            notiVC.addChild(spotVC)
            notiVC.view.addSubview(spotVC.view)
            spotVC.didMove(toParent: notiVC)
            
            notiVC.mapVC.prePanY = notiVC.mapVC.halfScreenY
         ///   DispatchQueue.main.async { notiVC.mapVC.customTabBar.view.frame = CGRect(x: 0, y: notiVC.mapVC.halfScreenY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - notiVC.mapVC.halfScreenY) }
            
            let infoPass = ["spot": spot as Any] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("OpenSpotFromNotis"), object: nil, userInfo: infoPass)
        }
    }
    
    
    override func prepareForReuse() {
        
        super.prepareForReuse()
        
        if profilePic != nil {
            profilePic.sd_cancelCurrentImageLoad()
            profilePic.image = UIImage()
        }
        
        if spotImage != nil {
            spotImage.sd_cancelCurrentImageLoad()
            spotImage.image = UIImage()
        }
    }

}

class FriendRequestHeader: UITableViewHeaderFooterView {
    
    var friendRequestsLabel: UILabel!
    var tapArea: UIButton!
    
    func setUp(friendRequestCount: Int) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(red: 0.03, green: 0.604, blue: 0.604, alpha: 1)
        self.backgroundView = backgroundView
                
        if friendRequestsLabel != nil { friendRequestsLabel.text = "" }
        friendRequestsLabel = UILabel(frame: CGRect(x: 23, y: 12, width: 200, height: 18))
        var labelText = "\(friendRequestCount) Friend Request"
        if friendRequestCount > 1 { labelText += "s" }
        friendRequestsLabel.text = labelText
        friendRequestsLabel.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        friendRequestsLabel.textColor = .white
        friendRequestsLabel.textAlignment = .left
        self.addSubview(friendRequestsLabel)
                
        tapArea = UIButton(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        tapArea.backgroundColor = nil
        tapArea.addTarget(self, action: #selector(openRequests(_:)), for: .touchUpInside)
        self.addSubview(tapArea)
    }
    
    @objc func openRequests(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "TabBar", bundle: nil).instantiateViewController(withIdentifier: "PendingFriends") as? PendingFriendRequestsController {
            if let notiVC = self.viewContainingController() as? NotificationsViewController {
                print("set raw requests")
                vc.rawRequests = notiVC.friendRequestsPending
                vc.notiVC = notiVC
                notiVC.present(vc, animated: true)
            }
        }
    }
    
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UITableViewCell {
    func getNotiTimestamp(timestamp: Firebase.Timestamp) -> String {
        let current = NSDate().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - timestamp.seconds
        
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
}

