//
//  MapFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseUI
import MapKit

extension MapController {
    func runMapFetches() {
        startTime = Timestamp(date: Date()).seconds
        DispatchQueue.global(qos: .userInitiated).async {
            self.getActiveUser()
        }
    }
    
    @objc func notifyUserLoad(_ notification: NSNotification) {
        if feedLoaded { return }
        feedLoaded = true
                
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMaps()
            self.homeFetchGroup.enter()
            self.getRecentPosts(map: nil)
            
            /// home fetch group once here and once for maps posts
            self.homeFetchGroup.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.attachNewPostListener()
                self.newPostsButton.isHidden = false
                self.loadAdditionalOnboarding()
                self.reloadMapsCollection(resort: true, newPost: false)
                self.displayHeelsMap()
            }
        }
    }
    
    func reloadMapsCollection(resort: Bool, newPost: Bool) {
        if resort { UserDataModel.shared.userInfo.sortMaps() }
        
        DispatchQueue.main.async {
            self.mapsCollection.reloadData()
            self.mapsCollection.selectItem(at: IndexPath(item: self.selectedItemIndex, section: 0), animated: false, scrollPosition: .left)
            if resort && !newPost { self.centerMapOnMapPosts(animated: true) }
            self.setNewPostsButtonCount()
        }
    }
    
    func getAdmins() {
        self.db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, err) in
            if err != nil { return }
            for admin in snap!.documents { UserDataModel.shared.adminIDs.append(admin.documentID) }
        }
        ///opt kenny/ellie/tyler/b0t/hog/hog0 out of tracking
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" || uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" || uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" || uid == "X6CB24zc4iZFE8maYGvlxBp1mhb2" || uid == "HhDmknXyHDdWF54t6s8IEbEBlXD2" || uid == "oAKwM2NgLjTlaE2xqvKEXiIVKYu1" {
            Mixpanel.mainInstance().optOutTracking()
        }
    }
    
    func getActiveUser() {
        
        userListener = self.db.collection("users").document(self.uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (userSnap, err) in
            
            guard let self = self else { return }
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }
            
            do {
                ///get current user info
                let actUser = try userSnap?.data(as: UserProfile.self)
                guard var activeUser = actUser else { return }
                
                activeUser.id = userSnap!.documentID
                if userSnap!.documentID != self.uid { return } /// logout + object not being destroyed
                
                if UserDataModel.shared.userInfo.id == "" { UserDataModel.shared.userInfo = activeUser } else { self.updateUserInfo(user: activeUser) }
                if UserDataModel.shared.userInfo.profilePic == UIImage() { self.getUserProfilePics() }

                NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))

                for friend in UserDataModel.shared.userInfo.friendIDs {
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard let info = friendInfo else { UserDataModel.shared.userInfo.friendIDs.removeAll(where: {$0 == friend}); return }
                            if !UserDataModel.shared.userInfo.friendsList.contains(where: {$0.id == friend}) {
                                UserDataModel.shared.userInfo.friendsList.append(info)
                                if UserDataModel.shared.userInfo.friendsList.count == UserDataModel.shared.userInfo.friendIDs.count {
                                    self.sortFriends() /// sort for top friends
                                }
                            }
                            
                        } catch {
                            /// remove broken friend object
                            UserDataModel.shared.userInfo.friendIDs.removeAll(where: {$0 == friend})
                            return
                        }
                    }
                }
            } catch {  return }
        })
    }
    
    func updateUserInfo(user: UserProfile) {
        // update user info fields to avoid overwriting map values
        UserDataModel.shared.userInfo.avatarURL = user.avatarURL
        UserDataModel.shared.userInfo.currentLocation = user.currentLocation
        UserDataModel.shared.userInfo.imageURL = user.imageURL
        UserDataModel.shared.userInfo.name = user.name
        UserDataModel.shared.userInfo.pendingFriendRequests = user.pendingFriendRequests
        UserDataModel.shared.userInfo.spotScore = user.spotScore
        UserDataModel.shared.userInfo.topFriends = user.topFriends
        UserDataModel.shared.userInfo.friendIDs = user.friendIDs
        UserDataModel.shared.userInfo.username = user.username
    }
    
    func getUserProfilePics() {
        
        let userGroup = DispatchGroup()
        userGroup.notify(queue: .main) {
             NotificationCenter.default.post(Notification(name: Notification.Name("InitialUserLoad"))) }
        userGroup.enter()
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: URL(string: UserDataModel.shared.userInfo.imageURL), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, data, err, cache, download, url) in
            UserDataModel.shared.userInfo.profilePic = image ?? UIImage()
            userGroup.leave()
        }
        
        let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFit)
        let avatarURL = UserDataModel.shared.userInfo.avatarURL ?? ""
        if (avatarURL) != "" {
            userGroup.enter()
            self.imageManager.loadImage(with: URL(string: avatarURL), options: .highPriority, context: [.imageTransformer: aviTransformer], progress: nil) { (image, data, err, cache, download, url) in
                UserDataModel.shared.userInfo.avatarPic = image ?? UIImage()
                userGroup.leave()
            }
        }
    }


    func getRecentPosts(map: CustomMap?) {
        /// fetch all posts in last 7 days
        let seconds = Date().timeIntervalSince1970 - 86400 * 14
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86400 * 7
        let timestamp = Timestamp(seconds: Int64(seconds), nanoseconds: 0)
        var recentQuery = db.collection("posts").whereField("timestamp", isGreaterThanOrEqualTo: timestamp)
        ///query by mapID or friendsList for friends posts
        recentQuery = map != nil ? recentQuery.whereField("mapID", isEqualTo: map!.id!) : recentQuery.whereField("friendsList", arrayContains: uid)
        
        recentQuery.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.documents.count == 0 { self.homeFetchGroup.leave(); return }

            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    if self.postsContains(postID: postInfo.id!, mapID: map?.id ?? "", newPost: false) { self.updatePost(post: postInfo, map: map); continue }
                    if map == nil && !UserDataModel.shared.userInfo.friendsContains(id: postInfo.posterID) { continue }
                    /// check seenList if older than 24 hours
                    if postInfo.timestamp.seconds < Int64(yesterdaySeconds) && postInfo.seenList!.contains(self.uid) { continue }
                    
                    recentGroup.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        if post.id ?? "" != "" {
                            DispatchQueue.main.async {
                                self.addPostToDictionary(post: post, map: map, newPost: false, index: self.selectedItemIndex)
                            }
                        }
                        recentGroup.leave()
                    }
                    continue
                    
                } catch {
                    continue
                }
            }
            recentGroup.notify(queue: .global()) {
                self.homeFetchGroup.leave()
            }
        }
    }
    
    func postsContains(postID: String, mapID: String, newPost: Bool) -> Bool {
        if mapID == "" || newPost {
            return self.friendsPostsDictionary[postID] != nil
        }
        if mapID != "" {
            if let map = UserDataModel.shared.userInfo.mapsList.first(where: {$0.id == mapID}) {
                return map.postsDictionary[postID] != nil
            }
        }
        return false
    }
    
    func addPostToDictionary(post: MapPost, map: CustomMap?, newPost: Bool, index: Int) {
        /// add new post to both dictionaries
        if map == nil || (newPost && !(post.hideFromFeed ?? false)) {
            friendsPostsDictionary.updateValue(post, forKey: post.id!)
            if index == 0 { mapView.addPostAnnotation(post: post) }
        }
        if map != nil {
            /// map posts are sorted by spot rather than user
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == map!.id!}) {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary.updateValue(post, forKey: post.id!)
                let _ = UserDataModel.shared.userInfo.mapsList[i].updateGroup(post: post)
                if index - 1 == i && self.sheetView == nil {
                    /// remove and re-add annotation
                    DispatchQueue.main.async { self.addMapAnnotations(index: index, reload: true) }
                }
            }
        }
    }

    func updatePost(post: MapPost, map: CustomMap?) {
        /// use old post to only update values that CHANGE -> comments and likers
        let oldPost = map == nil ? friendsPostsDictionary[post.id!] : map!.postsDictionary[post.id!]
        guard var oldPost = oldPost else { return }
        oldPost.likers = post.likers
        if post.commentCount != oldPost.commentCount {
            getComments(postID: post.id!) { [weak self] comments in
                guard let self = self else { return }
                oldPost.commentList = comments
                oldPost.commentCount = post.commentCount
                self.updatePostDictionary(post: oldPost, mapID: map?.id ?? "")
            }
        } else {
            updatePostDictionary(post: oldPost, mapID: map?.id ?? "")
        }
    }
    
    func updatePostDictionary(post: MapPost, mapID: String) {
        if mapID == "" {
            self.friendsPostsDictionary[post.id!] = post
        } else {
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == post.id!}) {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[post.id!] = post
            }
        }
    }
    
    func getMaps() {
        db.collection("maps").whereField("likers", arrayContains: uid).getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for doc in snap.documents {
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { continue }
                    mapInfo.addSpotGroups()
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                    self.homeFetchGroup.enter()
                    self.getRecentPosts(map: mapInfo)
                } catch {
                    continue
                }
            }
            self.mapsLoaded = true
            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
        }
    }
    
    func attachNewPostListener() {
        /// listen for new posts entering
        newPostListener = db.collection("posts").order(by: "timestamp", descending: true).limit(to: 1).addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if let doc = snap.documents.first {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    guard let postInfo = postIn else { return }
                    if UserDataModel.shared.deletedPostIDs.contains(postInfo.id ?? "") { return }
                    let map = UserDataModel.shared.userInfo.mapsList.first(where: {$0.id == postInfo.mapID ?? ""})
                    /// friendsPost from someone user isn't friends with
                    if map == nil && !UserDataModel.shared.userInfo.friendIDs.contains(postInfo.posterID) || postInfo.hideFromFeed ?? false { return }
                    /// check map dictionary for add
                    if !self.postsContains(postID: postInfo.id!, mapID: postInfo.mapID ?? "", newPost: true) {
                        self.setPostDetails(post: postInfo) { [weak self] post in
                            guard let self = self else { return }
                            self.addPostToDictionary(post: post, map: map, newPost: true, index: self.selectedItemIndex)
                            self.reloadMapsCollection(resort: false, newPost: true)
                        }
                    }
                } catch {
                    return
                }
            }
        }
    }
            
    func getSortedCoordinates() -> [CLLocationCoordinate2D] {
        let map = getSelectedMap()
        if map == nil {
            var posts = friendsPostsDictionary.map({$0.value})
            if posts.contains(where: {!$0.seen}) { posts = posts.filter({!$0.seen}) }
            posts = mapView.sortPosts(posts)
            return posts.map({CLLocationCoordinate2D(latitude: $0.postLat, longitude: $0.postLong)})
        } else {
            var group = map!.postGroup
            if group.contains(where: {$0.postIDs.contains(where: {!$0.seen})}) { group = group.filter({$0.postIDs.contains(where: {!$0.seen})})}
            group = mapView.sortPostGroup(group)
            return group.map({$0.coordinate})
        }
    }
    
    func setNewPostsButtonCount() {
        let map = getSelectedMap()
        newPostsButton.unseenPosts = map == nil ? friendsPostsDictionary.filter{!$0.value.seen}.count : map!.postsDictionary.filter{!$0.value.seen}.count
    }
    
    func userInChapelHill() -> Bool {
        let chapelHillLocation = CLLocation(latitude: 35.9132, longitude: -79.0558)
        let distance = UserDataModel.shared.currentLocation.distance(from: chapelHillLocation)
        /// include users within 10km of downtown CH
        return distance/1000 < 10
    }
    
    @objc func notifyPostOpen(_ notification: NSNotification) {
        guard let postID = notification.userInfo?.first?.value as? String else { return }
        /// check every map for post and update if necessary
        /// check coordinate to refresh annotation on the map
        var coordinate: CLLocationCoordinate2D?
        if var post = friendsPostsDictionary[postID] {
            if !post.seenList!.contains(uid) { post.seenList?.append(uid) }
            friendsPostsDictionary[postID] = post
            coordinate = post.coordinate
        }
        
        if !UserDataModel.shared.userInfo.mapsList.isEmpty {
            for i in 0...UserDataModel.shared.userInfo.mapsList.count - 1 {
                UserDataModel.shared.userInfo.mapsList[i].updateSeen(postID: postID)
                if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
                    coordinate = UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]?.coordinate
                }
            }
        }
        
        DispatchQueue.main.async {
            self.reloadMapsCollection(resort: false, newPost: false)
            if coordinate != nil {
                if let annotation = self.mapView.annotations.first(where: {$0.coordinate.isEqualTo(coordinate: coordinate!)}) {
                    self.mapView.removeAnnotation(annotation)
                    self.mapView.addAnnotation(annotation)
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ notification: NSNotification) {
        /// add new post + zoom in on map
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        /// add new map to mapsList if applicable
        var map = notification.userInfo?["map"] as? CustomMap
        let emptyMap = map == nil || map?.id ?? "" == ""
        if !emptyMap && !(UserDataModel.shared.userInfo.mapsList.contains(where: {$0.id == map!.id!})) {
            map!.addSpotGroups()
            UserDataModel.shared.userInfo.mapsList.append(map!)
        }
        let mapIndex = post.hideFromFeed! ? 1 : 0
        DispatchQueue.main.async {
            self.selectMapAt(index: 0) /// select map at 0 to reset selected index (resort might mess with selecting index 1)
            self.addPostToDictionary(post: post, map: map, newPost: true, index: 0)
            self.reloadMapsCollection(resort: true, newPost: true)
            self.selectMapAt(index: mapIndex)
            self.reloadMapsCollection(resort: false, newPost: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            /// animate to spot if post to map, to post location if friends map
          ///  let coordinate = mapIndex == 1 && post.spotID ?? "" != "" ? CLLocationCoordinate2D(latitude: post.spotLat!, longitude: post.spotLong!) : post.coordinate
            self.animateTo(coordinate: post.coordinate)
        }
    }

    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapID = notification.userInfo?["mapID"] as? String else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        guard let spotRemove = notification.userInfo?["spotRemove"] as? Bool else { return }
        /// remove from friends stuff
        friendsPostsDictionary.removeValue(forKey: post.id!)
        UserDataModel.shared.deletedPostIDs.append(post.id!)
        /// remove from map
        if mapID != "" {
            if mapDelete {
                selectedItemIndex = 0 /// reset to avoid index out of bounds
                UserDataModel.shared.userInfo.mapsList.removeAll(where: {$0.id == mapID})
            } else if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == mapID}) {
                DispatchQueue.main.async { UserDataModel.shared.userInfo.mapsList[i].removePost(postID: post.id!, spotID: spotDelete || spotRemove ? post.spotID! : "") }
            }
        }
        /// remove annotation
        if let i = mapView.annotations.firstIndex(where: {$0.coordinate.isEqualTo(coordinate: post.coordinate)}) {
            DispatchQueue.main.async { self.mapView.removeAnnotation(self.mapView.annotations[i])}
        }
        DispatchQueue.main.async { self.reloadMapsCollection(resort: false, newPost: false) }
    }
    
    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }
        
        if friendsPostsDictionary[postID] != nil {
            friendsPostsDictionary[postID]!.commentList = commentList
            friendsPostsDictionary[postID]!.commentCount = max(0, commentList.count - 1)
        }
        
        for i in 0...UserDataModel.shared.userInfo.mapsList.count - 1 {
            if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]!.commentList = commentList
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]!.commentCount = max(0, commentList.count - 1)
            }
        }
    }
        
    @objc func mapLikersChanged(_ notification: NSNotification) {
        reloadMapsCollection(resort: true, newPost: true) /// set newPost to true to avoid map centering
    }
        
    @objc func notifyFriendsListAdd() {
        /// query friends posts again
        homeFetchGroup.enter()
        homeFetchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.reloadMapsCollection(resort: true, newPost: false)
        }
        
        DispatchQueue.global().async {
            self.getRecentPosts(map: nil)
        }
    }
    
    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == map.id}) {
            UserDataModel.shared.userInfo.mapsList[i].memberIDs = map.memberIDs
            UserDataModel.shared.userInfo.mapsList[i].likers = map.likers
            UserDataModel.shared.userInfo.mapsList[i].memberProfiles = map.memberProfiles
            UserDataModel.shared.userInfo.mapsList[i].imageURL = map.imageURL
            UserDataModel.shared.userInfo.mapsList[i].mapName = map.mapName
            UserDataModel.shared.userInfo.mapsList[i].mapDescription = map.mapDescription
            UserDataModel.shared.userInfo.mapsList[i].secret = map.secret
            print("reload maps collection")
            DispatchQueue.main.async { self.mapsCollection.reloadItems(at: [IndexPath(item: i + 1, section: 0)]) }
        }
    }
    
    @objc func enterForeground() {
        DispatchQueue.main.async { self.checkForActivityIndicator() }
    }
    
    @objc func notifyLogout() {
        userListener.remove()
        newPostListener.remove()
    }
    
    func checkForActivityIndicator() {
        /// resume frozen indicator
        if mapsCollection != nil, let cell = mapsCollection.cellForItem(at: IndexPath(item: 0, section: 0)) as? MapLoadingCell {
            cell.activityIndicator.startAnimating()
        }
    }
    
    func loadAdditionalOnboarding() {
        let posts = friendsPostsDictionary.count
        if (UserDataModel.shared.userInfo.avatarURL ?? "" == "") {
            let avc = AvatarSelectionController(sentFrom: "map")
            self.navigationController!.pushViewController(avc, animated: true)
        }
        else if (UserDataModel.shared.userInfo.friendIDs.count < 6 && posts == 0) {
            self.addFriends = AddFriendsView {
                $0.layer.cornerRadius = 13
                $0.isHidden = false
                self.view.addSubview($0)
            }
            
            self.addFriends.addFriendButton.addTarget(self, action: #selector(self.findFriendsTap(_:)), for: .touchUpInside)
            self.addFriends.snp.makeConstraints{
                $0.height.equalTo(160)
                $0.leading.trailing.equalToSuperview().inset(16)
                $0.centerY.equalToSuperview()
            }
        }
    }
}

extension MapController: MapControllerDelegate {
    
    func displayHeelsMap() {
        if userInChapelHill() && !UserDataModel.shared.userInfo.mapsList.contains(where: {$0.id == heelsMapID}) {
            let vc = HeelsMapPopUpController()
            vc.mapDelegate = self
            self.present(vc, animated: true)
        }
    }
    
    func addHeelsMap(heelsMap: CustomMap) {
        UserDataModel.shared.userInfo.mapsList.append(heelsMap)
        self.db.collection("maps").document("9ECABEF9-0036-4082-A06A-C8943428FFF4").updateData([
            "memberIDs": FieldValue.arrayUnion([uid]),
            "likers": FieldValue.arrayUnion([uid])
        ])
        reloadMapsCollection(resort: true, newPost: true)
        self.homeFetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getRecentPosts(map: heelsMap)
        }
    }
    
}
