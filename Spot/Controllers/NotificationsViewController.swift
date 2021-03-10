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
    
    lazy var friendRequestList: [FriendRequest] = []
    lazy var contentNotificationList: [ContentNotification] = []
    lazy var notificationList: [(senderID: String, type: String, timestamp: Firebase.Timestamp, notiID: String)] = []
    lazy var friendRequestsPending: [FriendRequest] = []
    
    let acceptNotificationName = Notification.Name("friendRequestAccept")
    let deleteNotificationName = Notification.Name("friendRequestReject")
    
    var listener1, listener2, listener3, listener4, listener5: ListenerRegistration!
    var endDocument: DocumentSnapshot!
    
    unowned var mapVC: MapViewController!
    
    var refresh: NearbyViewController.refreshStatus = .refreshing
    
    lazy var sentFromPending = false
    lazy var active = false
    
    //finish passing method reloads data if friend request action was taken in profile
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyAccept(_:)), name: acceptNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyReject(_:)), name: deleteNotificationName, object: nil)
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            ///stop indicator freeze after view enters background
            resumeIndicatorAnimation()
        }
        
        self.setUpViews()
        getNotifications(refresh: false)
        getFriendRequests()
        removeSeen()
        
        /// causes profile to freeze if its already been scrolled past 0
        let pushManager = PushNotificationManager(userID: uid)
        pushManager.registerForPushNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(false)
        Mixpanel.mainInstance().track(event: "NotificationsOpen")
        
        active = true
        if tableView != nil {
            DispatchQueue.main.async { self.tableView.reloadData() }
            getNotifications(refresh: true)
        }
        
        resetView()
        markNotisSeen()
        resumeIndicatorAnimation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
        active = false
        
        mapVC.mapMask.removeFromSuperview()
        mapVC.customTabBar.tabBar.items?[3].image = UIImage(named: "NotificationsInactive")?.withRenderingMode(.alwaysOriginal)
        mapVC.customTabBar.tabBar.items?[3].selectedImage = UIImage(named: "NotificationsActive")?.withRenderingMode(.alwaysOriginal)
    }
    
    func setUpViews() {
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - mapVC.tabBarOpenY))
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.register(FriendRequestCell.self, forCellReuseIdentifier: "FriendRequestCell")
        tableView.register(ContentCell.self, forCellReuseIdentifier: "ContentCell")
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
        
        mapVC.prePanY = 0
        mapVC.customTabBar.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        
        mapVC.hideNearbyButtons()
        mapVC.hideSpotButtons()
        mapVC.customTabBar.tabBar.isHidden = false
        mapVC.setUpNavBar()
        
        mapVC.mapMask.backgroundColor = UIColor(named: "SpotBlack")!.withAlphaComponent(0.7)
        mapVC.mapView.addSubview(mapVC.mapMask)
    }
    
    func updateContentPosts() {
        // update content posts because there's no active listener attached to getcontentposts
        for noti in contentNotificationList {
            getContentPosts(notiID: noti.notiID, userID: noti.userInfo.id ?? "", postID: noti.post.id ?? "", timestamp: noti.post.timestamp, type: noti.type, originalPoster: noti.originalPoster)
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
            //   if (snap.count != 0)
            if err == nil && !(snap?.metadata.isFromCache ?? false) {
                //if query returns 0, refresh if the other query is done running
                
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
            //   if (snap.count != 0)
            if err != nil  { return }
            
            else {
                
                if(snap!.documents.count <= 1) {
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
                        let postID = document.get("postID") as! String
                        let originalPoster = document.get("originalPoster") as? String ?? "someone"
                        self.getContentPosts(notiID: document.documentID, userID: senderID, postID: postID, timestamp: timestamp, type: type, originalPoster: originalPoster)
                    }
                }
            }
        }
    }
    
    func addFriendRequest(notiID: String, userID: String, timestamp: Firebase.Timestamp, accepted: Bool) {
        
        getUserInfo(userID: userID, mapVC: mapVC) { (user) in
            let noti = FriendRequest(notiID: notiID, userInfo: user, timestamp: timestamp, accepted: accepted)
            if self.friendRequestList.contains(where: { $0.notiID == notiID }) || self.friendRequestsPending.contains(where: {$0.notiID == notiID}) { return }
            
            if (noti.accepted) {
                let type = "friendRequestAccepted"
                self.friendRequestList.append(noti)
                self.notificationList.append((senderID: noti.userInfo.id ?? "", type: type, timestamp: noti.timestamp, notiID: noti.notiID))
                self.notificationList = self.notificationList.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
                if self.refresh == .refreshing { self.refresh = .yesRefresh }
                /// don't refresh here due to friend requests loading before the rest of notificaitons
            } else {
                self.friendRequestsPending.append(noti)
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }
    
    func getContentPosts(notiID: String, userID: String, postID: String, timestamp: Firebase.Timestamp, type: String, originalPoster: String) {
        
        getUserInfo(userID: userID, mapVC: mapVC) { (userInfo) in
            self.getMapPost(postID: postID, mapVC: self.mapVC) { (post) in
                
                /// update post notification
                if self.notificationList.contains(where: {$0.notiID == notiID}) {
                    if let contentNoti = self.contentNotificationList.first(where: {$0.notiID == notiID}) {
                        contentNoti.post = post
                        DispatchQueue.main.async { self.tableView.reloadData() }
                    }
                    return
                }
                
                /// new content notification
                self.notificationList.append((senderID: userID, type: type, timestamp: timestamp, notiID: notiID))
                self.contentNotificationList.append(ContentNotification(notiID: notiID, userInfo: userInfo, originalPoster: originalPoster, timestamp: timestamp, type: type, post: post))
                self.notificationList = self.notificationList.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
                self.removeRefresh()
                if self.refresh == .refreshing { self.refresh = .yesRefresh }
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }
    
    func getUserInfo(userID: String, mapVC: MapViewController, completion: @escaping (_ user: UserProfile) -> Void) {
        let db: Firestore! = Firestore.firestore()
        
        if let user = mapVC.friendsList.first(where: {$0.id == userID}) {
            completion(user)
        } else {
            db.collection("users").document(userID).getDocument { (doc, err) in
                if err != nil { return }
                do {
                    let userInfo = try doc!.data(as: UserProfile.self)
                    guard var info = userInfo else { return }
                    info.id = doc!.documentID
                    
                    completion(info)
                } catch { return }
            }
        }
    }
    
    // standard get post methods because we need to get all post data before opening post page
    func getMapPost(postID: String, mapVC: MapViewController, completion: @escaping (_ post: MapPost) -> Void) {
        
        let dispatch = DispatchGroup()
        let db: Firestore! = Firestore.firestore()
        
        db.collection("posts").document(postID).addSnapshotListener({ (doc, err) in
            if err != nil { return }
            
            do {
                let postInfo = try doc?.data(as: MapPost.self)
                guard var info = postInfo else { return }
                
                info.seconds = info.timestamp.seconds
                info.id = doc!.documentID
                
                dispatch.enter()
                dispatch.enter()
                
                self.prefetchImages(imageURLs: info.imageURLs)
                
                self.getUserInfo(userID: info.posterID, mapVC: mapVC) { (userInfo) in
                    info.userInfo = userInfo
                    dispatch.leave()
                }
                
                self.getComments(postID: postID) { (comments) in
                    info.commentList = comments
                    dispatch.leave()
                }
                
                dispatch.notify(queue: .main) {
                    completion(info)
                }
                
            } catch { return }
        })
    }
    
    
    
    func prefetchImages(imageURLs: [String]) {
        var urls: [URL] = []
        for postURL in imageURLs {
            guard let url = URL(string: postURL) else { continue }
            urls.append(url)
        }
        
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
    }
    
    func getComments(postID: String, completion: @escaping (_ comments: [MapComment]) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        var commentList: [MapComment] = []
        
        db.collection("posts").document(postID).collection("comments").order(by: "timestamp", descending: true).getDocuments { (commentSnap, err) in
            
            if err != nil { return }

            for doc in commentSnap!.documents {
                do {
                    let commentInf = try doc.data(as: MapComment.self)
                    guard var commentInfo = commentInf else { return }
                    
                    commentInfo.id = doc.documentID
                    commentInfo.seconds = commentInfo.timestamp.seconds
                    commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                    
                    if !commentList.contains(where: {$0.id == doc.documentID}) {
                        commentList.append(commentInfo)
                        commentList.sort(by: {$0.seconds < $1.seconds})
                    }
                    
                    let docCount = commentSnap!.documents.count
                    let commentCount = commentList.count
                    
                    if commentCount == docCount {
                        completion(commentList)
                    }
                    
                } catch { continue }
            }
        }
    }
    
    func removeRefresh() {
        if (self.activityIndicator.isAnimating()) { self.activityIndicator.stopAnimating() }
    }
    
    func removeSeen() {
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
    
    func markNotisSeen() {
        let notiRef = db.collection("users").document(uid).collection("notifications")
        let query = notiRef.whereField("seen", isEqualTo: false)
        
        query.getDocuments { (docs, err) in
            if err != nil { return }
            for doc in docs!.documents {
                print("update doc")
                self.db.collection("users").document(self.uid).collection("notifications").document(doc.documentID).updateData(["seen" : true])
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notificationList.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (notificationList[indexPath.row].type == "friendRequestAccepted" || notificationList[indexPath.row].type == "friendRequestRejected") {
            return 80
        } else {
            return 170
        }
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FriendRequestHeader") as! FriendRequestHeader
        header.setUp(friendRequestCount: friendRequestsPending.count)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return friendRequestsPending.count == 0 ? 0 : 45
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let blank = tableView.dequeueReusableCell(withIdentifier: "friendRequestCell")
        blank?.backgroundColor = UIColor(named: "SpotBlack")
        
        if (notificationList.isEmpty) {
            return blank!
        }
        
        if (notificationList[indexPath.row].1 == "friendRequestAccepted") {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCell") as! FriendRequestCell
            
            let currentNotificationID = notificationList[indexPath.row].notiID
            var currentRequest: FriendRequest!
            for request in friendRequestList {
                if request.notiID == currentNotificationID {
                    currentRequest = request
                }
            }
            if currentRequest == nil { return blank! }
            cell.setUpAll(request: currentRequest, currentUsername: self.mapVC.userInfo.username )
            cell.setUpAccepted()
            return cell
        } else {
            
            if (contentNotificationList.isEmpty) { return blank! }
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContentCell") as! ContentCell
            
            let currentNotificationID = notificationList[indexPath.row].notiID
            
            var currentRequest: ContentNotification!
            for content in contentNotificationList {
                if content.notiID == currentNotificationID {
                    currentRequest = content
                }
            }
            
            if (currentRequest == nil) { return blank! }
            
            cell.setUpAll(notification: currentRequest)
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let notiID = self.notificationList[indexPath.row].notiID
        if let noti = self.contentNotificationList.first(where: {$0.notiID == notiID}) {
            if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
                
                self.active = false
                
                let pList = [noti.post]
                vc.postsList = pList
                vc.selectedPostIndex = 0
                vc.mapVC = self.mapVC
                vc.parentVC = .notifications
                
                if noti.type == "commentComment" || noti.type == "commentTag" || noti.type == "comment" { vc.commentNoti = true }
                
                mapVC.title = ""
                mapVC.customTabBar.tabBar.isHidden = true
                mapVC.navigationController?.navigationBar.isTranslucent = true
                mapVC.mapMask.removeFromSuperview()
                
                vc.view.frame = self.view.frame
                self.addChild(vc)
                self.view.addSubview(vc.view)
                vc.didMove(toParent: self)
                
                self.mapVC.postsList = pList
                let infoPass = ["selectedPost": 0, "firstOpen": true, "parentVC":  PostViewController.parentViewController.notifications] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            }
        }
    }
    
    @objc func notifyAccept(_ notification:Notification) {
        if let friendID = notification.userInfo?.first?.value as? String {
            if let index = self.friendRequestsPending.firstIndex(where: {$0.userInfo.id == friendID}) {
                let request = self.friendRequestsPending.remove(at: index)
                let interval = NSDate.now
                let timestamp = Timestamp(date: interval)
                request.timestamp = timestamp
                
                self.notificationList.insert((senderID: request.userInfo.id!, type: "friendRequestAccepted", timestamp: timestamp, notiID: request.notiID), at: 0)
                self.friendRequestList.insert(request, at: 0)
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
    }
    
    @objc func notifyReject(_ notification:Notification) {
        if let friendID = notification.userInfo?.first?.value as? String {
            friendRequestsPending.removeAll(where: {$0.userInfo.id == friendID})
            DispatchQueue.main.async { self.tableView.reloadData() }
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
        
        self.userInfo = request.userInfo
        self.username = currentUsername
                
        usernameLabel = UILabel(frame: CGRect(x: 103, y: 27, width: 200, height: 20))
        usernameLabel.text = request.userInfo.username
        usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)!
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
        
        time = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 80, y: 28, width: 40, height: 15))
        time.textColor = UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.0)
        time.textAlignment = .right
        time.font = UIFont(name: "SFCamera-Regular", size: 12)
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
        detail.font = UIFont(name: "SFCamera-regular", size: 14)
        detail.text = "sent you a friend request"
        detail.lineBreakMode = .byWordWrapping
        detail.numberOfLines = 0
        detail.sizeToFit()
        self.addSubview(detail)
        
        acceptButton = UIButton(frame: CGRect(x: 103, y: 85, width: 95, height: 30))
        acceptButton.layer.cornerRadius = 15
        acceptButton.layer.borderWidth = 2
        acceptButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        acceptButton.backgroundColor = nil
        acceptButton.setTitle("Accept", for: UIControl.State.normal)
        acceptButton.setTitleColor(UIColor(named: "SpotGreen"), for: UIControl.State.normal)
        acceptButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        acceptButton.addTarget(self, action: #selector(acceptTap(_:)), for: .touchUpInside)
        self.addSubview(acceptButton)
        
        removeButton = UIButton(frame: CGRect(x: 210, y: 85, width: 95, height: 30))
        removeButton.backgroundColor = nil
        removeButton.layer.cornerRadius = 15
        removeButton.layer.borderWidth = 2
        removeButton.layer.borderColor = UIColor(red:0.61, green:0.61, blue:0.61, alpha:1).cgColor
        removeButton.setTitle("Remove", for: UIControl.State.normal)
        removeButton.setTitleColor(UIColor(red:0.61, green:0.61, blue:0.61, alpha:1), for: UIControl.State.normal)
        removeButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        removeButton.addTarget(self, action: #selector(removeTap(_:)), for: .touchUpInside)
        self.addSubview(removeButton)
    }
    
    func setUpAccepted() {
        
        if acceptButton != nil { acceptButton.removeFromSuperview() }
        if removeButton != nil { removeButton.removeFromSuperview() }

        acceptedLabel = UILabel(frame: CGRect(x: 103, y: 44, width: 200, height: 15))
        acceptedLabel.text = "is now your friend!"
        acceptedLabel.textColor = (UIColor(named: "SpotGreen"))
        acceptedLabel.font = UIFont(name: "SFCamera-regular", size: 14)
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
        rejectedLabel.font = UIFont(name: "SFCamera-regular", size: 14)
        rejectedLabel.numberOfLines = 0
        rejectedLabel.lineBreakMode = .byWordWrapping
        rejectedLabel.sizeToFit()
        self.addSubview(rejectedLabel)
    }
        
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if usernameLabel != nil { usernameLabel.text = "" }
        if detail != nil { detail.text = "" }
        if acceptButton != nil { acceptButton.setImage(UIImage(), for: .normal); acceptButton.removeFromSuperview() }
        if removeButton != nil { removeButton.setImage(UIImage(), for: .normal); removeButton.removeFromSuperview() }
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
                vc.userInfo = self.userInfo
                vc.id = userInfo.id!
                
                vc.mapVC = notiVC.mapVC
                
                notiVC.active = false
                notiVC.mapVC.customTabBar.tabBar.isHidden = true
                notiVC.mapVC.mapMask.removeFromSuperview()
                
                vc.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - notiVC.mapVC.tabBarClosedY)
                notiVC.addChild(vc)
                notiVC.view.addSubview(vc.view)
                vc.didMove(toParent: notiVC)
                
            } else if let pendingVC = self.viewContainingController() as? PendingFriendRequestsController {
                ///dismiss pending view controller before opening profile
                vc.userInfo = self.userInfo
                vc.id = userInfo.id!
                vc.mapVC = pendingVC.notiVC.mapVC
                
                pendingVC.notiVC.active = false
                pendingVC.notiVC.mapVC.customTabBar.tabBar.isHidden = true
                pendingVC.notiVC.mapVC.mapMask.removeFromSuperview()
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
        Mixpanel.mainInstance().track(event: "NotificationsAcceptRequest")
        self.acceptButton.setImage(UIImage(), for: .normal)
        self.removeButton.setImage(UIImage(), for: .normal)
        
        let friendID = userInfo.id!
        acceptFriendRequest(friendID: friendID, uid: uid, username: username)
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestAccept"), object: nil, userInfo: infoPass)
    }
    
    @objc func removeTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "NotificationsRemoveRequest")
        self.acceptButton.setImage(UIImage(), for: .normal)
        self.removeButton.setImage(UIImage(), for: .normal)
        
        let friendID = userInfo.id!
        removeFriendRequest(friendID: friendID, uid: uid)
        let infoPass = ["friendID": friendID] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("friendRequestReject"), object: nil, userInfo: infoPass)
    }
}

class ContentCell: UITableViewCell {
    
    var usernameLabel: UILabel!
    var profilePic: UIImageView!
    var userButton: UIButton!
    var detail: UILabel!
    var time: UILabel!
    var contentImage: UIImageView!
    var icon: UIImageView!
    var userInfo: UserProfile!
    
    func setUpAll (notification: ContentNotification) {
        
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.selectionStyle = .none
        self.userInfo = notification.userInfo
        
        resetCell()
                
        usernameLabel = UILabel(frame: CGRect(x: 103, y: 27, width: 70, height: 20))
        usernameLabel.isHidden = false
        usernameLabel.text = notification.userInfo.username
        usernameLabel.font = UIFont(name: "SFCamera-Semibold", size: 13)!
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
        
        
        time = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 80, y: 28, width: 40, height: 15))
        time.textColor = UIColor(red:0.78, green:0.78, blue:0.78, alpha:1.0)
        time.textAlignment = .right
        time.font = UIFont(name: "SFCamera-Regular", size: 12)
        time.isHidden = false
        time.text = getNotiTimestamp(timestamp: notification.timestamp)
        self.addSubview(time)
        
        icon = UIImageView(frame: CGRect(x: 25, y: 31, width: 19.5, height: 13))
        self.addSubview(icon)
        
        detail = UILabel(frame: CGRect(x: 103, y: 43, width: UIScreen.main.bounds.width - 117, height: 15))
        detail.textColor = UIColor(red:0.71, green:0.71, blue:0.71, alpha:1.0)
        detail.font = UIFont(name: "SFCamera-regular", size: 14)
        detail.isHidden = false
        detail.numberOfLines = 0
        detail.lineBreakMode = .byWordWrapping
        self.addSubview(detail)
        
        contentImage = UIImageView(frame: CGRect(x: 103, y: 78, width: 50, height: 75))
        contentImage.layer.cornerRadius = 3
        contentImage.clipsToBounds = true
        contentImage.contentMode = .scaleAspectFill
        contentImage.isHidden = false
        self.addSubview(contentImage)
                
        let contentURL = notification.post.imageURLs.first ?? ""
        if contentURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
            contentImage.sd_setImage(with: URL(string: contentURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
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
            detail.text = "added you to a private spot"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 20
            newFrame.size.width = 17
            icon.frame = newFrame
            icon.image = UIImage(named: "PrivateIcon") ?? UIImage()
        } else if notification.type == "commentTag" {
            detail.text = "tagged you in a comment"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "CommentNotification") ?? UIImage()
        } else if notification.type == "spotTag" {
            detail.text = "tagged you at a spot"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 20
            newFrame.size.width = 20
            icon.frame = newFrame
            icon.image = UIImage(named: "BlackSpotIcon") ?? UIImage()
        } else if notification.type == "postTag" {
            detail.text = "tagged you in a post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 18
            icon.frame = newFrame
            icon.image = UIImage(named: "PostNotification") ?? UIImage()
        } else if notification.type == "commentComment" {
            detail.text = "commented on \(notification.originalPoster)'s post"
            detail.sizeToFit()
            var newFrame = icon.frame
            newFrame.size.height = 16
            newFrame.size.width = 16
            icon.frame = newFrame
            icon.image = UIImage(named: "CommentNotification") ?? UIImage()
        }
        
        contentImage.frame = CGRect(x: 103, y: detail.frame.maxY + 10, width: 50, height: 75)

        usernameLabel.isHidden = false
    }
    
    func resetCell() {
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
            contentImage.image = UIImage()
            contentImage.sd_cancelCurrentImageLoad()
        }
    }
    
    @objc func openProfile(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
            if let notiVC = self.viewContainingController() as? NotificationsViewController {
                
                vc.userInfo = self.userInfo
                vc.id = userInfo.id!
                vc.mapVC = notiVC.mapVC
                
                notiVC.active = false
                notiVC.mapVC.customTabBar.tabBar.isHidden = true
                
                vc.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - notiVC.mapVC.tabBarClosedY)
                notiVC.addChild(vc)
                notiVC.view.addSubview(vc.view)
                vc.didMove(toParent: notiVC)
            }
        }
    }
}

class FriendRequestHeader: UITableViewHeaderFooterView {
    var friendRequestsLabel: UILabel!
    var friendRequestCountLabel: UILabel!
    var seenDot: UIImageView!
    var tapArea: UIButton!
    
    func setUp(friendRequestCount: Int) {
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        
        resetCell()
        
        friendRequestsLabel = UILabel(frame: CGRect(x: 10, y: 17.5, width: 200, height: 15))
        friendRequestsLabel.text = "Friend Requests"
        friendRequestsLabel.font = UIFont(name: "SFCamera-Regular", size: 14)
        friendRequestsLabel.textColor = .white
        friendRequestsLabel.textAlignment = .left
        self.addSubview(friendRequestsLabel)
        
        friendRequestCountLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 30, y: 20, width: 15, height: 10))
        friendRequestCountLabel.font = UIFont(name: "SFCamera-Semibold", size: 14)
        friendRequestCountLabel.textColor = .white
        friendRequestCountLabel.text = String(friendRequestCount)
        self.addSubview(friendRequestCountLabel)
        
        seenDot = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width - 45, y: 21, width: 12, height: 12))
        let greenActive = UIImage(named: "GreenActiveDot") ?? UIImage()
        seenDot.image = greenActive
        self.addSubview(seenDot)
        
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
    
    func resetCell() {
        if friendRequestsLabel != nil { friendRequestsLabel.text = "" }
        if friendRequestCountLabel != nil { friendRequestCountLabel.text = "" }
        if seenDot != nil { seenDot.image = UIImage() }
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
