//
//  MapFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Firebase
import MapKit
import Mixpanel
import UIKit
import SDWebImage

extension MapController {
    func runMapFetches() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getActiveUser()
        }
    }
    
    func leaveHomeFetchGroup(newPost: Bool) {
        if homeFetchLeaveCount < 2 {
            homeFetchLeaveCount += 1
            homeFetchGroup.leave()
        } else {
            if newPost {
                DispatchQueue.main.async { self.finishPostsLoad(resort: true, newPost: true, upload: false) }
            }
        }
    }
    
    func finishPostsLoad(resort: Bool, newPost: Bool, upload: Bool) {
        if resort {
            /// reset selected item index on resort in case the position of the selected map changed
            UserDataModel.shared.userInfo.sortMaps()
        }
        if resort && !newPost { centerMapOnMapPosts(animated: true, includeSeen: false) }
        setNewPostsButtonCount()
    }
    
    func getAdmins() {
        self.db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, _) in
            guard let snap = snap else { return }
            for doc in snap.documents { UserDataModel.shared.adminIDs.append(doc.documentID)
            }
        }
        // opt kenny/tyler/b0t/hog/test/john/ella out of tracking
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" ||
            uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" ||
            uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" ||
            uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" ||
            uid == "oAKwM2NgLjTlaE2xqvKEXiIVKYu1" ||
            uid == "2MpKovZvUYOR4h7YvAGexGqS7Uq1" ||
            uid == "W75L1D248ibsm6heDoV8AzlWXCx2" {
            Mixpanel.mainInstance().optOutTracking()
        }
    }
    
    func getActiveUser() {
        userListener = self.db.collection("users").document(self.uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (userSnap, err) in
            guard let self = self else { return }
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }
            
            do {
                /// get current user info
                let actUser = try userSnap?.data(as: UserProfile.self)
                guard let activeUser = actUser else { return }
                if userSnap?.documentID ?? "" != self.uid { return } // logout + object not being destroyed
                
                if UserDataModel.shared.userInfo.id == "" {
                    UserDataModel.shared.userInfo = activeUser
                } else {
                    self.updateUserInfo(user: activeUser)
                }
                
                NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                self.titleView.profileButton.profileImage.sd_setImage(
                    with: URL(string: UserDataModel.shared.userInfo.imageURL),
                    placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .darkGray),
                    options: .highPriority, context: [.imageTransformer: transformer])
                
                for friend in UserDataModel.shared.userInfo.friendIDs {
                    self.db.collection("users").document(friend).getDocument { (friendSnap, _) in
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard let info = friendInfo else { UserDataModel.shared.userInfo.friendIDs.removeAll(where: { $0 == friend }); return }
                            
                            if !UserDataModel.shared.userInfo.friendsList.contains(where: { $0.id == friend }) && !UserDataModel.shared.deletedFriendIDs.contains(friend) {
                                
                                UserDataModel.shared.userInfo.friendsList.append(info)
                                
                                if UserDataModel.shared.userInfo.friendsList.count == UserDataModel.shared.userInfo.friendIDs.count {
                                    UserDataModel.shared.userInfo.sortFriends() /// sort for top friends
                                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                                    // show / hide new posts button if user has >1 friend
                                    self.setNewPostsButtonCount()
                                    // if listener found a new friend, re-run home fetch
                                    if self.friendsLoaded {
                                        // this is not a great solution
                                        // trying to account for posts' friendsList property not yet being updated at the time of fetch
                                        // (profile friendslist is updated first)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { NotificationCenter.default.post(name: Notification.Name("FriendsListAdd"), object: nil) }
                                    }
                                    self.friendsLoaded = true
                                }
                            }
                            
                        } catch {
                            // remove broken friend object
                            UserDataModel.shared.userInfo.friendIDs.removeAll(where: { $0 == friend })
                            return
                        }
                    }
                }
            } catch {  return }
        })
    }
    
    func updateUserInfo(user: UserProfile) {
        /// only reload if a visible value changed
        let runReload = UserDataModel.shared.userInfo.avatarURL != user.avatarURL ||
        UserDataModel.shared.userInfo.currentLocation != user.currentLocation ||
        UserDataModel.shared.userInfo.imageURL != user.imageURL ||
        UserDataModel.shared.userInfo.name != user.name ||
        UserDataModel.shared.userInfo.username != user.username
        
        // update user info fields to avoid overwriting map values
        UserDataModel.shared.userInfo.avatarURL = user.avatarURL
        UserDataModel.shared.userInfo.currentLocation = user.currentLocation
        UserDataModel.shared.userInfo.imageURL = user.imageURL
        UserDataModel.shared.userInfo.name = user.name
        UserDataModel.shared.userInfo.hiddenUsers = user.hiddenUsers
        UserDataModel.shared.userInfo.pendingFriendRequests = user.pendingFriendRequests
        UserDataModel.shared.userInfo.spotScore = user.spotScore
        UserDataModel.shared.userInfo.topFriends = user.topFriends
        UserDataModel.shared.userInfo.friendIDs = user.friendIDs
        UserDataModel.shared.userInfo.username = user.username
        let userInfo = UserDataModel.shared.userInfo
        /// update mapscollection + all posts to display accurate user info on profile edit
        if runReload {
            DispatchQueue.global().async {
                for key in self.postDictionary.keys {
                    if self.postDictionary[key] == nil { continue }
                    if self.postDictionary[key]?.posterID == self.uid { self.postDictionary[key]?.userInfo = userInfo }
                }
                /// update maps posts
                for i in 0..<UserDataModel.shared.userInfo.mapsList.count {
                    for key in UserDataModel.shared.userInfo.mapsList[i].postsDictionary.keys {
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key] == nil { continue }
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]?.posterID == self.uid {
                            UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]?.userInfo = userInfo }
                    }
                }
            }
            // reload to update avatar
            DispatchQueue.main.async { self.finishPostsLoad(resort: false, newPost: false, upload: false) }
        }
    }
    
    func getPosts() {
        // fetch all posts in last 7 days
        let seconds = Date().timeIntervalSince1970 - 86_400 * 7
        let timestamp = Timestamp(seconds: Int64(seconds), nanoseconds: 0)
        let recentQuery = db.collection("posts").whereField("timestamp", isGreaterThanOrEqualTo: timestamp)
        let friendsQuery = recentQuery.whereField("friendsList", arrayContains: uid)
        let mapsQuery = recentQuery.whereField("inviteList", arrayContains: uid)
        
        getFriendsPosts(query: friendsQuery)
        getMapPosts(query: mapsQuery)
    }
    
    func getFriendsPosts(query: Query) {
        friendsPostsListener = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            
            var newPost = false
            let postIDs = snap.documents.map({ $0.documentID })
            if self.postsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, friendsFetch: true) }
            self.friendsFetchIDs = postIDs
            if snap.documents.isEmpty { self.leaveHomeFetchGroup(newPost: false); return }
            
            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try? doc.data(as: MapPost.self)
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    if self.postsContains(postID: postInfo.id ?? "") {
                        self.updatePost(post: postInfo, map: nil)
                        continue
                    }
                    if self.filteredFromFeed(post: postInfo, friendsMap: true) { continue }
                    
                    recentGroup.enter()
                    Task(priority: .utility) {
                        if let post = await self.mapPostService?.setPostDetails(post: postInfo) {
                            DispatchQueue.main.async {
                                newPost = true
                                self.addPostToDictionary(post: post, map: nil, newPost: false)
                            }
                            recentGroup.leave()
                        }
                    }
                }
                
                recentGroup.notify(queue: .global()) {
                    self.leaveHomeFetchGroup(newPost: newPost)
                }
            }
        }
    }
    
    func getMapPosts(query: Query) {
        mapsPostsListener = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            
            var newPost = false
            let postIDs = snap.documents.map({ $0.documentID })
            if self.postsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, friendsFetch: false) }
            self.mapFetchIDs = postIDs
            if snap.documents.isEmpty { self.leaveHomeFetchGroup(newPost: false); return }
            
            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try? doc.data(as: MapPost.self)
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    guard let map = UserDataModel.shared.userInfo.mapsList.first(where: { $0.id == postInfo.mapID ?? "" }) else { continue }
                    if self.postsContains(postID: postInfo.id ?? "") {
                        self.updatePost(post: postInfo, map: map)
                        continue
                    }
                    if self.filteredFromFeed(post: postInfo, friendsMap: false) { continue }
                    
                    recentGroup.enter()
                    
                    Task {
                        if let post = await self.mapPostService?.setPostDetails(post: postInfo) {
                            DispatchQueue.main.async {
                                newPost = true
                                self.addPostToDictionary(post: post, map: nil, newPost: false)
                            }
                            recentGroup.leave()
                        }
                    }
                }
                continue
            }
            recentGroup.notify(queue: .global()) {
                self.leaveHomeFetchGroup(newPost: newPost)
            }
        }
    }
    
    func postsContains(postID: String) -> Bool {
        return postDictionary[postID] != nil
    }
    
    func filteredFromFeed(post: MapPost, friendsMap: Bool) -> Bool {
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86_400
        return (post.userInfo?.id?.isBlocked() ?? false) ||
        (post.hiddenBy?.contains(self.uid) ?? false) ||
        (friendsMap && !UserDataModel.shared.userInfo.friendsContains(id: post.posterID))
        || (post.timestamp.seconds < Int64(yesterdaySeconds) && (post.seenList?.contains(self.uid) ?? false))
    }
    
    func addPostToDictionary(post: MapPost, map: CustomMap?, newPost: Bool) {
        // Run post contains again in case added on async fetch
        if postsContains(postID: post.id ?? "") { return }
        postDictionary.updateValue(post, forKey: post.id ?? "")
        
        let groupData = updateFriendsPostGroup(post: post, spot: nil)
        // only add annotation immediately if not initial fetch
        if postsFetched {
            let map = getFriendsMapObject()
            mapView.addPostAnnotation(group: groupData.group, newGroup: groupData.newGroup, map: map)
        }
    }
    
    func updatePost(post: MapPost, map: CustomMap?) {
        Task {
            // use old post to only update values that CHANGE -> comments and likers
            var oldPost = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            if let map, let post = map.postsDictionary[post.id ?? ""] {
                oldPost = post
            } else if let post = postDictionary[post.id ?? ""] {
                oldPost = post
            } else {
                return
            }
            
            oldPost.likers = post.likers
            if post.commentCount != oldPost.commentCount {
                let comments = try await mapPostService?.getComments(postID: post.id ?? "") ?? []
                oldPost.commentList = comments
                oldPost.commentCount = post.commentCount
            }
            self.postDictionary[post.id ?? ""] = oldPost
        }
    }
    
    func checkForPostDelete(postIDs: [String], friendsFetch: Bool) -> Bool {
        // check which id is not included in postIDs from previous fetch
        var spotID = ""
        
        var post = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
        if friendsFetch, let postID = friendsFetchIDs.first(where: { !postIDs.contains($0) }) {
            // check came from friends fetch
            if let friendsPost = postDictionary[postID] { post = friendsPost }
            
        } else if let postID = mapFetchIDs.first(where: { !postIDs.contains($0) }) {
            // check came from maps fetch
            if let mapPost = postDictionary[postID] { post = mapPost }
            
        } else {
            return false
        }
        
        UserDataModel.shared.deletedPostIDs.append(post.id ?? "")
        if let group = postGroup.first(where: { $0.id == post.spotID ?? "" }), group.postIDs.count == 1 { spotID = group.id }
        removePost(post: post, spotID: spotID, mapID: "", mapDelete: false)
        return true
    }
    
    func getMaps() {
        mapsListener = db.collection("maps").whereField("likers", arrayContains: uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            for doc in snap.documents {
                do {
                    let mapIn = try? doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { continue }
                    if UserDataModel.shared.deletedMapIDs.contains(where: { $0 == mapInfo.id }) { continue }
                    if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapInfo.id }) {
                        self.updateMap(map: mapInfo, index: i)
                        continue
                    }
                    mapInfo.addSpotGroups()
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                }
            }
            
            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
            UserDataModel.shared.userInfo.sortMaps()
            
            // fetch group aleady entered before getMaps call
            self.homeFetchGroup.enter()
            self.getPosts()
        })
    }
    
    func updateMap(map: CustomMap, index: Int) {
        // might not need to update values separately on new fetch
        let oldMap = UserDataModel.shared.userInfo.mapsList[index]
        var newMap = map
        newMap.postsDictionary = oldMap.postsDictionary
        newMap.postGroup = oldMap.postGroup
        UserDataModel.shared.userInfo.mapsList[index] = newMap
    }
    
    func setNewPostsButtonCount() {
        newPostsButton.totalPosts = postDictionary.count
        newPostsButton.unseenPosts = postDictionary.filter { !$0.value.seen }.count
    }
    
    func checkForActivityIndicator() {
        if !postsFetched {
            DispatchQueue.main.async { self.mapActivityIndicator.startAnimating(duration: 1.5) }
        }
    }
}
