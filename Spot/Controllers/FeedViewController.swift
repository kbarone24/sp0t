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
    var refresh: refreshStatus = .refreshing
    
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
        self.navigationItem.title = ""
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
    }
        
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    @objc func notifyIndexChange(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            
            if let index = info["index"] as? Int {
                
                self.selectedPostIndex = index
                guard let id = info["id"] as? String else { return }
                if postVC != nil && id != postVC.vcid { return }
                
                /// refresh if current postIndex > 2 in the current refresh count and refresh hasn't been called  2 / 8 / 14
                /// comment / like update
                
                if let post = info["post"] as? MapPost { self.postsList[index] = post }
                
                if index > (postsList.count - 4) && self.refresh == .yesRefresh {
                    print("refreshing")
                    refresh = .refreshing
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else { return }
                        self.getFriendPosts(refresh: false) }
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
        
        mapVC.tutorialMode = false /// remove tutorial on users first post
        
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            postsList.insert(newPost, at: 0)
            
            if postVC != nil {
                
                /// add pullLine and image / row change notifications on first post
                if postVC.tutorialMode || postVC.postsEmpty {
                    postVC.addPullLineAndNotifications()
                    postVC.tutorialMode = false
                    postVC.postsEmpty = false
                }
                
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
        
        var indexPaths: [IndexPath] = []

        if let postIDs = sender.userInfo?.first?.value as? [String] {
            
            if postVC != nil {
                /// seperate loop for postvc postslist just in case it doesnt match the feeds postslist during reload
                for id in postIDs {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == id}) {
                        indexPaths.append(IndexPath(row: index, section: 0))
                    }
                }
            }
            
            /// looping through these twice kind of sucks but i dont know how to account for the indexes changing upon removing a post
            for id in postIDs {
                if let index = self.postsList.firstIndex(where: {$0.id == id}) {
                    postsList.remove(at: index)
                    postsList.sort(by: {$0.seconds > $1.seconds})
                }
            }
                    
            if postVC != nil {

                /// avoid double refresh
                postVC.postsList = self.postsList
                mapVC.postsList = self.postsList

                postVC.tableView.beginUpdates()
                postVC.tableView.deleteRows(at: indexPaths, with: .bottom)
                postVC.tableView.endUpdates()
                
                if postVC.selectedPostIndex >= postVC.postsList.count {
                    if postVC.postsList.count == 0 { postVC.postsEmpty = true; postVC.tableView.reloadData(); return }
                    postVC.selectedPostIndex = max(0, postVC.postsList.count - 1)
                    postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: true)
                    postVC.tableView.reloadData()
                }

                let mapPass = ["selectedPost": self.postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
            }
        }
    }
    
    func resumeIndicatorAnimation() {
        if self.activityIndicator != nil && !self.activityIndicator.isHidden {
            DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        }
    }
    
    
    func getFriendPosts(refresh: Bool) {
        
        var query = db.collection("posts").order(by: "timestamp", descending: true).whereField("friendsList", arrayContains: self.uid).limit(to: 11)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument) }

        self.listener1 = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (snap, err) in
        
            guard let self = self else { return }
            guard let longDocs = snap?.documents else { return }
            
            if longDocs.count < 11 && !(snap?.metadata.isFromCache ?? false) {
                self.refresh = .noRefresh
            } else {
                self.endDocument = longDocs.last
            }
            
            if longDocs.count == 0 && self.postsList.count == 0 { self.addEmptyState(tutorialMode: false) }
            
            var localPosts: [MapPost] = []
            var index = 0
            
            let docs = self.refresh == .noRefresh ? longDocs : longDocs.dropLast() /// drop last doc to get exactly 10 posts for reload unless under 10 posts fetched
            
            for doc in docs {
                
                do {
                
                let postIn = try doc.data(as: MapPost.self)
                guard var postInfo = postIn else { index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts)}; continue }
                
                    postInfo.seconds = postInfo.timestamp.seconds
                    postInfo.id = doc.documentID
                
                if let user = self.mapVC.friendsList.first(where: {$0.id == postInfo.posterID}) {
                    postInfo.userInfo = user
                    
                } else if postInfo.posterID == self.uid {
                    postInfo.userInfo = self.mapVC.userInfo
                }
                    
                    var commentList: [MapComment] = []
                    self.listener2 = self.db.collection("posts").document(postInfo.id!).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener({ [weak self] (commentSnap, err) in
                        
                        guard let self = self else { return }
                        if err != nil { index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts)}; return }
                        
                        if commentSnap!.documents.count == 0 { index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts) }}
                        
                        for doc in commentSnap!.documents {
                            do {
                                
                                let commInfo = try doc.data(as: MapComment.self)
                                guard var commentInfo = commInfo else { if doc == commentSnap!.documents.last { index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts) }}; continue }
                                
                                commentInfo.id = doc.documentID
                                commentInfo.seconds = commentInfo.timestamp.seconds
                                commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                                
                                if !commentList.contains(where: {$0.id == doc.documentID}) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: {$0.seconds < $1.seconds})
                                }

                                if doc == commentSnap!.documents.last {
                                    
                                    postInfo.commentList = commentList
                                    localPosts.append(postInfo)
                                    
                                    index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts) }}
                                
                            } catch {
                                if doc == commentSnap!.documents.last { index += 1; if index == docs.count { self.loadPostsToFeed(posts: localPosts) }; continue }
                            }
                        }
                    })

                } catch {
                    index += 1
                    if index == docs.count { self.loadPostsToFeed(posts: localPosts)}
                    continue
                }
            }
        })
    }
    
    func checkForNewPosts() {
        getFriendPosts(refresh: true)
    }
    
    func loadPostsToFeed(posts: [MapPost]) {

        for post in posts {
            
            var scrollToFirstRow = false

            if !postsList.contains(where: {$0.id == post.id}) {
                
                if !mapVC.deletedPostIDs.contains(post.id ?? "") {

                    let newPost = postsList.count > 10 && post.timestamp.seconds > postsList.first?.timestamp.seconds ?? 100000000000

                    if !newPost {
                        postsList.append(post)
                        postsList.sort(by: {$0.seconds > $1.seconds})
                        
                    } else {

                        /// insert at 0 if at the of the feed (usually a new load), insert at post + 1 otherwise
                        if postVC.selectedPostIndex == 0 {
                            scrollToFirstRow = true
                            postsList.insert(post, at: 0)
                            
                        } else {
                            postsList.insert(post, at: postVC.selectedPostIndex + 1)
                        }
                    }
                }
                
               if post.id == posts.last?.id {
                
                    if postVC != nil {
                        
                        
                        let originalPostCount = self.postVC.postsList.count
                        
                        postVC.postsList = postsList
                        if tabBar.selectedIndex == 0 && postVC.children.count == 0 {
                            mapVC.postsList = postVC.postsList }
                        
                        if originalPostCount == postVC.selectedPostIndex {
                            /// send notification to map to animate to new post annotation if its on the loading page
                            
                            DispatchQueue.main.async {
                                let mapPass = ["selectedPost": self.postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed] as [String : Any]
                                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass) }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        
                        /// add post as child or reload tableview with new posts
                        if self.postVC == nil {
                            self.activityIndicator.stopAnimating()
                            self.addPostAsChild()
                            if posts.count > 1 { self.mapVC.checkForFeedTutorial() } /// check for swipe tutorial on the 2nd post so user has actions to take
                            if self.refresh != .noRefresh { self.refresh = .yesRefresh }

                        } else if self.postVC.tableView != nil {
                            self.checkTutorialRemove() /// check if need to remove tutorialView
                            self.postVC.tableView.reloadData()
                            self.postVC.tableView.performBatchUpdates(nil, completion: {
                                (result) in
                                if scrollToFirstRow { self.scrollToFirstRow() }
                                if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                            })
                        }
                    }
                }
                
            } else {
                
                /// already contains post - active listener found a change, probably a comment or like
                if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {

                    let selected0 = postsList[index].selectedImageIndex
                    self.postsList[index] = post
                    self.postsList[index].selectedImageIndex = selected0
                    
                    if let postVC = children.first as? PostViewController {
                        
                        /// account for possiblity of postslist / postvc.postslist not matching up
                        if let postIndex = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                                                        
                            let selected1 = postVC.postsList[postIndex].selectedImageIndex
                            postVC.postsList[postIndex] = post
                            postVC.postsList[postIndex].selectedImageIndex = selected1
                        
                            if post.id == posts.last?.id {

                                if postVC.tableView != nil {
                                    DispatchQueue.main.async { self.postVC.tableView.reloadData() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkTutorialRemove() {
        if postVC.tutorialMode || postVC.postsEmpty {
            postVC.addPullLineAndNotifications()
            postVC.tutorialMode = false
            postVC.postsEmpty = false
        }
    }
    
    func addEmptyState(tutorialMode: Bool) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            vc.selectedPostIndex = 0
            vc.mapVC = self.mapVC
            vc.parentVC = .feed
            vc.tutorialMode = tutorialMode
            vc.postsEmpty = !tutorialMode
            
            postVC = vc
            
            vc.view.frame = UIScreen.main.bounds
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.didMove(toParent: self)

        }

    }

    func addPostAsChild() {

        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            vc.postsList = self.postsList
            vc.selectedPostIndex = self.selectedPostIndex
            vc.mapVC = self.mapVC
            vc.parentVC = .feed

            mapVC.toggleMapTouch(enable: true)
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
            
            if postsList.count < 2 { return }
            
            if postVC.tableView != nil {
                
                if postVC.tableView.numberOfRows(inSection: 0) == 0 { return }
                
                DispatchQueue.main.async {
                    self.postVC.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    self.postVC.openDrawer(swipe: true)
                }
                
                self.selectedPostIndex = 0
                postVC.selectedPostIndex = 0
                let infoPass = ["selectedPost": 0, "firstOpen": true, "parentVC":  PostViewController.parentViewController.feed] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            }
        }
    }
}
