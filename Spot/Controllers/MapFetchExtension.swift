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
        let scrollPosition: UICollectionView.ScrollPosition = resort ? .left : []
        
        DispatchQueue.main.async {
            self.mapsCollection.reloadData()
            self.mapsCollection.selectItem(at: IndexPath(item: self.selectedItemIndex, section: 0), animated: false, scrollPosition: scrollPosition)
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
                                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
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
        /// only reload if a visible value changed
        let runReload = UserDataModel.shared.userInfo.avatarURL != user.avatarURL || UserDataModel.shared.userInfo.currentLocation != user.currentLocation || UserDataModel.shared.userInfo.imageURL != user.imageURL || UserDataModel.shared.userInfo.name != user.name || UserDataModel.shared.userInfo.username != user.username
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
        /// update mapscollection + all posts to display accurate user info on profile edit
        if runReload {
            DispatchQueue.global().async {
                for key in self.friendsPostsDictionary.keys {
                    if self.friendsPostsDictionary[key] == nil { continue }
                    if self.friendsPostsDictionary[key]!.posterID == self.uid { self.friendsPostsDictionary[key]!.userInfo = UserDataModel.shared.userInfo }
                }
                /// update maps posts
                for i in 0..<UserDataModel.shared.userInfo.mapsList.count {
                    for key in UserDataModel.shared.userInfo.mapsList[i].postsDictionary.keys {
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key] == nil { continue }
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]!.posterID == self.uid {
                            UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]!.userInfo = UserDataModel.shared.userInfo }
                    }
                }
            }
            /// reload to update avatar
            DispatchQueue.main.async { if self.mapsCollection != nil { self.reloadMapsCollection(resort: false, newPost: false) }}
        }
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
        let seconds = Date().timeIntervalSince1970 - 86400 * 7
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86400
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
            if self.friendsPostsDictionary[postID] != nil { return true }
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
        if map == nil || (newPost && !(post.hideFromFeed ?? false) && UserDataModel.shared.userInfo.friendsContains(id: post.posterID)) {
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
        newPostListener = db.collection("posts").order(by: "timestamp", descending: true).limit(to: 1).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            
            if let doc = snap.documents.first {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    guard let postInfo = postIn else { return }
                    /// new post has 2 separate writes, wait for post location to get set to load it in
                    if doc.get("g") as? String == nil { return }
                    if UserDataModel.shared.deletedPostIDs.contains(postInfo.id ?? "") { return }
                    let map = UserDataModel.shared.userInfo.mapsList.first(where: {$0.id == postInfo.mapID ?? ""})
                    
                    let postAccess = self.hasNewPostAccess(post: postInfo, map: map)
                    if postAccess.access == false { return }
                    /// if user was just added to a new map, load that map then add the post to the map. Otherwise load in the new post
                    if postAccess.newMap {
                        self.loadNewMap(post: postInfo)
                    } else {
                        self.finishNewMapPostLoad(postInfo: postInfo, map: map)
                    }
                } catch {
                    return
                }
            }
        })
    }
        
    func hasNewPostAccess(post: MapPost, map: CustomMap?) -> (access: Bool, newMap: Bool) {
        if map == nil {
            /// non-friend post, user doesn't have map access
            if !UserDataModel.shared.userInfo.friendsContains(id: post.posterID) { return (false, false) }
            if (post.mapID ?? "") != "" {
                /// friend post to new map
                if (post.inviteList?.contains(uid) ?? false) {
                    return (true, true)
                } else if post.privacyLevel == "invite" {
                    /// user doesnt have access -on post to a secret map
                    return (false, false)
                } else {
                    /// user not added to map, just add to freinds map
                    return (true, false)
                }
            }
            /// friend post, not posted to a map
            return (true, false)
        }
        /// friend post to existing map
        return (true, false)
    }
    
    func loadNewMap(post: MapPost) {
        db.collection("maps").document(post.mapID!).getDocument { doc, err in
            guard let doc = doc else { return }
            do {
                let mapIn = try doc.data(as: CustomMap.self)
                guard var mapInfo = mapIn else { return }
                mapInfo.addSpotGroups()
                UserDataModel.shared.userInfo.mapsList.insert(mapInfo, at: 0)
                self.finishNewMapPostLoad(postInfo: post, map: mapInfo)
            } catch {
                return
            }
        }
    }
    
    func finishNewMapPostLoad(postInfo: MapPost, map: CustomMap?) {
        /// check map dictionary for add
        if !self.postsContains(postID: postInfo.id!, mapID: postInfo.mapID ?? "", newPost: true) {
            self.setPostDetails(post: postInfo) { [weak self] post in
                guard let self = self else { return }
                if !self.postsContains(postID: post.id!, mapID: post.mapID ?? "", newPost: true) {
                    DispatchQueue.main.async {
                        self.addPostToDictionary(post: post, map: map, newPost: true, index: self.selectedItemIndex)
                        self.reloadMapsCollection(resort: false, newPost: true)
                    }
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
            var group = map!.postGroup.filter({!$0.postIDs.isEmpty}) /// dont include empty spots
            if group.contains(where: {$0.postIDs.contains(where: {!$0.seen})}) { group = group.filter({$0.postIDs.contains(where: {!$0.seen})})}
            group = mapView.sortPostGroup(group)
            return group.map({$0.coordinate})
        }
    }
    
    func setNewPostsButtonCount() {
        let map = getSelectedMap()
        newPostsButton.unseenPosts = map == nil ? friendsPostsDictionary.filter{!$0.value.seen}.count : map!.postsDictionary.filter{!$0.value.seen}.count
    }
    
        
    func checkForActivityIndicator() {
        /// resume frozen indicator
        if mapsCollection != nil, let cell = mapsCollection.cellForItem(at: IndexPath(item: 0, section: 0)) as? MapLoadingCell {
            cell.activityIndicator.startAnimating()
        }
    }
}
