//
//  MapExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/18/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import FirebaseUI
import MapboxMaps
import Firebase
import Geofirestore

extension MapViewController {
    
    func addFeedAnnotations() {
       /* if !postAnnotations.isEmpty { for anno in postAnnotations {
            mapView.addAnnotation(anno.value)
        } } */
    }
    
    func addPostAnnotation(post: MapPost, segment: Int) {
        /// probably need to break out into 2 funcs -> will add every post to map regardless of segment rn
        let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
        var customPointAnnotation = PointAnnotation(id: post.id!, coordinate: coordinate)
        customPointAnnotation.symbolSortKey = post.postScore

        if post.imageURLs.isEmpty || post.imageURLs.first ?? "" == "" {
            /// add text post anno
            let infoWindow = TextPostWindow.instanceFromNib() as! TextPostWindow
            infoWindow.clipsToBounds = true
            
            customPointAnnotation.image = .init(image: infoWindow.asImage(), name: "TextPost")
            addAnnotationToMap(annotation: customPointAnnotation, segment: segment)
            
        } else {
            /// add image anno
                        
            let tagImage = post.tag ?? "" == "" ? UIImage() : Tag(name: post.tag!).image
            var count = 0
            
            let nibView = MapPostWindow.instanceFromNib() as! MapPostWindow
            nibView.clipsToBounds = true
            
            nibView.galleryImage.contentMode = .scaleAspectFill
            nibView.galleryImage.layer.cornerRadius = 6
            nibView.galleryImage.clipsToBounds = true
            nibView.bringSubviewToFront(nibView.tagImage)

            if tagImage == UIImage() && post.tag != "" && post.tag != nil {
                loadTagImage(tag: post.tag!) { [weak self] image in
                    guard let self = self else { return }
                    nibView.tagImage.image = image
                    count += 1
                    if count == 2 {
                        let nibImage = nibView.asImage()
                        customPointAnnotation.image = .init(image: nibImage, name: UUID().uuidString)
                        self.addAnnotationToMap(annotation: customPointAnnotation, segment: segment)
                    }
                }
                
            } else {
                nibView.tagImage.image = tagImage
                count += 1
            }

            // load post image
            loadPostAnnotationImage(post: post) { [weak self] image in
                guard let self = self else { return }
                nibView.galleryImage.image = image
                count += 1
                if count == 2 {
                    let nibImage = nibView.asImage()
                    customPointAnnotation.image = .init(image: nibImage, name: UUID().uuidString)
                    self.addAnnotationToMap(annotation: customPointAnnotation, segment: segment)
                }
            }
        }
    }
    
    func addAnnotationToMap(annotation: PointAnnotation, segment: Int) {
        
        if segment == 0 { nearbyAnnotations.append(annotation) } else { friendAnnotations.append(annotation) }
        
        if segment == selectedSegmentIndex {
            postAnnotationManager.annotations.append(annotation)
            pointAnnotations.append(annotation)
        }
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
        
        let width: CGFloat = 100
        let transformer = SDImageResizingTransformer(size: CGSize(width: width, height: width * 1.5), scaleMode: .aspectFill)
        imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func loadTagImage(tag: String, completion: @escaping (_ image: UIImage) -> Void) {
        
        let tag = Tag(name: tag)
        /// get tag image url from db and update image
        tag.getImageURL { [weak self] urlString in
            guard let self = self else { return }

            let transformer = SDImageResizingTransformer(size: CGSize(width: 60, height: 60), scaleMode: .aspectFill)
            self.imageManager.loadImage(with: URL(string: urlString), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
                let image = image ?? UIImage()
                completion(image)
            }
        }
    }

    func getFriendPosts(refresh: Bool) {
        
        var query = db.collection("posts").order(by: "timestamp", descending: true).whereField("friendsList", arrayContains: self.uid).limit(to: 16)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument) }
        if !loadingIndicator.isAnimating() { DispatchQueue.main.async { self.loadingIndicator.startAnimating() }}

        self.friendsListener = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (snap, err) in
        
            guard let self = self else { return }
            guard let longDocs = snap?.documents else { return }
            
            if longDocs.count < 16 && !(snap?.metadata.isFromCache ?? false) {
                self.friendsRefresh = .noRefresh
                if self.selectedSegmentIndex == 1 { self.refresh = .noRefresh }
            } else {
                self.endDocument = longDocs.last
            }
            
          //  if longDocs.count == 0 && self.friendPosts.count == 0 { self.addEmptyState() }
                        
            var localPosts: [MapPost] = [] /// just the 10 posts for this fetch
            var index = 0
            
            let docs = self.friendsRefresh == .noRefresh ? longDocs : longDocs.dropLast() /// drop last doc to get exactly 10 posts for reload unless under 10 posts fetched

            for doc in docs {
                
                do {
                
                let postIn = try doc.data(as: MapPost.self)
                guard var postInfo = postIn else { index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}; continue }
                    postInfo.id = doc.documentID

                    if let user = UserDataModel.shared.friendsList.first(where: {$0.id == postInfo.posterID}) {
                    postInfo.userInfo = user
                    
                } else if postInfo.posterID == self.uid {
                    postInfo.userInfo = UserDataModel.shared.userInfo
                    
                } else {
                    /// friend not in users friendslist, might have removed them as a friend
                    index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}; continue
                }
                    
                    /// check for addedUsers + getComments -> exitCount will == 2 when these async functions are done running (avoid using dispatch due to loop)
                    var exitCount = 0
                    
                    self.getComments(postID: postInfo.id!) { commentList in
                        postInfo.commentList = commentList
                        postInfo = self.setSecondaryPostValues(post: postInfo)
                        exitCount += 1; if exitCount == 2 { localPosts.append(postInfo); index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }}
                    }
                    
                    self.getUserInfos(userIDs: postInfo.addedUsers ?? []) { users in
                        postInfo.addedUserProfiles = users
                        exitCount += 1; if exitCount == 2 { localPosts.append(postInfo); index += 1; if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts) }}
                    }

                } catch {
                    index += 1
                    if index == docs.count { self.loadFriendPostsToFeed(posts: localPosts)}
                    continue
                }
            }
        })
    }
    
    func getNearbyPosts(radius: Double) {

        nearbyEnteredCount = 0; currentNearbyPosts.removeAll(); noAccessCount = 0; nearbyEscapeCount = 0 /// reset counters to quickly check for post access on each query
        let geoFire = GeoFirestore(collectionRef: Firestore.firestore().collection("posts"))
        
        /// instantiate or update radius for circleQuery
        if circleQuery == nil {
            circleQuery = geoFire.query(withCenter: GeoPoint(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude), radius: radius)
            ///circleQuery?.searchLimit = 500
            let _ = circleQuery?.observe(.documentEntered, with: loadPostFromDB)
            
            let _ = circleQuery?.observeReady {
                self.queryReady = true
                if self.nearbyEnteredCount == 0 && self.activeRadius < 64 {
                    self.activeRadius *= 2; self.getNearbyPosts(radius: self.activeRadius)
                } else { self.accessEscape() }
            }
            
        } else {
            
            queryReady = false
            circleQuery?.removeAllObservers()
            circleQuery?.radius = radius
            circleQuery?.center = UserDataModel.shared.currentLocation

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
        nearbyListener = ref.addSnapshotListener({ [weak self] (doc, err) in
            
            guard let self = self else { return }

            do {
                /// get spot and check for access
                let postIn = try doc?.data(as: MapPost.self)
                guard var postInfo = postIn else { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return }
                if self.deletedPostIDs.contains(where: {$0 == postKey}) { self.noAccessCount += 1; self.accessEscape(); return }
                
                postInfo.id = doc!.documentID
                postInfo = self.setSecondaryPostValues(post: postInfo)

                if self.nearbyPosts.contains(where: {$0.id == postKey}) {
                    /// fetching new circle query form DB and this post is already there
                    if self.noAccessCount + self.currentNearbyPosts.count < self.nearbyEnteredCount { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return
                    } else {
                    /// active listener found a change
                        self.updateNearbyPostFromDB(post: postInfo); return
                    }
                }
                
                if !self.hasPostAccess(post: postInfo) { if !escaped { self.noAccessCount += 1 }; escaped = true; self.accessEscape(); return }
                
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
        
        /// add if condition for if nearby posts selected
        if selectedSegmentIndex == 0, let i = postsList.firstIndex(where: {$0.id == post.id}) {
            let userInfo = postsList[i].userInfo
            let postScore = postsList[i].postScore
            postsList[i] = post
            postsList[i].userInfo = userInfo /// not fetching user info again so need to set it manually
            postsList[i].postScore = postScore /// not fetching post score again so need to set it manually
            ///  DispatchQueue.main.async { self.postVC.tableView.reloadData() }
        }
        
        getComments(postID: post.id!) { [weak self] commentList in
            guard let self = self else { return }
            self.updateNearbyPostComments(comments: commentList, postID: post.id!)
        }
    }
    
    func updateNearbyPostComments(comments: [MapComment], postID: String) {
        if let i = nearbyPosts.firstIndex(where: {$0.id == postID}) {
            nearbyPosts[i].commentList = comments
            /// segment index check
            if selectedSegmentIndex == 0, let i = postsList.firstIndex(where: {$0.id == postID}) {
                postsList[i].commentList = comments
              ///  DispatchQueue.main.async { self.postVC.tableView.reloadData() }
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
            
            var post = currentNearbyPosts[i]
            
            var exitCount = 0
            self.getComments(postID: post.id!) { commentList in
                post.commentList = commentList
                self.currentNearbyPosts[i].commentList = commentList
                exitCount += 1; if exitCount == 3 { self.nearbyEscape() }
            }
            
            /// get poster user info
            self.getUserInfos(userIDs: [post.posterID]) { userInfos in
                let user = userInfos.first ?? UserProfile(username: "", name: "", imageURL: "", currentLocation: "", userBio: "")
                post.userInfo = user
                self.currentNearbyPosts[i].userInfo = user
                exitCount += 1; if exitCount == 3 { self.nearbyEscape() }
            }
            
            /// get added user infos
            self.getUserInfos(userIDs: post.addedUsers ?? []) { userInfos in
                post.addedUserProfiles = userInfos
                self.currentNearbyPosts[i].addedUserProfiles = userInfos
                exitCount += 1; if exitCount == 3 { self.nearbyEscape() }
            }
        }
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
        
        let distance = max(CLLocation(latitude: post.postLat, longitude: post.postLong).distance(from: CLLocation(latitude: UserDataModel.shared.currentLocation.coordinate.latitude, longitude: UserDataModel.shared.currentLocation.coordinate.longitude)), 1)

        let postTime = Float(post.seconds)
        let current = NSDate().timeIntervalSince1970
        let currentTime = Float(current)
        let timeSincePost = currentTime - postTime

        /// add multiplier for recent posts
        let factor = Double(min(1 + (100000000 / timeSincePost), 2000))
        scoreMultiplier = Double(pow(factor, 3)) * 10

        /// content bonuses
        if UserDataModel.shared.friendIDs.contains(post.posterID) { scoreMultiplier += 50 }
        
        for like in post.likers {
            scoreMultiplier += 20
            if UserDataModel.shared.friendIDs.contains(like) { scoreMultiplier += 5 }
        }
        
        for comment in post.commentList {
            scoreMultiplier += 10
            if UserDataModel.shared.friendIDs.contains(comment.commenterID) { scoreMultiplier += 2.5 }
        }
        
        return scoreMultiplier/distance
    }
    
    func loadNearbyPostsToFeed() {

        currentNearbyPosts.sort(by: {$0.postScore > $1.postScore})
        
        for post in currentNearbyPosts {
            
            if !nearbyPosts.contains(where: {$0.id == post.id}) {
                
                /// nil user info leaks through because nearby escape is called for an error on user fetch. itll be fine for nil comments but nil user is bad
                if post.userInfo != nil { nearbyPosts.append(post) }
                self.addPostAnnotation(post: post, segment: 0)

                /// only update if active segment
                if post.id == currentNearbyPosts.last?.id {
                    
                    if selectedSegmentIndex == 0 {
                        
                        DispatchQueue.main.async {
                                                        
                            for i in 0...self.nearbyPosts.count - 1 { self.nearbyPosts[i].postScore = self.getPostScore(post: self.nearbyPosts[i]) } /// update post scores on location change
                            self.nearbyPosts.sort(by: {$0.postScore > $1.postScore})
                            self.postsList = self.nearbyPosts
                            
                            if self.nearbyRefresh != .noRefresh { self.nearbyRefresh = .yesRefresh }
                            if self.refresh != .noRefresh { self.refresh = .yesRefresh }
                        }
                        
                        /// just update refresh index otherwise
                    } else { if self.nearbyRefresh != .noRefresh { self.nearbyRefresh = .yesRefresh } }
                }
                
            } else {
                
                if let index = self.nearbyPosts.firstIndex(where: {$0.id == post.id}) {

                    let selected0 = nearbyPosts[index].selectedImageIndex
                    self.nearbyPosts[index] = post
                    self.nearbyPosts[index].selectedImageIndex = selected0
                    
                    if let postVC = children.first as? PostViewController, selectedSegmentIndex == 0 {
                        
                        /// if this is the active segment
                        if let postIndex = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                                                        
                            let selected1 = postVC.postsList[postIndex].selectedImageIndex
                            postVC.postsList[postIndex] = post
                            postVC.postsList[postIndex].selectedImageIndex = selected1
                        
                        }
                    }
                }

            }
        }
    }
    func loadFriendPostsToFeed(posts: [MapPost]) {

        for post in posts {
            
            if !friendPosts.contains(where: {$0.id == post.id}) {
                
                var scrollToFirstRow = false
                
                if !deletedPostIDs.contains(post.id ?? "") && !deletedFriendIDs.contains(post.posterID) {

                  /*  let postAnnotation = CustomPointAnnotation()
                    postAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
                    postAnnotation.postID = post.id ?? ""
                    postAnnotations[post.id!] = postAnnotation

                    if selectedSegmentIndex == 0 {                         mapView.addAnnotation(postAnnotation) } */
                    
                    self.addPostAnnotation(post: post, segment: 1)
                    
                    let newPost = friendPosts.count > 10 && post.timestamp.seconds > friendPosts.first?.timestamp.seconds ?? 100000000000

                    if !newPost {
                        friendPosts.append(post)
                        friendPosts.sort(by: {$0.seconds > $1.seconds})
                        
                    } else {
                        /// insert at 0 if at the of the feed (usually a new load), insert at post + 1 otherwise
                        friendPosts.insert(post, at: 0)
                       /// if postVC != nil { scrollToFirstRow = postVC.selectedPostIndex == 0 }
                    }
                    
                    if selectedSegmentIndex == 1 { postsList = friendPosts }
                }
                
               if post.id == posts.last?.id {
                if selectedSegmentIndex == 1 {
                    // reload posts table
                    DispatchQueue.main.async {
                        if self.feedTable.numberOfRows(inSection: 0) == 0 { self.checkFeedLocations() }
                        self.feedTable.reloadData()
                        self.refresh = .yesRefresh
                        
                        /// reload postsVC if added
                        if let postVC = self.children.first(where: {$0.isKind(of: PostViewController.self)}) as? PostViewController {
                            postVC.postsList = self.postsList
                            postVC.tableView.reloadData()
                        }
                    }
                    
                    /// segment switch during reload
                } else { if self.friendsRefresh != .noRefresh { self.friendsRefresh = .yesRefresh } }
               }
                
            } else {
                
                /// already contains post - active listener found a change, probably a comment or like
                if let index = self.friendPosts.firstIndex(where: {$0.id == post.id}) {

                    let selected0 = friendPosts[index].selectedImageIndex
                    friendPosts[index] = post
                    friendPosts[index].selectedImageIndex = selected0
                    
                    if let postVC = children.first as? PostViewController, selectedSegmentIndex == 1 {
                        
                        /// account for possiblity of postslist / postvc.postslist not matching up
                        if let postIndex = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                                                        
                            let selected1 = postVC.postsList[postIndex].selectedImageIndex
                            postVC.postsList[postIndex] = post
                            postVC.postsList[postIndex].selectedImageIndex = selected1
                        
                            /// table reloaded constantly - really no need for this
                        }
                    }
                }
            }
        }
    }
    
    func getUserInfos(userIDs: [String], completion: @escaping (_ users: [UserProfile]) -> Void) {
        
        var users: [UserProfile] = []
        if userIDs.isEmpty { completion(users); return }
        var userCount = 0
        
        for userID in userIDs {
            
            if let user = UserDataModel.shared.friendsList.first(where: {$0.id == userID}) {
                users.append(user)
                userCount += 1
                if userCount == userIDs.count { completion(users) }
                
            } else if userID == uid {
                users.append(UserDataModel.shared.userInfo)
                userCount += 1
                if userCount == userIDs.count { completion(users) }
                
            } else {
                db.collection("users").document(userID).getDocument { (doc, err) in
                    if err != nil { return }

                    do {
                        let userInfo = try doc!.data(as: UserProfile.self)
                        guard var info = userInfo else { userCount += 1; if userCount == userIDs.count { completion(users) }; return }

                        info.id = doc!.documentID
                        users.append(info)
                        userCount += 1
                        if userCount == userIDs.count { completion(users) }

                    } catch { userCount += 1; if userCount == userIDs.count { completion(users); return } }
                }
            }
        }
    }

    
    func getComments(postID: String, completion: @escaping (_ comments: [MapComment]) -> Void) {
        
        var commentList: [MapComment] = []
        
        commentListener = db.collection("posts").document(postID).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener { [weak self] (commentSnap, err) in
            
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
                    
                    /// get commenter user info from friends list or from database
                    var tempFriends = UserDataModel.shared.friendsList
                    tempFriends.append(UserDataModel.shared.userInfo)
                    
                    if let i = tempFriends.firstIndex(where: {$0.id == commentInfo.commenterID}) {
                        commentInfo.userInfo = tempFriends[i]
                        if !commentList.contains(where: {$0.id == doc.documentID}) {
                            commentList.append(commentInfo)
                            commentList.sort(by: {$0.seconds < $1.seconds})
                        }
                        
                        if doc == commentSnap!.documents.last { completion(commentList) }
                        
                    } else {
                        
                        self.db.collection("users").document(commentInfo.commenterID).getDocument { (snap, err) in
                            
                            do {
                                let userProf = try snap?.data(as: UserProfile.self)
                                guard var userProfile = userProf else { if doc == commentSnap!.documents.last { completion(commentList) }; return }
                                
                                userProfile.id = snap!.documentID
                                commentInfo.userInfo = userProfile
                                
                                if !commentList.contains(where: {$0.id == doc.documentID}) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: {$0.seconds < $1.seconds})
                                }
                                
                                if doc == commentSnap!.documents.last { completion(commentList) }
                                
                            } catch { if doc == commentSnap!.documents.last { completion(commentList) }; return }
                        }
                    }
                } catch { if doc == commentSnap!.documents.last { completion(commentList) }; continue }
            }
        }
    }
    
    func openPosts(row: Int, openComments: Bool) {
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            vc.postsList = self.postsList
            vc.selectedPostIndex = row
            /// set frame index and go to that image
                        
            vc.mapVC = self
            vc.commentNoti = openComments
            vc.parentVC = .feed
            
            vc.view.frame = UIScreen.main.bounds
            addChild(vc)
            view.addSubview(vc.view)
            vc.didMove(toParent: self)
            
            let infoPass = ["selectedPost": index, "firstOpen": true, "parentVC": PostViewController.parentViewController.spot] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
        }
    }
    
    @objc func notifyNewPost(_ notification: NSNotification) {
        /// needs to be reworked with mapbox funcs
        if let newPost = notification.userInfo?.first?.value as? MapPost {
            
            var post = newPost
            post = setSecondaryPostValues(post: post)
            postsList.insert(post, at: 0)
            selectedFeedIndex = max(selectedFeedIndex + 1, 1) /// increment index or move to >0 to ensure select new runs
            
            let postAnnotation = CustomPointAnnotation()
            postAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            postAnnotation.postID = post.id ?? ""
            postAnnotations[post.id!] = postAnnotation
            
            addPostAnnotation(post: post, segment: 1)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.feedTable.reloadData(); self.selectPostAt(index: 0) }
            
        }
    }
    
    @objc func postIndexChange(_ notification: NSNotification) {

        guard let info = notification.userInfo as? [String: Any] else { return }
        /// animate to next post after vertical scroll
        if let index = info["selectedPost"] as? Int {
            selectNewPost(index: index, animated: true, dragging: false)
        }
    }
    
    func resetFeed() {
        setUpNavBar()
    }
    
    @objc func feedButtonTap(_ sender: UIButton) {
        sender.tag == 0 ? closeFeedDrawer() : openFeedDrawer()
    }
    
    func closeFeedDrawer() {
        
        feedTableButton.tag = 1

        /// deselect current row/anno
        selectNewPost(index: -1, animated: false, dragging: false)
        
        UIView.animate(withDuration: 0.3) {
            self.feedTableContainer.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 80, width: UIScreen.main.bounds.width, height: 80)
            self.postsLabel.frame = CGRect(x: self.postsLabel.frame.minX, y: self.postsLabel.frame.minY, width: self.postsLabel.frame.width, height: self.postsLabel.frame.height)
            self.feedTable.alpha = 0.0
            self.feedTable.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            self.feedTableButton.frame = CGRect(x: self.postsLabel.frame.maxX, y: self.feedTableButton.frame.minY, width: self.feedTableButton.frame.width, height: self.feedTableButton.frame.height)
         //   self.addClosedDrawerMask()
        }
    }
    
    func openFeedDrawer() {
        
        feedTableButton.tag = 0
        addTempGradient() /// simulate smooth map mask animation

        UIView.animate(withDuration: 0.3) {
            self.feedTableContainer.frame = CGRect(x: 0, y: UIScreen.main.bounds.height * 2/5, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 3/5)
            self.postsLabel.frame = CGRect(x: self.postsLabel.frame.minX, y: self.postsLabel.frame.minY, width: self.postsLabel.frame.width, height: self.postsLabel.frame.height)
            self.feedTable.alpha = 1.0
            self.feedTableButton.frame = CGRect(x: self.postsLabel.frame.maxX, y: self.feedTableButton.frame.minY, width: self.feedTableButton.frame.width, height: self.feedTableButton.frame.height)
          //  self.addOpenDrawerMask()
        }
    }
    
    func addOpenDrawerMask() {
        
        bottomMapMask.frame = CGRect(x: 0, y: UIScreen.main.bounds.height/2, width: UIScreen.main.bounds.width, height: bottomMapMask.frame.height)
        
        if let layer1 = bottomMapMask.layer.sublayers?.first as? CAGradientLayer {
            layer1.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0, alpha: 0.86).cgColor,
              UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
            ]
            layer1.locations = [0, 0.56, 1]
        }
    }
    
    func addTempGradient() {
        
        let tempView = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height * 3/4, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 1/4))
        UserDataModel.shared.mapView.addSubview(tempView)
        
        let layer1 = CAGradientLayer()
        layer1.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.86).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
        ]
        layer1.locations = [0, 0.05, 0.1, 0.25, 0.3]
        layer1.frame = tempView.bounds
        layer1.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer1.endPoint = CGPoint(x: 0.5, y: 1.0)
        tempView.layer.addSublayer(layer1)

        UIView.animate(withDuration: 0.3, animations: {
            tempView.alpha = 0.0
        }) { _ in
            tempView.removeFromSuperview()
        }
    }
    
    func addClosedDrawerMask() {
                
        bottomMapMask.frame = CGRect(x: 0, y: UIScreen.main.bounds.height * 3/4, width: UIScreen.main.bounds.width, height: bottomMapMask.frame.height)
        
        if let layer1 = bottomMapMask.layer.sublayers?.first as? CAGradientLayer {
            layer1.colors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.1).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.86).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
            ]
            layer1.locations = [0, 0.05, 0.1, 0.25, 0.3]
        }
    }
    
    @objc func feedPan(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: feedTable)
        let velocity = sender.velocity(in: feedTable)
        
        switch sender.state {
        case .began:
            originalOffset = feedTable.contentOffset.y
            feedRowOffset = 0
            
        case .changed:
            feedTable.setContentOffset(CGPoint(x: 0, y: min(max(0, originalOffset - translation.y/2), feedTable.contentSize.height)), animated: false)
            setPartialValues(translation: translation.y/2)

            if translation.y/2 + feedRowOffset < 0 {
                let zeroAdjust: CGFloat = selectedFeedIndex == -1 ? 22.5 : 0
                if selectedFeedIndex > postsList.count - 2 { return }
                
                if (zeroAdjust - translation.y/2 - feedRowOffset) > 22.5 {
                    if selectedFeedIndex != -1 { feedRowOffset += 45 } /// offset for row 0 stays d 0
                    deselectOldPost(index: selectedFeedIndex, up: false)
                    selectNewPost(index: selectedFeedIndex + 1, animated: false, dragging: true)
                }
                
            } else {
                if selectedFeedIndex < 1 { return }
                if -(-translation.y/2 - feedRowOffset) > 22.5 {
                    feedRowOffset -= 45
                    deselectOldPost(index: selectedFeedIndex, up: true)
                    selectNewPost(index: selectedFeedIndex - 1, animated: false, dragging: true)
                }
            }
            
        case .ended, .cancelled:

            let composite = translation.y/2 + velocity.y/20 + feedRowOffset
            /// round composite to nearest multiple of 45 then Int divide by 45 to determine how many rows to offset
            /// check for end of table / <0
            let lineHeight: CGFloat = 45
            let totalOffset = Int(lineHeight) * Int((composite / lineHeight).rounded())
            let rowOffset = totalOffset/Int(lineHeight)
            var newRow = rowOffset < 0 ? selectedFeedIndex + 1 : rowOffset < 0 ? selectedFeedIndex - 1 : selectedFeedIndex
            newRow = min(max(newRow, 0), postsList.count - 1)
            selectNewPost(index: newRow, animated: true, dragging: false)
            
           // let newIndex = min(max(0, selectedFeedIndex - rowOffset), postsList.count - 1)
            
            return
        default: return
        }
    }
    
    func setPartialValues(translation: CGFloat) {
        /// get content offset -> percentage
        let extraOffset = feedTable.contentOffset.y - CGFloat(45 * selectedFeedIndex)
        let newRow = extraOffset > 0 ? selectedFeedIndex + 1 : selectedFeedIndex - 1
        let percentageOffset: CGFloat = min(max(abs(extraOffset / 45), 0), 1)
        /// get new cell
        guard let newCell = feedTable.cellForRow(at: IndexPath(row: newRow, section: 0)) as? MapFeedCell else { return }
        newCell.setPartialValues(offset: percentageOffset)
        /// get currently selected
        guard let oldCell = feedTable.cellForRow(at: IndexPath(row: selectedFeedIndex, section: 0)) as? MapFeedCell else { return }
        oldCell.setPartialValues(offset: 1 - percentageOffset)
        /// set value proportional to offset for each
    }
    
    func deselectOldPost(index: Int, up: Bool) {
        let n1 = up ? index + 1 : index - 1
        if n1 < postsList.count - 1 && n1 > 0 {
            guard let oldCell = feedTable.cellForRow(at: IndexPath(row: n1, section: 0)) as? MapFeedCell else { return }
            oldCell.setUnselectedValues()
        }
    }
}

class MapFeedCell: UITableViewCell {
    
    var profilePic: UIImageView!
    var newIcon: UIImageView!
    var usernameLabel: UILabel!
    var timestampLabel: UILabel!
    var tagIcon: UIImageView!
    var spotName: UILabel!
    
    var row = -1
    var tap: UITapGestureRecognizer!
    
    func setUp(post: MapPost, row: Int, selected: Bool) {
        
        self.row = row
        backgroundColor = .clear
        selectionStyle = .none
        let cellWidth = UIScreen.main.bounds.width - 101
        
        resetView()
        tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        contentView.addGestureRecognizer(tap)
                
        profilePic = UIImageView(frame: CGRect(x: selected ? 18.5 : 13.5, y: selected ? 6.5 : 13.5, width: selected ? 37 : 31, height: selected ? 36.5 : 30.5))
        profilePic.contentMode = .scaleAspectFill
        profilePic.layer.cornerRadius = selected ? 11.5 : 11
        profilePic.clipsToBounds = true
        contentView.addSubview(profilePic)

        if post.userInfo != nil {
            let url = post.userInfo.imageURL
            if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
            }
        }
    
        usernameLabel = UILabel(frame: CGRect(x: selected ? profilePic.frame.maxX + 6.5 : profilePic.frame.maxX + 10.5, y: selected ? 7 : 14, width: cellWidth - profilePic.frame.maxX - 50, height: 15))
        usernameLabel.text = post.userInfo.username
        usernameLabel.textColor = selected ? .white : UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        usernameLabel.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        usernameLabel.sizeToFit()
        contentView.addSubview(usernameLabel)
        
        timestampLabel = UILabel(frame: CGRect(x: usernameLabel.frame.maxX + 3, y: usernameLabel.frame.minY + 1, width: 100, height: 14))
        timestampLabel.text = getTimestamp(postTime: post.timestamp)
        timestampLabel.textColor = UIColor(red: 0.496, green: 0.496, blue: 0.496, alpha: 1)
        timestampLabel.font = UIFont(name: "SFCompactText-Regular", size: 11.5)
        timestampLabel.sizeToFit()
        contentView.addSubview(timestampLabel)
        
        let tagImage = post.tag ?? "" == "" ? UIImage(named: "FeedSpotIcon") : Tag(name: post.tag!).image

        tagIcon = UIImageView(frame: CGRect(x: usernameLabel.frame.minX, y: usernameLabel.frame.maxY + 2, width: 15, height: 15))
        tagIcon.image =  tagImage
        tagIcon.isUserInteractionEnabled = false
        contentView.addSubview(tagIcon)
        if tagImage == UIImage() { getTagImage(tagName: post.tag!) }
        
        spotName = UILabel(frame: CGRect(x: tagIcon.frame.maxX + 3, y: tagIcon.frame.minY + 1, width: cellWidth - tagIcon.frame.maxX - 5, height: 14))
        spotName.text = post.spotName ?? ""
        spotName.textColor = selected ? .white : UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        spotName.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        contentView.addSubview(spotName)
    }
    
    @objc func tap(_ sender: UITapGestureRecognizer) {
        guard let mapVC = viewContainingController() as? MapViewController else { return }
        mapVC.selectPostAt(index: row)
    }
    
    func getTagImage(tagName: String) {
        let tag = Tag(name: tagName)
        tag.getImageURL { [weak self] url in
            guard let self = self else { return }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 70, height: 70), scaleMode: .aspectFill)
            if self.tagIcon != nil { self.tagIcon.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
        }
    }
    
    func setSelectedValues() {
        
        let cellWidth = UIScreen.main.bounds.width - 101

        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.1) {
                /// selected - 18.5/6.5/37/36.5
                self.profilePic.frame = CGRect(x: 18.5, y: 6.5, width: 37, height: 36.5)
                self.profilePic.layer.cornerRadius = 11.5

                /// selected- +6.5/7
                self.usernameLabel.frame = CGRect(x: self.profilePic.frame.maxX + 6.5, y: 7, width: self.usernameLabel.frame.width, height: 15)
                self.usernameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
                
                self.timestampLabel.frame = CGRect(x: self.usernameLabel.frame.maxX + 3, y: self.usernameLabel.frame.minY + 1, width: self.timestampLabel.frame.width, height: 14)
                self.tagIcon.frame = CGRect(x: self.usernameLabel.frame.minX, y: self.usernameLabel.frame.maxY + 2, width: 15, height: 15)

                self.spotName.frame = CGRect(x: self.tagIcon.frame.maxX + 3, y: self.tagIcon.frame.minY + 1, width: cellWidth - self.tagIcon.frame.maxX - 5, height: 14)
                self.spotName.textColor = .white
            }
        }
    }
    
    func setUnselectedValues() {
        
        let cellWidth = UIScreen.main.bounds.width - 101

        DispatchQueue.main.async {
           UIView.animate(withDuration: 0.1) {
                /// unselected - 13.5/13.5/31/30.5
                self.profilePic.frame = CGRect(x: 13.5, y: 13.5, width: 31, height: 30.5)
                self.profilePic.layer.cornerRadius = 11

                /// unselected - +10.5/14
                self.usernameLabel.frame = CGRect(x: self.profilePic.frame.maxX + 10.5, y: 14, width: self.usernameLabel.frame.width, height: 15)
                self.usernameLabel.textColor = .white
                
                self.timestampLabel.frame = CGRect(x: self.usernameLabel.frame.maxX + 3, y: self.usernameLabel.frame.minY + 1, width: self.timestampLabel.frame.width, height: 14)
                self.tagIcon.frame = CGRect(x: self.usernameLabel.frame.minX, y: self.usernameLabel.frame.maxY + 2, width: 15, height: 15)

                self.spotName.frame = CGRect(x: self.tagIcon.frame.maxX + 3, y: self.tagIcon.frame.minY + 1, width: cellWidth - self.tagIcon.frame.maxX - 5, height: 14)
                self.spotName.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
            }
        }
    }
    
    func setPartialValues(offset: CGFloat) {
        
        let cellWidth = UIScreen.main.bounds.width - 101

        /// set proportional values between selected/unselected
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.1) {
                /// unselected - 13.5/13.5/31/30.5
                /// selected - 18.5/6.5/37/36.5
                self.profilePic.frame = CGRect(x: 13.5 + (offset * 5), y: 13.5 - (offset * 7), width: 31 + (offset * 6), height: 30.5 + (offset * 6))

                /// unselected - +10.5/14
                /// selected- +6.5/7
                self.usernameLabel.frame = CGRect(x: self.profilePic.frame.maxX + 10.5 - (offset * 4), y: 14 - (offset * 7), width: cellWidth - self.profilePic.frame.maxX - 50, height: 15)
                self.usernameLabel.sizeToFit()
                
                self.timestampLabel.frame = CGRect(x: self.usernameLabel.frame.maxX + 3, y: self.usernameLabel.frame.minY + 1, width: self.timestampLabel.frame.width, height: 14)
                self.tagIcon.frame = CGRect(x: self.usernameLabel.frame.minX, y: self.usernameLabel.frame.maxY + 2, width: 15, height: 15)

                self.spotName.frame = CGRect(x: self.tagIcon.frame.maxX + 3, y: self.tagIcon.frame.minY + 1, width: cellWidth - self.tagIcon.frame.maxX - 5, height: 14)
            }
        }
    }

    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if newIcon != nil { newIcon.image = UIImage() }
        if usernameLabel != nil { usernameLabel.text = "" }
        if timestampLabel != nil { timestampLabel.text = "" }
        if tagIcon != nil { tagIcon.image = UIImage() }
        if spotName != nil { spotName.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if profilePic != nil { profilePic.removeFromSuperview(); profilePic.sd_cancelCurrentImageLoad() }
        if tagIcon != nil { tagIcon.removeFromSuperview(); tagIcon.sd_cancelCurrentImageLoad() }
    }
}

class MapFeedLoadingCell: UITableViewCell {
    
    var activityIndicator: CustomActivityIndicator!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp() {
    
        if activityIndicator != nil { activityIndicator.removeFromSuperview() }
        
        activityIndicator = CustomActivityIndicator(frame: CGRect(x: 30, y: 10, width: 30, height: 30))
        activityIndicator.startAnimating()
        self.addSubview(activityIndicator)
    }
}
