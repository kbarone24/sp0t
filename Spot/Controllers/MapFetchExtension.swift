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
                print("not hidden")
                self.newPostsButton.isHidden = self.sheetView != nil
                self.newPostsButton.totalPosts = self.friendsPostsDictionary.count
                self.loadAdditionalOnboarding()
                self.reloadMapsCollection(resort: true, newPost: false)
            }
        }
    }
    
    func reloadMapsCollection(resort: Bool, newPost: Bool) {
        if resort {
            /// reset selected item index on resort in case the position of the selected map changed
            let mapID = UserDataModel.shared.userInfo.mapsList[safe: selectedItemIndex - 1]?.id ?? ""
            UserDataModel.shared.userInfo.sortMaps()
            if let index = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == mapID}) { selectedItemIndex = index + 1 } else { selectedItemIndex = 0 }
        }
        
        let scrollPosition: UICollectionView.ScrollPosition = resort ? .left : []
        /// select new map on add from onboarding
        if newMapID != nil, let index = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == newMapID}) {
            selectMapAt(index: index + 1)
            newMapID = nil
        }
        
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
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                self.titleView.profileButton.profileImage.sd_setImage(with: URL(string: UserDataModel.shared.userInfo.imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])

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
        if map == nil || map?.id ?? "" == "" || (newPost && !(post.hideFromFeed ?? false) && UserDataModel.shared.userInfo.friendsContains(id: post.posterID)) {
            friendsPostsDictionary.updateValue(post, forKey: post.id!)
            let groupData = updateFriendsPostGroup(post: post)
            if index == 0 {
                let map = getFriendsMapObject()
                mapView.addPostAnnotation(group: groupData.group, newGroup: groupData.newGroup, map: map)
            }
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
        mapsListener = db.collection("maps").whereField("likers", arrayContains: uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            for doc in snap.documents {
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { continue }
                    
                    if UserDataModel.shared.deletedMapIDs.contains(where: {$0 == mapInfo.id}) { continue }
                    if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == mapInfo.id}) {
                        self.updateMap(map: mapInfo, index: i)
                        continue
                    }
                    
                    mapInfo.addSpotGroups()
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                    self.homeFetchGroup.enter()
                    self.getRecentPosts(map: mapInfo)
                    
                    /// add new notify method for new map since initial notify method wont be called
                    if self.mapsLoaded {
                        self.homeFetchGroup.notify(queue: .main) { [weak self] in
                            guard let self = self else { return }
                            self.reloadMapsCollection(resort: true, newPost: false)
                        }
                    }
                    
                } catch {
                    continue
                }
            }
            self.mapsLoaded = true
            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
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
                    
                    if self.hasNewPostAccess(post: postInfo, map: map) {
                        self.finishNewMapPostLoad(postInfo: postInfo, map: map)
                    }
                   
                } catch {
                    return
                }
            }
        })
    }
        
    func hasNewPostAccess(post: MapPost, map: CustomMap?) -> (Bool) {
        if map == nil {
            return post.friendsList.contains(uid)
        }
        return true
    }
    
    /*
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
    } */

    func finishNewMapPostLoad(postInfo: MapPost, map: CustomMap?) {
        /// check map dictionary for add
        if !self.postsContains(postID: postInfo.id!, mapID: postInfo.mapID ?? "", newPost: true) {
            self.setPostDetails(post: postInfo) { [weak self] post in
                guard let self = self else { return }
                if !self.postsContains(postID: post.id!, mapID: post.mapID ?? "", newPost: true) {
                    DispatchQueue.main.async {
                        self.addPostToDictionary(post: post, map: map, newPost: true, index: self.selectedItemIndex)
                  ///      let resort = self.selectedItemIndex == 0 /// patch fix for selected index getting messed up on resort if index > 0
                        self.reloadMapsCollection(resort: true, newPost: true)
                    }
                }
            }
        }
    }
    
    func getSortedCoordinates() -> [CLLocationCoordinate2D] {
        let map = getSelectedMap()
        /// filter for spots without posts
        var group = map == nil ? postGroup.filter({!$0.postIDs.isEmpty}) : map!.postGroup.filter({!$0.postIDs.isEmpty})
        
        if group.contains(where: {$0.postIDs.contains(where: {!$0.seen})}) { group = group.filter({$0.postIDs.contains(where: {!$0.seen})})}
        group = mapView.sortPostGroup(group)
        return group.map({$0.coordinate})
    }
    
    func setNewPostsButtonCount() {
        let map = getSelectedMap()
        newPostsButton.unseenPosts = map == nil ? friendsPostsDictionary.filter{!$0.value.seen}.count : map!.postsDictionary.filter{!$0.value.seen}.count
        /// show new posts button on friends map if the user has a friend (no real way of checking if that friend has actually posted to friends map)
        newPostsButton.totalPosts = map == nil ? UserDataModel.shared.userInfo.friendIDs.count > 1 ? 1 : 0 : map!.postIDs.count
    }
    
        
    func checkForActivityIndicator() -> Bool {
        /// resume frozen indicator
        if mapsCollection != nil, let cell = mapsCollection.cellForItem(at: IndexPath(item: 0, section: 0)) as? MapLoadingCell {
            DispatchQueue.main.async { cell.activityIndicator.startAnimating() }
            return true
        }
        return false
    }
    
    func reRunMapFetch() {
        homeFetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getRecentPosts(map: nil)
        }
        
        for map in UserDataModel.shared.userInfo.mapsList {
            homeFetchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.getRecentPosts(map: map)
            }
        }
        
        homeFetchGroup.notify(queue: .main) {
          //  let resort = self.selectedItemIndex == 0
            self.reloadMapsCollection(resort: true, newPost: false)
        }
    }
}

/// friend postGroup methods
extension MapController {
    func updateFriendsPostGroup(post: MapPost) -> (group: MapPostGroup?, newGroup: Bool) {
        if post.spotID ?? "" == "" {
            /// attach by postID
            let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            let newGroup = MapPostGroup(id: post.id!, coordinate: coordinate, spotName: "", postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)])
            postGroup.append(newGroup)
            return (newGroup, true)
            
        } else if !postGroup.contains(where: {$0.id == post.spotID!}) {
            let coordinate = CLLocationCoordinate2D(latitude: post.spotLat!, longitude: post.spotLong!)
            let newGroup = MapPostGroup(id: post.spotID!, coordinate: coordinate, spotName: post.spotName!, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)])
            postGroup.append(newGroup)
            return (newGroup, true)

        } else if let i = postGroup.firstIndex(where: {$0.id == post.spotID}) {
            if !postGroup[i].postIDs.contains(where: {$0.id == post.id}) {
                postGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen))
                postGroup[i].sortPostIDs()
                return (postGroup[i], false)
            }
        }
        return (nil, false)
    }

    func updateFriendsPostGroupSeen(postID: String) {
        if let i = postGroup.firstIndex(where: {$0.postIDs.contains(where: {$0.id == postID})}) {
            if let j = postGroup[i].postIDs.firstIndex(where: {$0.id == postID}) {
                postGroup[i].postIDs[j].seen = true
                postGroup[i].sortPostIDs()
            }
        }
    }

    func removeFromFriendsPostGroup(postID: String, spotID: String) {
        /// remove id from post group
        if let i = postGroup.firstIndex(where: {$0.postIDs.contains(where: {$0.id == postID})}) {
            if let j = postGroup[i].postIDs.firstIndex(where: {$0.id == postID}) {
                postGroup[i].postIDs.remove(at: j)
                /// remove from post group entirely if no spot attached
                if postGroup[i].postIDs.count == 0 && postGroup[i].spotName == "" { postGroup.remove(at: i) }
            }
        }
        
        if spotID != "" { postGroup.removeAll(where: {$0.id == spotID}) }
    }
}
