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
import Mixpanel

class FeedViewController: UIViewController {
    
    var friendPosts: [MapPost] = []
    var nearbyPostIndex = 0
    var friendsPostIndex = 0
    var selectedPostIndex = 0
    var selectedSegmentIndex = 0
    var feedSegBlur: UIImageView!
    var feedSeg: UIView!
    var friendsSegment: UIButton!
    var nearbySegment: UIButton!
    var selectedSegmentHighlight: UIView!
    
    var nearbyPosts: [MapPost] = []
    var nearbyEnteredCount = 0
    var noAccessCount = 0
    var nearbyEscapeCount = 0
    var currentNearbyPosts: [MapPost] = [] /// keep track of posts for the current circleQuery to reload all at once
    var activeRadius = 0.5
    var circleQuery: GFSCircleQuery?

    var endDocument: DocumentSnapshot!
    var activityIndicator: CustomActivityIndicator!
    var refresh: refreshStatus = .refreshing
    var friendsRefresh: refreshStatus = .yesRefresh
    var nearbyRefresh: refreshStatus = .yesRefresh
    var queryReady = false /// circlequery returned
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    var listener1, listener2, listener3, listener4, listener5: ListenerRegistration!
    
    unowned var mapVC: MapViewController!
    var postVC: PostViewController!
    var tabBar: CustomTabBar!
        
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
        checkForLocationChange() /// check if user location changed for nearby feed
    }
        
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    @objc func notifyIndexChange(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            
            if let index = info["index"] as? Int {
                                
                guard let id = info["id"] as? String else { return }
                if postVC != nil && id != postVC.vcid { return }
                
                self.selectedPostIndex = index
                if selectedSegmentIndex == 0 { friendsPostIndex = index } else { nearbyPostIndex = index }
                
                let activePosts = selectedSegmentIndex == 0 ? friendPosts : nearbyPosts
                
                /// comment / like update
                if let post = info["post"] as? MapPost { if selectedSegmentIndex == 0 { friendPosts[index] = post } else { nearbyPosts[index] = post } }
                
                if index > (activePosts.count - 4) && self.refresh == .yesRefresh {
                    if selectedSegmentIndex == 0 { friendsRefresh = .refreshing } else { nearbyRefresh = .refreshing }
                    refresh = .refreshing
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else { return }
                        if self.selectedSegmentIndex == 0 { self.getFriendPosts(refresh: false) } else if self.activeRadius < 1000 { self.activeRadius *= 2; self.getNearbyPosts(radius: self.activeRadius) }
                    }
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
                
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            
            if !newPost.friendsList.contains(uid) { return }
            friendPosts.insert(newPost, at: 0)
            
            if postVC != nil {
                postVC.postsEmpty = false
                switchToFriendsSegment()
                openOrScrollToFirst(animated: true, newPost: true)
            }
        }
    }
    
    @objc func notifyEditPost(_ sender: NSNotification) {
        
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            // post edited from post page
            if let index = self.friendPosts.firstIndex(where: {$0.id == newPost.id}) {
                self.friendPosts[index] = newPost
                if postVC != nil && selectedPostIndex == 0 {
                    mapVC.postsList = self.friendPosts
                    postVC.postsList = self.friendPosts
                    if postVC.tableView != nil { postVC.tableView.reloadData() }
                }
            }
            
            if let index = self.nearbyPosts.firstIndex(where: {$0.id == newPost.id}) {
                self.nearbyPosts[index] = newPost
                if postVC != nil && selectedPostIndex == 1 {
                    mapVC.postsList = self.nearbyPosts
                    postVC.postsList = self.nearbyPosts
                    if postVC.tableView != nil { postVC.tableView.reloadData() }
                }
            }
            
        } else if let info = sender.userInfo as? [String: Any] {
            // spot level info changed
            guard let postID = info["postID"] as? String else { return }
            if let index = self.friendPosts.firstIndex(where: {$0.id == postID}) {
                self.friendPosts[index].spotName = info["spotName"] as? String ?? ""
                self.friendPosts[index].inviteList = info["inviteList"] as? [String] ?? []
                self.friendPosts[index].spotLat = info["spotLat"] as? Double ?? 0.0
                self.friendPosts[index].spotLong = info["spotLong"] as? Double ?? 0.0
                self.friendPosts[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                if postVC != nil && selectedPostIndex == 0 {
                    mapVC.postsList = self.friendPosts
                    postVC.postsList = self.friendPosts
                    postVC.tableView.reloadData()
                }
            }
            
            if let index = self.nearbyPosts.firstIndex(where: {$0.id == postID}) {
                self.nearbyPosts[index].spotName = info["spotName"] as? String ?? ""
                self.nearbyPosts[index].inviteList = info["inviteList"] as? [String] ?? []
                self.nearbyPosts[index].spotLat = info["spotLat"] as? Double ?? 0.0
                self.nearbyPosts[index].spotLong = info["spotLong"] as? Double ?? 0.0
                self.nearbyPosts[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                if postVC != nil && selectedPostIndex == 1 {
                    mapVC.postsList = self.nearbyPosts
                    postVC.postsList = self.nearbyPosts
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
                
                if let index = self.friendPosts.firstIndex(where: {$0.id == id}) {
                    friendPosts.remove(at: index)
                    friendPosts.sort(by: {$0.seconds > $1.seconds})
                }

                if let index = self.nearbyPosts.firstIndex(where: {$0.id == id}) {
                    nearbyPosts.remove(at: index)
                }
                
                /// really should be matching this up with the active segment but due to discrepancies between active posts and postvc.postsList reload this is the best way for now
                if postVC != nil {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == id}) {
                        postVC.postsList.remove(at: index)
                    }
                }
            }
            
                    
            if postVC != nil {

                mapVC.postsList = postVC.postsList
                if postVC.tableView == nil { return } /// i think crash happening on logged out account views still existing in the background
                
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
                self.friendsRefresh = .noRefresh
                if self.selectedSegmentIndex == 0 { self.refresh = .noRefresh }
            } else {
                self.endDocument = longDocs.last
            }
            
            if longDocs.count == 0 && self.friendPosts.count == 0 { self.addEmptyState() }
                        
            var localPosts: [MapPost] = [] /// just the 10 posts for this fetch
            var index = 0
            
            let docs = self.friendsRefresh == .noRefresh ? longDocs : longDocs.dropLast() /// drop last doc to get exactly 10 posts for reload unless under 10 posts fetched

            for doc in docs {
                
                do {
                
                let postIn = try doc.data(as: MapPost.self)
                guard var postInfo = postIn else { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}; continue }
                
                    postInfo.seconds = postInfo.timestamp.seconds
                    postInfo.id = doc.documentID
                
                if let user = self.mapVC.friendsList.first(where: {$0.id == postInfo.posterID}) {
                    postInfo.userInfo = user
                    
                } else if postInfo.posterID == self.uid {
                    postInfo.userInfo = self.mapVC.userInfo
                    
                } else {
                    /// friend not in users friendslist, might have removed them as a friend
                    index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}; continue
                }
                    
                    var commentList: [MapComment] = []
                    self.listener2 = self.db.collection("posts").document(postInfo.id!).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener({ [weak self] (commentSnap, err) in
                        
                        guard let self = self else { return }
                        if err != nil { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}; return }
                        
                        if commentSnap!.documents.count == 0 { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }}
                        
                        for doc in commentSnap!.documents {
                            do {
                                
                                let commInfo = try doc.data(as: MapComment.self)
                                guard var commentInfo = commInfo else { if doc == commentSnap!.documents.last { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }}; continue }
                                
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
                                    
                                    index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }}
                                
                            } catch {
                                if doc == commentSnap!.documents.last { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }; continue }
                            }
                        }
                    })

                } catch {
                    index += 1
                    if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}
                    continue
                }
            }
        })
    }
    
    func loadFriendPostsToFeed(posts: [MapPost]) {

        for post in posts {
            
            if !friendPosts.contains(where: {$0.id == post.id}) {
                
                var scrollToFirstRow = false
                
                if !mapVC.deletedPostIDs.contains(post.id ?? "") {

                    let newPost = friendPosts.count > 10 && post.timestamp.seconds > friendPosts.first?.timestamp.seconds ?? 100000000000

                    if !newPost {
                        friendPosts.append(post)
                        friendPosts.sort(by: {$0.seconds > $1.seconds})
                        
                    } else {
                        /// insert at 0 if at the of the feed (usually a new load), insert at post + 1 otherwise
                        
                        friendPosts.insert(post, at: 0)
                        if postVC != nil { scrollToFirstRow = postVC.selectedPostIndex == 0 }
                    }
                }
                
               if post.id == posts.last?.id {
                if selectedSegmentIndex == 0 {
                    if postVC != nil {
                        
                        let originalPostCount = self.postVC.postsList.count
                        if originalPostCount == 0 { scrollToFirstRow = true }
                        
                        postVC.postsList = friendPosts

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
                            if posts.count > 1 { self.mapVC.checkForTutorial(index: 0) } /// check for swipe tutorial on the 2nd post so user has actions to take
                            if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                            if self.friendsRefresh != .noRefresh { self.friendsRefresh = .yesRefresh }

                        } else if self.postVC.tableView != nil {
                            self.checkTutorialRemove() /// check if need to remove tutorialView
                            self.postVC.tableView.reloadData()
                            self.postVC.tableView.performBatchUpdates(nil, completion: {
                                (result) in
                                if scrollToFirstRow { self.openOrScrollToFirst(animated: false, newPost: true) }
                                if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                                if self.friendsRefresh != .noRefresh { self.friendsRefresh = .yesRefresh }
                                self.activityIndicator.stopAnimating()
                            })
                        }
                    }
                    /// segment switch during reload
                } else { if self.friendsRefresh != .noRefresh { self.friendsRefresh = .yesRefresh } }
               }
                
            } else {
                
                /// already contains post - active listener found a change, probably a comment or like
                if let index = self.friendPosts.firstIndex(where: {$0.id == post.id}) {

                    let selected0 = friendPosts[index].selectedImageIndex
                    self.friendPosts[index] = post
                    self.friendPosts[index].selectedImageIndex = selected0
                    
                    if let postVC = children.first as? PostViewController, selectedSegmentIndex == 0 {
                        
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
    
    func getNearbyPosts(radius: Double) {

        nearbyEnteredCount = 0; currentNearbyPosts.removeAll(); noAccessCount = 0; nearbyEscapeCount = 0 /// reset counters to quickly check for post access on each query

        let geoFire = GeoFirestore(collectionRef: Firestore.firestore().collection("posts"))
        
        /// instantiate or update radius for circleQuery
        if circleQuery == nil {
            circleQuery = geoFire.query(withCenter: GeoPoint(latitude: mapVC.currentLocation.coordinate.latitude, longitude: mapVC.currentLocation.coordinate.longitude), radius: radius)
            ///circleQuery?.searchLimit = 500
            let _ = circleQuery?.observe(.documentEntered, with: loadPostFromDB)
            
            let _ = circleQuery?.observeReady {
                self.queryReady = true
                if self.nearbyEnteredCount == 0 && self.activeRadius < 1024 {
                    self.activeRadius *= 2; self.getNearbyPosts(radius: self.activeRadius)
                } else { self.accessEscape() }
            }
            
        } else {
            
            queryReady = false
            circleQuery?.removeAllObservers()
            circleQuery?.radius = radius
            circleQuery?.center = mapVC.currentLocation

            let _ = circleQuery?.observe(.documentEntered, with: loadPostFromDB)
            let _ = circleQuery?.observeReady {
                self.queryReady = true
                if self.nearbyEnteredCount == 0 && self.activeRadius < 1024 {
                    self.activeRadius *= 2; self.getNearbyPosts(radius: self.activeRadius)
                } else { self.accessEscape() }
            }
        }
    }
    
    func loadPostFromDB(key: String?, location: CLLocation?) {

        guard let postKey = key else { return }
        
        nearbyEnteredCount += 1
        var escaped = false /// variable denotes whether to increment noAccessCount (whether active listener found change or this is a new post entering)
        
        let ref = db.collection("posts").document(postKey)
        listener5 = ref.addSnapshotListener({ [weak self] (doc, err) in
            
            guard let self = self else { return }

            do {
                /// get spot and check for access
                let postIn = try doc?.data(as: MapPost.self)
                guard var postInfo = postIn else { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return }
                if self.mapVC.deletedPostIDs.contains(where: {$0 == postKey}) { self.noAccessCount += 1; self.accessEscape(); return }
                
                postInfo.seconds = postInfo.timestamp.seconds
                postInfo.id = doc!.documentID
                
                if self.nearbyPosts.contains(where: {$0.id == postKey}) {
                    /// fetching new circle query form DB and this post is already there
                    if self.noAccessCount + self.currentNearbyPosts.count < self.nearbyEnteredCount { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return
                    } else {
                    /// active listener found a change
                        self.updateNearbyPostFromDB(post: postInfo); return
                    }
                }
                
                if !self.hasPostAccess(post: postInfo, mapVC: self.mapVC) { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return }
                
                /// fix for current nearby posts growing too big - possibly due to active listener finding a change? this is all happening inside the listener closure so just update post object if necessary, don't need to increment and escape like above
                if !self.currentNearbyPosts.contains(where: {$0.id == postInfo.id}) { self.currentNearbyPosts.append(postInfo) }
                else if let i = self.currentNearbyPosts.firstIndex(where: {$0.id == postInfo.id }) { self.currentNearbyPosts[i] = postInfo; if !escaped { self.noAccessCount += 1 }; escaped = true; }
                self.accessEscape()
                
            } catch { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return }
        })
    }
    
    /// update post in nearbyPosts when change made from
    func updateNearbyPostFromDB(post: MapPost) {
        
        if let i = nearbyPosts.firstIndex(where: {$0.id == post.id}) {
            let userInfo = nearbyPosts[i].userInfo
            let postScore = nearbyPosts[i].postScore
            nearbyPosts[i] = post
            nearbyPosts[i].userInfo = userInfo /// not fetching user info again so need to set it manually
            nearbyPosts[i].postScore = postScore /// not fetching post score again so need to set it manually
        }
        
        /// if nearby posts currently selected, update post in postsTable
        if selectedSegmentIndex == 1, postVC != nil, postVC.tableView != nil {
            if let i = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                let userInfo = postVC.postsList[i].userInfo
                let postScore = nearbyPosts[i].postScore
                postVC.postsList[i] = post
                postVC.postsList[i].userInfo = userInfo /// not fetching user info again so need to set it manually
                postVC.postsList[i].postScore = postScore /// not fetching post score again so need to set it manually
                DispatchQueue.main.async { self.postVC.tableView.reloadData() }
            }
        }
        
        getNearbyComments(postID: post.id!, refresh: true)
    }
    
    func updateNearbyPostComments(comments: [MapComment], postID: String) {
        if let i = nearbyPosts.firstIndex(where: {$0.id == postID}) {
            nearbyPosts[i].commentList = comments
            if selectedSegmentIndex == 1, postVC != nil, postVC.tableView != nil {
                if let i = postVC.postsList.firstIndex(where: {$0.id == postID}) {
                    postVC.postsList[i].commentList = comments
                    DispatchQueue.main.async { self.postVC.tableView.reloadData() }
                }
            }
        }
    }

    func accessEscape() {
        if noAccessCount + currentNearbyPosts.count == nearbyEnteredCount && queryReady {
            if currentNearbyPosts.count < 10 && activeRadius < 1000 { /// force reload if active radius reaches 1024
               activeRadius *= 2; getNearbyPosts(radius: activeRadius)
            } else {
                self.getNearbyUserInfo()
            }
        }
    }
    
    func getNearbyUserInfo() {
        
        for i in 0...currentNearbyPosts.count - 1 {
            
            let post = currentNearbyPosts[i]
            
            if let user = self.mapVC.friendsList.first(where: {$0.id == post.posterID}) {
                currentNearbyPosts[i].userInfo = user
                getNearbyComments(postID: post.id!, refresh: false)
                
            } else if post.posterID == self.uid {
                currentNearbyPosts[i].userInfo = self.mapVC.userInfo
                getNearbyComments(postID: post.id!, refresh: false)
                
            } else {
                
                var userLeaveCalled = false
                
                self.listener4 = self.db.collection("users").document(post.posterID).addSnapshotListener({  [weak self] (userSnap, err) in
                    
                    guard let self = self else { return }
                    
                    if err == nil {
                        do {
                            let profInfo = try userSnap?.data(as: UserProfile.self)
                            guard var prof = profInfo else { self.nearbyEscape(); return }
                            
                            prof.id = userSnap?.documentID
                            self.currentNearbyPosts[i].userInfo = prof

                            if !userLeaveCalled {
                                userLeaveCalled = true
                                self.getNearbyComments(postID: post.id!, refresh: false)
                            }
                            
                        } catch { self.nearbyEscape(); return }
                    } else { self.nearbyEscape(); return }
                })
            }
        }
    }
    
    func getNearbyComments(postID: String, refresh: Bool) {
        
        guard let i = currentNearbyPosts.firstIndex(where: {$0.id == postID}) else { nearbyEscape(); return }
        let info = currentNearbyPosts[i]
        
        var commentList: [MapComment] = []
        var commentCount = 0

        let commentRef = self.db.collection("posts").document(info.id!).collection("comments").order(by: "timestamp", descending: true)

        self.listener3 = commentRef.addSnapshotListener({ [weak self] (commentSnap, err) in
            
            guard let self = self else { return }
            
            let docCount = commentSnap!.documents.count
            if docCount == 0 { if refresh { self.updateNearbyPostComments(comments: commentList, postID: postID); return }; self.nearbyEscape(); return }
            
            for doc in commentSnap!.documents {
                
                do {

                    let commInfo = try doc.data(as: MapComment.self)
                    guard var commentInfo = commInfo else { commentCount += 1; if commentCount == docCount {
                        if refresh { self.updateNearbyPostComments(comments: commentList, postID: postID); continue }; self.currentNearbyPosts[i].commentList = commentList; self.nearbyEscape() }; continue }
                    
                    commentInfo.id = doc.documentID
                    commentInfo.seconds = commentInfo.timestamp.seconds
                    commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)
                    
                    if !commentList.contains(where: {$0.id == doc.documentID}) {
                        commentList.append(commentInfo)
                        commentList.sort(by: {$0.seconds < $1.seconds})
                    }
                    
                    commentCount += 1; if commentCount == docCount {
                        if refresh { self.updateNearbyPostComments(comments: commentList, postID: postID); return  }
                        self.currentNearbyPosts[i].commentList = commentList
                        self.nearbyEscape()
                    }

                } catch {
                    
                    commentCount += 1; if commentCount == docCount {
                        if refresh { self.updateNearbyPostComments(comments: commentList, postID: postID); return  }
                        self.currentNearbyPosts[i].commentList = commentList
                        self.nearbyEscape()
                    }
                    continue
                }
            }
        })
    }
    
    func nearbyEscape() {
        /// check if got all posts + get spot rank + reload feed
        nearbyEscapeCount += 1
        if nearbyEscapeCount == currentNearbyPosts.count {
            for i in 0...currentNearbyPosts.count - 1 {
                currentNearbyPosts[i].postScore = getPostScore(post: currentNearbyPosts[i])
                if i == currentNearbyPosts.count - 1 { loadNearbyPostsToFeed() }
            }
        }
    }
    
    func getPostScore(post: MapPost) -> Double {
        
        var scoreMultiplier = 0.0
        
        let distance = max(CLLocation(latitude: post.postLat, longitude: post.postLong).distance(from: CLLocation(latitude: mapVC.currentLocation.coordinate.latitude, longitude: mapVC.currentLocation.coordinate.longitude)), 1)

        let postTime = Float(post.seconds)
        let current = NSDate().timeIntervalSince1970
        let currentTime = Float(current)
        let timeSincePost = currentTime - postTime

        /// add multiplier for recent posts
        let factor = Double(min(1 + (100000000 / timeSincePost), 2000))
        scoreMultiplier = Double(pow(factor, 3)) * 10

        /// content bonuses
        if mapVC.friendIDs.contains(post.posterID) { scoreMultiplier += 50 }
        
        for like in post.likers {
            scoreMultiplier += 20
            if mapVC.friendIDs.contains(like) { scoreMultiplier += 5 }
        }
        
        for comment in post.commentList {
            scoreMultiplier += 10
            if mapVC.friendIDs.contains(comment.commenterID) { scoreMultiplier += 2.5 }
        }
        
        return scoreMultiplier/distance
    }
    
    func loadNearbyPostsToFeed() {

        currentNearbyPosts.sort(by: {$0.postScore > $1.postScore})
        
        for post in currentNearbyPosts {
            
            if !nearbyPosts.contains(where: {$0.id == post.id}) {
                
                /// nil user info leaks through because nearby escape is called for an error on user fetch. itll be fine for nil comments but nil user is bad
                if post.userInfo != nil { nearbyPosts.append(post) }
                
                /// only update if active segment
                if post.id == currentNearbyPosts.last?.id {
                    
                    if selectedSegmentIndex == 1 {
                        var scrollToFirstRow = false
                        
                        if postVC != nil {
                            
                            let originalPostCount = self.postVC.postsList.count
                            scrollToFirstRow = originalPostCount == 0
                            
                            postVC.postsList = nearbyPosts
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
                                self.mapVC.checkForTutorial(index: 0)
                                if self.nearbyRefresh != .noRefresh { self.nearbyRefresh = .yesRefresh }
                                if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                                
                            } else if self.postVC.tableView != nil {
                                
                                /// activity indicator will only be animating on refresh, here we resort based on postscore
                                if self.activityIndicator.isAnimating() {
                                    for i in 0...self.nearbyPosts.count - 1 { self.nearbyPosts[i].postScore = self.getPostScore(post: self.nearbyPosts[i]) } /// update post scores on location change
                                    self.nearbyPosts.sort(by: {$0.postScore > $1.postScore})
                                    if self.selectedSegmentIndex == 1 { self.postVC.postsList = self.nearbyPosts }
                                    if self.tabBar.selectedIndex == 0 && self.postVC.children.count == 0 {
                                        self.mapVC.postsList = self.postVC.postsList }
                                    scrollToFirstRow = true
                                }
                                
                                self.postVC.tableView.reloadData()
                                self.postVC.tableView.performBatchUpdates(nil, completion: {
                                    (result) in
                                    self.activityIndicator.stopAnimating()
                                    if scrollToFirstRow { self.openOrScrollToFirst(animated: false, newPost: true) }
                                    self.mapVC.checkForTutorial(index: 0)
                                    if self.nearbyRefresh != .noRefresh { self.nearbyRefresh = .yesRefresh }
                                    if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                                })
                            }
                        }
                        
                    /// just update refresh index otherwise
                    } else { if self.nearbyRefresh != .noRefresh { self.nearbyRefresh = .yesRefresh } }
                }
                
            } else {
                
                if let index = self.nearbyPosts.firstIndex(where: {$0.id == post.id}) {

                    let selected0 = nearbyPosts[index].selectedImageIndex
                    self.nearbyPosts[index] = post
                    self.nearbyPosts[index].selectedImageIndex = selected0
                    
                    if let postVC = children.first as? PostViewController, selectedSegmentIndex == 1 {
                        
                        /// if this is the active segment 
                        if let postIndex = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                                                        
                            let selected1 = postVC.postsList[postIndex].selectedImageIndex
                            postVC.postsList[postIndex] = post
                            postVC.postsList[postIndex].selectedImageIndex = selected1
                        
                            if post.id == currentNearbyPosts.last?.id {

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
        postVC.postsEmpty = false
    }
    
    func addEmptyState() {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            vc.selectedPostIndex = 0
            vc.mapVC = self.mapVC
            vc.parentVC = .feed
            vc.postsEmpty = true
            
            postVC = vc
            
            vc.view.frame = UIScreen.main.bounds
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.didMove(toParent: self)
        }
    }

    func addPostAsChild() {

        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {

            let activePosts = selectedSegmentIndex == 0 ? friendPosts : nearbyPosts
            vc.postsList = activePosts
            vc.selectedPostIndex = self.selectedPostIndex
            vc.mapVC = self.mapVC
            vc.parentVC = .feed

            postVC = vc
            
            vc.view.frame = UIScreen.main.bounds
            self.addChild(vc)
            self.view.addSubview(vc.view)
            vc.didMove(toParent: self)
            
            if self.tabBar.selectedIndex == 0 {
                self.mapVC.postsList = activePosts
                let infoPass = ["selectedPost": self.selectedPostIndex, "firstOpen": true, "parentVC":  PostViewController.parentViewController.feed] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            }
        }
    }
    
    func openOrScrollToFirst(animated: Bool, newPost: Bool) {

        if postVC != nil {
            
            if postVC.postsList.count < 2 { return }

            if postVC.tableView != nil {
                if postVC.tableView.numberOfRows(inSection: 0) == 0 { return }
                
                DispatchQueue.main.async {
                    /// scroll to first row for new post or when drawer is already open 
                    if newPost || self.mapVC.prePanY < 200 {
                        self.scrollToFirstRow(animated: animated)
                        
                    } else if self.mapVC.prePanY > 200 {
                        self.postVC.openDrawer(swipe: false)
                    }
                }
            }
        }
    }
    
    func scrollToFirstRow(animated: Bool) {
        postVC.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
        selectedPostIndex = 0
        if selectedSegmentIndex == 0 { friendsPostIndex = 0 } else { nearbyPostIndex = 0 }
        postVC.selectedPostIndex = 0
        let infoPass = ["selectedPost": 0, "firstOpen": false, "parentVC":  PostViewController.parentViewController.feed] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
    }
    
    func addFeedSeg(selectedIndex: Int) {
        
        self.selectedSegmentIndex = selectedIndex
        
        let wideScreen = UIScreen.main.bounds.width > 400
        let segY: CGFloat = !mapVC.largeScreen ? 18 : UIScreen.main.bounds.width > 400 ? 53 : 42
        
        mapVC.feedMask = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        mapVC.feedMask.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        mapVC.mapView.addSubview(mapVC.feedMask)
        
        feedSegBlur = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 150, y: 0, width: 300, height: segY * 2 + 35))
        feedSegBlur.image = UIImage(named: "FeedSegBlur")
        mapVC.feedMask.addSubview(feedSegBlur)
        
        let segWidth: CGFloat = wideScreen ? 82 : 78 /// includes edge insets
        feedSeg = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - segWidth - 2.5, y: segY, width: segWidth * 2 + 10, height: 35))
        feedSeg.backgroundColor = nil
        mapVC.feedMask.addSubview(feedSeg)

        let selectedX = selectedIndex == 0 ? 5 : segWidth + 8.5
        let selectedY: CGFloat = wideScreen ? 3 : 4
        let selectedHeight: CGFloat = wideScreen ? 29 : 27
        
        selectedSegmentHighlight = UIView(frame: CGRect(x: selectedX, y: selectedY, width: segWidth - 10, height: selectedHeight))
        selectedSegmentHighlight.backgroundColor = UIColor(red: 0.11, green: 0.54, blue: 0.54, alpha: 1.00)
        selectedSegmentHighlight.layer.cornerRadius = 9
        selectedSegmentHighlight.layer.borderWidth = 1.25
        selectedSegmentHighlight.layer.borderColor = UIColor(red: 0.36, green: 0.69, blue: 0.71, alpha: 1.00).cgColor
        selectedSegmentHighlight.isUserInteractionEnabled = true
        selectedSegmentHighlight.clipsToBounds = true
        feedSeg.addSubview(selectedSegmentHighlight)
        
        let fontSize: CGFloat = wideScreen ? 14.5 : 13.5
        
        friendsSegment = UIButton(frame: CGRect(x: 0, y: 0, width: segWidth, height: 35))
        friendsSegment.titleEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 5)
        friendsSegment.setTitle("Friends", for: .normal)
        friendsSegment.setTitleColor(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.00), for: .normal)
        friendsSegment.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: fontSize)
        friendsSegment.contentHorizontalAlignment = .center
        friendsSegment.contentVerticalAlignment = .center
        friendsSegment.addTarget(self, action: #selector(friendsSegmentTap(_:)), for: .touchUpInside)
        feedSeg.addSubview(friendsSegment)
        
        nearbySegment = UIButton(frame: CGRect(x: segWidth + 5, y: 0, width: segWidth, height: 35))
        nearbySegment.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        nearbySegment.setTitle("Nearby", for: .normal)
        nearbySegment.setTitleColor(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.00), for: .normal)
        nearbySegment.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: fontSize)
        nearbySegment.contentHorizontalAlignment = .center
        nearbySegment.contentVerticalAlignment = .center
        nearbySegment.addTarget(self, action: #selector(nearbySegmentTap(_:)), for: .touchUpInside)
        feedSeg.addSubview(nearbySegment)

        /// hide feed seg if user already clicked off the feed
        if mapVC.customTabBar.selectedIndex != 0 { hideFeedSeg() }
    }
    
    func hideFeedSeg() {
        if mapVC.feedMask == nil { return }
        for sub in mapVC.feedMask.subviews { sub.removeFromSuperview() }
        mapVC.feedMask.isHidden = true
    }
    
    func unhideFeedSeg() {
        
        if !mapVC.feedMask.isHidden { return }
        if feedSeg == nil { return }
        if mapVC.customTabBar.selectedIndex != 0 { return }
        
        mapVC.feedMask.isHidden = false
        /// reset alphas in case drawer was closed on exit
        mapVC.feedMask.alpha = 1.0
        feedSeg.alpha = 1.0
        mapVC.feedMask.addSubview(feedSegBlur)
        mapVC.feedMask.addSubview(feedSeg)
    }
    
    @objc func friendsSegmentTap(_ sender: UIButton) {
        /// scroll to top if currently selected segment, switch segments otherwise
        Mixpanel.mainInstance().track(event: "FeedFriendsSegmentTap")
        if selectedSegmentIndex == 0 { openOrScrollToFirst(animated: true, newPost: false); return }
        switchToFriendsSegment()
    }
    
    func switchToFriendsSegment() {
        
        selectedSegmentIndex = 0
        selectedPostIndex = friendsPostIndex
        refresh = friendsRefresh
        animateSegmentSwitch()
        activityIndicator.stopAnimating()
        
        if postVC != nil && postVC.tableView != nil {
            
            postVC.cancelDownloads()
            postVC.selectedPostIndex = friendsPostIndex
            postVC.postsList = friendPosts
            mapVC.postsList = friendPosts
            postVC.tableView.reloadData()
            
            /// scroll to first row if theres a post there + open post on map
            if postVC.postsList.count != 0 {
                postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: false)
                let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed as Any] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                
            } else if refresh != .noRefresh {
                /// add activityIndicator if first refresh not finished yet
                if endDocument == nil { getFriendPosts(refresh: false) } /// endDocument should almost always be nil when refresh != noRefresh (more than 10 posts available to user)
                view.bringSubviewToFront(activityIndicator)
                activityIndicator.startAnimating()
            }
        }
    }
    
    @objc func nearbySegmentTap(_ sender: UIButton) {
        /// scroll to top if currently selected segment, switch segments otherwise
        Mixpanel.mainInstance().track(event: "FeedNearbySegmentTap")
        switchToNearbySegment()
        if selectedSegmentIndex == 1 { openOrScrollToFirst(animated: true, newPost: false); return }
    }
    
    func switchToNearbySegment() {
        
        selectedSegmentIndex = 1
        selectedPostIndex = nearbyPostIndex
        refresh = nearbyRefresh
        animateSegmentSwitch()
        activityIndicator.stopAnimating()

        if postVC != nil && postVC.tableView != nil {
            
            postVC.cancelDownloads()
            postVC.selectedPostIndex = nearbyPostIndex
            postVC.postsList = nearbyPosts
            mapVC.postsList = nearbyPosts
            postVC.tableView.reloadData()

            /// get nearby posts if haven't fetched already with starting radius
            if nearbyPosts.isEmpty {
                postVC.tableView.reloadData()
                view.bringSubviewToFront(activityIndicator)
                activityIndicator.startAnimating()
                getNearbyPosts(radius: 0.5)
            /// switch to nearby seg
                
            } else {
                activityIndicator.stopAnimating()
                postVC.tableView.reloadData()
                checkForLocationChange()
                
                /// scroll to first row if theres a post there + open post on map
                if postVC.postsList.count > postVC.selectedPostIndex {
                    postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: false)
                    let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.feed as Any] as [String : Any]
                    NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                }
            }
            /// run getNearbyPosts off the jump if friends fetch hasn't returned yet
        } else { getNearbyPosts(radius: activeRadius) }
    }
    
    func animateSegmentSwitch() {
        let wideScreen = UIScreen.main.bounds.width > 400
        let segWidth: CGFloat = wideScreen ? 82 : 78
        let minX = selectedSegmentIndex == 0 ? 5 : segWidth + 8.5
        UIView.animate(withDuration: 0.2) {
            self.selectedSegmentHighlight.frame = CGRect(x: minX, y: self.selectedSegmentHighlight.frame.minY, width: self.selectedSegmentHighlight.frame.width, height: self.selectedSegmentHighlight.frame.height)
        }
    }
    
    func checkForLocationChange() {
        
        if postVC != nil && postVC.tableView != nil && selectedSegmentIndex == 1  && activeRadius < 1000 {
            /// rerun circleQuery to updated location. Animate activity indicator so user expects new posts to appear
            let clCoordinate = mapVC.currentLocation.coordinate
            let queryCoordinate = circleQuery?.center.coordinate
            let latDif = abs(clCoordinate.latitude - (queryCoordinate?.latitude ?? 0.0))
            let longDif = abs(clCoordinate.longitude - (queryCoordinate?.longitude ?? 0.0))
            /// only reload if this was a big change
            if  latDif + longDif < 0.01 { return }
            
            getNearbyPosts(radius: activeRadius)
            view.bringSubviewToFront(activityIndicator)
            activityIndicator.startAnimating()
        }
    }
}


