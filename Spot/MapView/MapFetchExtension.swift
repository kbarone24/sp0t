//
//  MapFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//
import Firebase
import FirebaseUI
import Foundation
import MapKit
import Mixpanel
import UIKit

extension MapController {
    func runMapFetches() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getActiveUser()
        }
    }
    
    @objc func notifyUserLoad(_ notification: NSNotification) {
        if userLoaded { return }
        userLoaded = true
        DispatchQueue.global(qos: .userInitiated).async {
            self.homeFetchGroup.enter()
            self.getMaps()

            // home fetch group once here and once for maps posts
            self.homeFetchGroup.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.postsFetched = true
                self.newPostsButton.isHidden = self.sheetView != nil
                self.newPostsButton.totalPosts = self.friendsPostsDictionary.count
                self.loadAdditionalOnboarding()
                self.reloadMapsCollection(resort: true, newPost: false)
            }
        }
    }

    func leaveHomeFetchGroup(newPost: Bool) {
        if !postsFetched {
            homeFetchGroup.leave()
        } else {
            if newPost {
                // eventually want to resort here but was causing exc_bad_access
                DispatchQueue.main.async { self.reloadMapsCollection(resort: true, newPost: true) }
            }
        }
    }

    func reloadMapsCollection(resort: Bool, newPost: Bool) {
        if resort {
            /// reset selected item index on resort in case the position of the selected map changed
            let mapID = UserDataModel.shared.userInfo.mapsList[safe: selectedItemIndex - 1]?.id ?? ""
            UserDataModel.shared.userInfo.sortMaps()
            if let index = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapID }) { selectedItemIndex = index + 1 } else { selectedItemIndex = 0 }
        }
        
        let scrollPosition: UICollectionView.ScrollPosition = resort ? .left : []
        /// select new map on add from onboarding
        if newMapID != nil, let index = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == newMapID }) {
            selectMapAt(index: index + 1)
            newMapID = nil
        }

        mapsCollection.reloadData()
        mapsCollection.selectItem(at: IndexPath(item: selectedItemIndex, section: 0), animated: false, scrollPosition: scrollPosition)
        if resort && !newPost { centerMapOnMapPosts(animated: true) }
        setNewPostsButtonCount()
    }
    
    func getAdmins() {
        self.db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, _) in
            guard let snap = snap else { return }
            for doc in snap.documents { UserDataModel.shared.adminIDs.append(doc.documentID)
            }
        }
        // opt kenny/ellie/tyler/b0t/hog/hog0 out of tracking
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" ||
            uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" ||
            uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" ||
            uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" ||
            uid == "X6CB24zc4iZFE8maYGvlxBp1mhb2" ||
            uid == "HhDmknXyHDdWF54t6s8IEbEBlXD2" ||
            uid == "oAKwM2NgLjTlaE2xqvKEXiIVKYu1" {
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
                self.titleView?.profileButton.profileImage.sd_setImage(
                    with: URL(string: UserDataModel.shared.userInfo.imageURL),
                    placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .black),
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
        /// update mapscollection + all posts to display accurate user info on profile edit
        if runReload {
            DispatchQueue.global().async {
                for key in self.friendsPostsDictionary.keys {
                    if self.friendsPostsDictionary[key] == nil { continue }
                    if self.friendsPostsDictionary[key]?.posterID == self.uid { self.friendsPostsDictionary[key]?.userInfo = UserDataModel.shared.userInfo }
                }
                /// update maps posts
                for i in 0..<UserDataModel.shared.userInfo.mapsList.count {
                    for key in UserDataModel.shared.userInfo.mapsList[i].postsDictionary.keys {
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key] == nil { continue }
                        if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]?.posterID == self.uid {
                            UserDataModel.shared.userInfo.mapsList[i].postsDictionary[key]?.userInfo = UserDataModel.shared.userInfo }
                    }
                }
            }
            // reload to update avatar
            DispatchQueue.main.async { self.reloadMapsCollection(resort: false, newPost: false) }
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
            if self.postsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, mapFetch: false) }
            if snap.documents.isEmpty { self.leaveHomeFetchGroup(newPost: false); return }

            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    /// filter new post on initial db write
                    if doc.get("g") as? String == nil { continue }
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    if self.postsContains(postID: postInfo.id ?? "", mapID: "", newPost: false) {
                        self.updatePost(post: postInfo, map: nil)
                        continue
                    }
                    if self.filteredFromFeed(post: postInfo, friendsMap: true) { continue }

                    recentGroup.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        if post.id ?? "" != "" {
                            DispatchQueue.main.async {
                                newPost = true
                                self.addPostToDictionary(post: post, map: nil, newPost: false, index: self.selectedItemIndex)
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
                self.leaveHomeFetchGroup(newPost: newPost)
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
            if self.postsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, mapFetch: true) }
            self.mapFetchIDs = postIDs
            if snap.documents.isEmpty { self.leaveHomeFetchGroup(newPost: false); return }

            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    /// filter new post on initial db write
                    if doc.get("g") as? String == nil { continue }
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    guard let map = UserDataModel.shared.userInfo.mapsList.first(where: { $0.id == postInfo.mapID ?? "" }) else { continue }
                    if self.postsContains(postID: postInfo.id ?? "", mapID: map.id ?? "", newPost: false) {
                        self.updatePost(post: postInfo, map: map)
                        continue
                    }
                    if self.filteredFromFeed(post: postInfo, friendsMap: false) { continue }

                    recentGroup.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        if post.id ?? "" != "" {
                            DispatchQueue.main.async {
                                newPost = true
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
                self.leaveHomeFetchGroup(newPost: newPost)
            }
        }
    }
    
    func postsContains(postID: String, mapID: String, newPost: Bool) -> Bool {
        if mapID == "" || newPost {
            if self.friendsPostsDictionary[postID] != nil { return true }
        }
        if mapID != "" {
            if let map = UserDataModel.shared.userInfo.mapsList.first(where: { $0.id == mapID }) {
                return map.postsDictionary[postID] != nil
            }
        }
        return false
    }

    func filteredFromFeed(post: MapPost, friendsMap: Bool) -> Bool {
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86_400
        return (post.userInfo?.id?.isBlocked() ?? false) ||
        (post.hiddenBy?.contains(self.uid) ?? false) ||
        (friendsMap && !UserDataModel.shared.userInfo.friendsContains(id: post.posterID)) ||
        (post.timestamp.seconds < Int64(yesterdaySeconds) && (post.seenList?.contains(self.uid) ?? false))
    }

    func addPostToDictionary(post: MapPost, map: CustomMap?, newPost: Bool, index: Int) {
        // add new post to both dictionaries. Run post contains again in case added on async fetch
        if postsContains(postID: post.id ?? "", mapID: map?.id ?? "", newPost: newPost) { return }
        if map == nil || map?.id ?? "" == "" || (newPost && !(post.hideFromFeed ?? false) && UserDataModel.shared.userInfo.friendsContains(id: post.posterID)) {
            friendsPostsDictionary.updateValue(post, forKey: post.id ?? "")
            let groupData = updateFriendsPostGroup(post: post)
            if index == 0 {
                let map = getFriendsMapObject()
                mapView.addPostAnnotation(group: groupData.group, newGroup: groupData.newGroup, map: map)
            }
        }
        if let map, let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == map.id ?? "" }) {
            UserDataModel.shared.userInfo.mapsList[i].postsDictionary.updateValue(post, forKey: post.id ?? "")
            _ = UserDataModel.shared.userInfo.mapsList[i].updateGroup(post: post)
            if index - 1 == i && self.sheetView == nil {
                // remove and re-add annotation
                addMapAnnotations(index: index, reload: true)
            }
        }
    }
    
    func updatePost(post: MapPost, map: CustomMap?) {
        Task {
            // use old post to only update values that CHANGE -> comments and likers
            var oldPost = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            if let map, let post = map.postsDictionary[post.id ?? ""] {
                oldPost = post
            } else if let post = friendsPostsDictionary[post.id ?? ""] {
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
            
            DispatchQueue.main.async {
                self.updatePostDictionary(post: oldPost, mapID: map?.id ?? "")
            }
        }
    }
    
    func updatePostDictionary(post: MapPost, mapID: String) {
        if mapID == "" {
            self.friendsPostsDictionary[post.id ?? ""] = post
        } else {
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == post.id ?? "" }) {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[post.id ?? ""] = post
            }
        }
    }

    func checkForPostDelete(postIDs: [String], mapFetch: Bool) -> Bool {
        // check which id is not included in postIDs from previous fetch
        if mapFetch {
            if let id = mapFetchIDs.first(where: { !postIDs.contains($0) }) {
                UserDataModel.shared.deletedPostIDs.append(id)
                for map in UserDataModel.shared.userInfo.mapsList {
                    if let post = map.postsDictionary[id] {
                        var spotID = ""
                        // pass through spotID if this is the only post to this post group
                        if let group = map.postGroup.first(where: { $0.id == post.spotID ?? "" }), group.postIDs.count == 1 { spotID = group.id }
                        removePost(post: post, spotID: spotID, mapID: map.id ?? "", mapDelete: map.postIDs.count == 1 )
                        print("remove post map")
                        return true
                    }
                }
            }
        } else if let post = friendsPostsDictionary.first(where: { !postIDs.contains($0.key) }) {
            UserDataModel.shared.deletedPostIDs.append(post.key)
            var spotID = ""
            if let group = postGroup.first(where: { $0.id == post.value.spotID ?? "" }), group.postIDs.count == 1 { spotID = group.id }
            removePost(post: post.value, spotID: spotID, mapID: "", mapDelete: false)
            print("remove post friends")
            return true
        }
        return false
    }

    func getMaps() {
        mapsListener = db.collection("maps").whereField("likers", arrayContains: uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            for doc in snap.documents {
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { continue }
                    
                    if UserDataModel.shared.deletedMapIDs.contains(where: { $0 == mapInfo.id }) { continue }
                    if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapInfo.id }) {
                        self.updateMap(map: mapInfo, index: i)
                        continue
                    }
                    mapInfo.addSpotGroups()
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)

                } catch {
                    continue
                }
            }
            self.mapsLoaded = true
            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
            // fetch group aleady entered before getMaps call
            self.homeFetchGroup.enter()
            self.getPosts()
        })
    }
    
    func updateMap(map: CustomMap, index: Int) {
        /// only reload if display content changes
        let oldMap = UserDataModel.shared.userInfo.mapsList[index]
        let reload = oldMap.mapName != map.mapName || oldMap.imageURL != map.imageURL || oldMap.secret != map.secret
        
        UserDataModel.shared.userInfo.mapsList[index].memberIDs = map.memberIDs
        UserDataModel.shared.userInfo.mapsList[index].likers = map.likers
        UserDataModel.shared.userInfo.mapsList[index].memberProfiles = map.memberProfiles
        UserDataModel.shared.userInfo.mapsList[index].imageURL = map.imageURL
        UserDataModel.shared.userInfo.mapsList[index].mapName = map.mapName
        UserDataModel.shared.userInfo.mapsList[index].mapDescription = map.mapDescription
        UserDataModel.shared.userInfo.mapsList[index].secret = map.secret
        
        if reload {
            DispatchQueue.main.async { self.reloadMapsCollection(resort: false, newPost: false) }
        }
    }

    func setNewPostsButtonCount() {
        let map = getSelectedMap()
        newPostsButton.unseenPosts = map == nil ? friendsPostsDictionary.filter { !$0.value.seen }.count : map?.postsDictionary.filter { !$0.value.seen }.count ?? 0
        // show new posts button on friends map if the user has a friend (no real way of checking if that friend has actually posted to friends map)
        newPostsButton.totalPosts = map == nil ? UserDataModel.shared.userInfo.friendIDs.count > 1 ? 1 : 0 : map?.postIDs.count ?? 0
    }
    
    func checkForActivityIndicator() -> Bool {
        /// resume frozen indicator
        if  let cell = mapsCollection.cellForItem(at: IndexPath(item: 0, section: 0)) as? MapLoadingCell {
            DispatchQueue.main.async { cell.activityIndicator.startAnimating() }
            return true
        }
        return false
    }
}
