//
//  FeedViewController.swift
//  Spot
//
//  Created by kbarone on 2/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import Geofirestore
import FirebaseUI

class FeedViewController: UIViewController {
    
    var activityIndicator: CustomActivityIndicator!
    var postsList: [MapPost] = []
    var selectedPostIndex = 0
    var endDocument: DocumentSnapshot!
    var refresh: refreshStatus = .noRefresh
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    var listener1, listener2, listener3: ListenerRegistration!
    
    unowned var mapVC: MapViewController!
    var postVC: PostViewController!
    var tabBar: CustomTabBar!
    
    deinit {
        print("deinit feed")
    }
    
    enum refreshStatus {
        case yesRefresh
        case refreshing
        case noRefresh
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = ""
        view.tag = 16
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: 40))
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditPost(_:)), name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] notification in
            ///stop indicator freeze after view enters background
            resumeIndicatorAnimation()
        }
        
        if let customTab = self.parent as? CustomTabBar { tabBar = customTab }
        if let map = tabBar.parent as? MapViewController { mapVC = map }
    }

    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        resumeIndicatorAnimation()
        if postVC != nil { checkForNewPosts() }
    }
        
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    @objc func notifyIndexChange(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            
            if let index = info["index"] as? Int {
                guard let id = info["id"] as? String else { return }
                if postVC != nil && id != postVC.vcid { return }
                
                /// refresh if current postIndex > 2 in the current refresh count and refresh hasn't been called  2 / 8 / 14
                /// comment / like update
                
                if let post = info["post"] as? MapPost { self.postsList[index] = post }
                
                if index > postsList.count - 4 && self.refresh == .yesRefresh {
                    
                    refresh = .refreshing
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else { return }
                        self.getPosts(refresh: false) }
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            postsList.insert(newPost, at: 0)
            if postVC != nil {
                postVC.postsList = self.postsList
                self.mapVC.postsList = self.postsList
                if postVC.tableView != nil { postVC.tableView.reloadData() }
                self.scrollToFirstRow()
            }
        }
    }
    
    @objc func notifyEditPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            // post edited from post page
            if let index = self.postsList.firstIndex(where: {$0.id == newPost.id}) {
                self.postsList[index] = newPost
                if postVC != nil {
                    mapVC.postsList = self.postsList
                    postVC.postsList = self.postsList
                    postVC.tableView.reloadData()
                }
            }
        } else if let info = sender.userInfo as? [String: Any] {
            // spot level info changed
            guard let postID = info["postID"] as? String else { return }
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                self.postsList[index].spotName = info["spotName"] as? String ?? ""
                self.postsList[index].inviteList = info["inviteList"] as? [String] ?? []
                self.postsList[index].spotLat = info["spotLat"] as? Double ?? 0.0
                self.postsList[index].spotLong = info["spotLong"] as? Double ?? 0.0
                self.postsList[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                if postVC != nil {
                    mapVC.postsList = self.postsList
                    postVC.postsList = self.postsList
                    postVC.tableView.reloadData()
                }
            }
        }
    }
    
    @objc func notifyDeletePost(_ sender: NSNotification) {
        
        if let postID = sender.userInfo?.first?.value as? String {
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                
                postsList.remove(at: index)
                postsList.sort(by: {$0.seconds > $1.seconds})
                
                if postVC != nil {

                    postVC.postsList = self.postsList
                    postVC.tableView.deleteRows(at: [IndexPath(row: postVC.selectedPostIndex, section: 0)], with: .bottom)

                    mapVC.postsList = self.postsList
                    
                    let mapPass = ["selectedPost": self.postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed] as [String : Any]
                    NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                }
            }
        }
    }
    
    func resumeIndicatorAnimation() {
        if self.activityIndicator != nil && !self.activityIndicator.isHidden {
            DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        }
    }
    
    func checkForNewPosts() {
        getPosts(refresh: true)
    }
    
    func getPosts(refresh: Bool) {
        
        /// the only problem with using endDocument is that it stops listening for new documents from docs that have already loaded which kind of defeats the purpose of using an active listener. checkForNewPosts() is a patch fix that checks the earliest posts for changes. Better solution needed
        
        var query = db.collection("posts").order(by: "timestamp", descending: true)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument) }
        
        self.listener1 = query.addSnapshotListener(includeMetadataChanges: true, listener: { (snap, err) in
            
            guard let docs = snap?.documents else {
                return
            }
            var dispatchIndex = 1
            
            for doc in docs {

                /// at the end of the query, noRefresh to avoid future calls
                if docs.count < 6 {
                    self.refresh = .noRefresh
                }

                if dispatchIndex > 6 {
                    if !refresh { self.endDocument = doc }
                    if self.refresh == .noRefresh { self.refresh = .yesRefresh }
                    return
                }
                
                do {
                    
                    let postInfo = try doc.data(as: MapPost.self)
                    guard var info = postInfo else { return }
                    
                    info.seconds = info.timestamp.seconds
                    info.id = doc.documentID
                    
                    let lowFriends = self.mapVC.friendIDs.count < 3 && self.mapVC.adminIDs.contains(info.posterID)
                    
                    // check that user has access
                    
                    if info.posterID != self.uid {
                        
                        switch info.privacyLevel {
                        
                        case "invite":
                            if !(info.inviteList?.contains(where: {$0 == self.uid}) ?? false) { continue }
                            
                        default:
                            if !self.mapVC.friendIDs.contains(where: {$0 == info.posterID}) && !lowFriends { continue }
                        }
                    }
                    
                    dispatchIndex += 1
                                        
                    /// get user from users friends list because every user in feed will be a friend
                    if let user = self.mapVC.friendsList.first(where: {$0.id == info.posterID}) {
                        info.userInfo = user
                    } else if info.posterID == self.uid {
                        info.userInfo = self.mapVC.userInfo
                    }
                    
                    // fetch comments
                    var commentList: [MapComment] = []
                    
                    self.listener3 = self.db.collection("posts").document(info.id!).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (commentSnap, err) in
                        
                        guard let self = self else { return }
                        if err != nil { return }

                        for doc in commentSnap!.documents {
                            do {
                                
                                let commInfo = try doc.data(as: MapComment.self)
                                guard var commentInfo = commInfo else { continue }
                                
                                commentInfo.id = doc.documentID
                                commentInfo.seconds = commentInfo.timestamp.seconds
                                commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                                
                                if !commentList.contains(where: {$0.id == doc.documentID}) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: {$0.seconds < $1.seconds})
                                }

                                let docCount = commentSnap!.documents.count
                                let commentCount = commentList.count

                                if commentCount >= docCount {
                                    info.commentList = commentList
                                    self.loadPostToFeed(post: info)
                                }

                            } catch {
                                continue
                            }
                        }
                    })
                } catch { continue }
            }
        })
    }
    
    func loadPostToFeed(post: MapPost) {
        
        self.refresh = .yesRefresh
        
        if !self.postsList.contains(where: {$0.id == post.id}) {

            if mapVC.deletedPostIDs.contains(post.id ?? "") { return }

            self.postsList.append(post)
            self.postsList.sort(by: {$0.seconds > $1.seconds})
                        
            if self.postsList.count == 1 { self.mapVC.checkForFeedTutorial() }
            
            if self.postVC != nil {
                let originalPostCount = self.postVC.postsList.count
                
                /// don't want to set postslist once postsVC is already active because it'll reset selected image index
                self.postVC.postsList = self.postsList
                
                if self.tabBar.selectedIndex == 0 && self.postVC.children.count == 0 {
                    self.mapVC.postsList = self.postVC.postsList }
                
                if self.postVC.tableView != nil {
                    if originalPostCount == self.postVC.selectedPostIndex {
                        /// send notification to map to animate to new post if its on the loading page
                        
                        let mapPass = ["selectedPost": self.postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed] as [String : Any]
                        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                    }
                    self.postVC.tableView.reloadData()
                }
                
            } else {
                self.activityIndicator.stopAnimating()
                self.addPostAsChild()
            }
        } else {
            
            /// already contains post - active listener found a change, probably a comment or like
            if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {

                self.postsList[index] = post

                if let postVC = self.children.first as? PostViewController {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                        
                        let selectedIndex = postVC.postsList[index].selectedImageIndex
                        self.postsList[index].selectedImageIndex = selectedIndex

                        postVC.postsList[index] = post
                        postVC.postsList[index].selectedImageIndex = selectedIndex
                    }
                    
                    if postVC.tableView != nil { postVC.tableView.reloadData() }
                }
            }
        }
    }

    
    func addPostAsChild() {
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            vc.postsList = self.postsList
            vc.selectedPostIndex = self.selectedPostIndex
            vc.mapVC = self.mapVC
            vc.parentVC = .feed
            
            postVC = vc
            
            vc.view.frame = UIScreen.main.bounds
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.didMove(toParent: self)
            
            if self.tabBar.selectedIndex == 0 {
                self.mapVC.postsList = self.postsList
                let infoPass = ["selectedPost": self.selectedPostIndex, "firstOpen": true, "parentVC":  PostViewController.parentViewController.feed] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            }
        }
    }
    
    func scrollToFirstRow() {
        if postVC != nil {
            if postVC.tableView != nil {
                
                if postVC.tableView.numberOfRows(inSection: 0) == 0 { return }
                
                DispatchQueue.main.async {
                    self.postVC.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    self.postVC.openDrawer()
                }
                
                self.selectedPostIndex = 0
                postVC.selectedPostIndex = 0
                let infoPass = ["selectedPost": 0, "firstOpen": true, "parentVC":  PostViewController.parentViewController.feed] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            }
        }
    }
}
