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
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("get maps", Timestamp(date: Date()).seconds - self.startTime)
            self.getMaps()
            self.homeFetchGroup.enter()
            self.getRecentPosts(map: nil)
            
            /// home fetch group once here and once for maps posts
            self.homeFetchGroup.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                print("home fetch", Timestamp(date: Date()).seconds - self.startTime)
                if !self.feedLoaded {
                    self.feedLoaded = true
                    self.attachNewPostListener()
                }
                self.newPostsButton.isHidden = false
                self.reloadMapsCollection()
            }
        }
    }
    
    func reloadMapsCollection() {
        UserDataModel.shared.userInfo.sortMaps()
        
        DispatchQueue.main.async {
            self.mapsCollection.reloadData()
            self.mapsCollection.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
            self.centerMapOnPosts(animated: true)
            self.setNewPostsButtonCount()
        }
    }
    
    func getAdmins() {
        
        self.db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, err) in
            if err != nil { return }
            for admin in snap!.documents { UserDataModel.shared.adminIDs.append(admin.documentID) }
        }
        
        ///opt kenny/ellie/tyler/b0t/hog/hog0 out of tracking
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" || uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" || uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" || uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" || uid == "QgwnBsP9mlSudEuONsAsyVqvWEZ2" || uid == "X6CB24zc4iZFE8maYGvlxBp1mhb2" {
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
                
                UserDataModel.shared.friendIDs = userSnap?.get("friendsList") as? [String] ?? []
                for id in self.deletedFriendIDs { UserDataModel.shared.friendIDs.removeAll(where: {$0 == id}) } /// unfriended friend reentered from cache
                NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))

                for friend in UserDataModel.shared.friendIDs {
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard let info = friendInfo else { UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend}); return }
                            if !UserDataModel.shared.friendsList.contains(where: {$0.id == friend}) {
                                UserDataModel.shared.friendsList.append(info)
                            }
                            
                        } catch {
                            /// remove broken friend object
                            UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                            return
                        }
                    }
                }
            } catch {  return }
        })
    }
    
    func updateUserInfo(user: UserProfile) {
        // update user info fields to avoid overwriting map values
        print("update user info")
        UserDataModel.shared.userInfo.avatarURL = user.avatarURL
        UserDataModel.shared.userInfo.currentLocation = user.currentLocation
        UserDataModel.shared.userInfo.imageURL = user.imageURL
        UserDataModel.shared.userInfo.name = user.name
        UserDataModel.shared.userInfo.pendingFriendRequests = user.pendingFriendRequests
        UserDataModel.shared.userInfo.spotScore = user.spotScore
        UserDataModel.shared.userInfo.topFriends = user.topFriends
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
        let seconds = Date().timeIntervalSince1970 - 86400 * 50
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86400 * 40
        let timestamp = Timestamp(seconds: Int64(seconds), nanoseconds: 0)
        var recentQuery = db.collection("posts").whereField("timestamp", isGreaterThanOrEqualTo: timestamp)
        if map != nil { recentQuery = recentQuery.whereField("mapID", isEqualTo: map!.id!) }
        
        recentQuery.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            if snap.documents.count == 0 { self.homeFetchGroup.leave(); return }

            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    if self.postsContains(postID: postInfo.id!, mapID: map?.id ?? "") { self.updatePost(post: postInfo, map: map); continue }
                    /// check seenList if older than 24 hours
                    if postInfo.timestamp.seconds < Int64(yesterdaySeconds) && postInfo.seenList!.contains(self.uid) { continue }
                    
                    recentGroup.enter()
                    self.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        if post.id ?? "" != "" {
                            DispatchQueue.main.async {
                                self.addPostToDictionary(post: post, map: map)
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

    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void) {
        var postInfo = post
        
        /// detail group tracks comments and added users fetches
        let detailGroup = DispatchGroup()
        detailGroup.enter()
        getUserInfo(userID: postInfo.posterID) { user in
            postInfo.userInfo = user
            detailGroup.leave()
        }
        
        detailGroup.enter()
        self.getComments(postID: postInfo.id!) { comments in
            postInfo.commentList = comments
            detailGroup.leave()
        }
        
        detailGroup.enter()
        /// taggedUserGroup tracks tagged user fetch
        let taggedUserGroup = DispatchGroup()
        for userID in postInfo.taggedUserIDs ?? [] {
            taggedUserGroup.enter()
            self.getUserInfo(userID: userID) { user in
                postInfo.addedUserProfiles!.append(user)
                taggedUserGroup.leave()
            }
        }
        
        taggedUserGroup.notify(queue: .global()) {
            detailGroup.leave()
        }
        detailGroup.notify(queue: .global()) {
            completion(postInfo)
            return
        }
    }
    
    func postsContains(postID: String, mapID: String) -> Bool {
        if mapID == "" {
            return self.friendsPostsDictionary[postID] != nil
        } else {
            if let map = UserDataModel.shared.userInfo.mapsList.first(where: {$0.id == mapID}) {
                return map.postsDictionary[postID] != nil
            }
        }
        return false
    }
    
    func addPostToDictionary(post: MapPost, map: CustomMap?) {
        postsList.append(post)
        if selectedItemIndex == 0 { addPostAnnotation(post: post) } /// 0 always selected on initial fetch
        
        if map == nil {
            friendsPostsDictionary.updateValue(post, forKey: post.id!)
            
        } else {
            /// map posts are sorted by spot rather than user
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == map!.id!}) {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary.updateValue(post, forKey: post.id!)
             //   UserDataModel.shared.userInfo.mapsList[i].postsDictionary[post.id!] = post
                if post.spotID ?? "" == "" {
                    /// attach by postID
                    let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
                    UserDataModel.shared.userInfo.mapsList[i].postGroup.append(MapPostGroup(id: post.id!, coordinate: coordinate, spotName: "", postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)]))

                } else if !map!.postGroup.contains(where: {$0.id == post.spotID!}) {
                    let coordinate = CLLocationCoordinate2D(latitude: post.spotLat!, longitude: post.spotLong!)
                    UserDataModel.shared.userInfo.mapsList[i].postGroup.append(MapPostGroup(id: post.spotID!, coordinate: coordinate, spotName: post.spotName!, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)]))
                    
                } else if let i = map!.postGroup.firstIndex(where: {$0.id == post.spotID}) {
                    UserDataModel.shared.userInfo.mapsList[i].postGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen))
                    UserDataModel.shared.userInfo.mapsList[i].postGroup[i].sortPostIDs()
                }
            }
        }
    }

    func updatePost(post: MapPost, map: CustomMap?) {
        var post = post
        let oldPost = map == nil ? friendsPostsDictionary[post.id!] : map!.postsDictionary[post.id!]
        if (post.likers.count != oldPost!.likers.count) || (post.commentCount != oldPost!.commentCount) {
            post.likers = oldPost!.likers
            if post.commentCount != oldPost!.commentCount {
                getComments(postID: post.id!) { [weak self] comments in
                    guard let self = self else { return }
                    post.commentList = comments
                    self.updatePostDictionary(post: post, mapID: map?.id ?? "")
                }
            } else {
                updatePostDictionary(post: post, mapID: map?.id ?? "")
            }
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
        db.collection("maps").whereField("memberIDs", arrayContains: uid).getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for doc in snap.documents {
                let last = doc == snap.documents.last
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { if last { self.homeFetchGroup.leave() }; continue }
                    /// append spots to show on map even if there's no post attached
                    if !mapInfo.spotIDs.isEmpty {
                        for i in 0...mapInfo.spotIDs.count - 1 {
                            let coordinate = CLLocationCoordinate2D(latitude: mapInfo.spotLocations[safe: i]?["lat"] ?? 0.0, longitude: mapInfo.spotLocations[safe: i]?["long"] ?? 0.0)
                            mapInfo.postGroup.append(MapPostGroup(id: mapInfo.spotIDs[i], coordinate: coordinate, spotName: mapInfo.spotNames[safe: i] ?? "", postIDs: []))
                        }
                    }
                    
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                    self.homeFetchGroup.enter()
                    self.getRecentPosts(map: mapInfo)
                } catch {
                    continue
                }
            }
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
                    if postInfo.mapID != "" {
                        /// check map dictionary for add
                        if let map = UserDataModel.shared.userInfo.mapsList.first(where: {$0.id == postInfo.mapID}) {
                            if !self.postsContains(postID: postInfo.id!, mapID: postInfo.mapID!) {
                                self.setPostDetails(post: postInfo) { [weak self] post in
                                    guard let self = self else { return }
                                    self.addPostToDictionary(post: post, map: map)
                                    self.reloadMapsCollection()
                                }
                            }
                        }
                    }
                
                    if postInfo.friendsList.contains(self.uid) {
                        if !self.postsContains(postID: postInfo.id!, mapID: "") {
                            self.setPostDetails(post: postInfo) { [weak self] post in
                                guard let self = self else { return }
                                self.addPostToDictionary(post: post, map: nil)
                                self.reloadMapsCollection()
                            }
                        }
                    }

                } catch {
                    return
                }
            }
        }
    }
    
    func sortPosts(_ posts: [MapPost]) -> [MapPost] {
        posts.sorted(by: { p1, p2 in
            guard p1.seen == p2.seen else {
                return !p1.seen && p2.seen
            }
            
            return p1.timestamp.seconds > p2.timestamp.seconds
        })
    }
    
    func sortPostGroup(_ group: [MapPostGroup]) -> [MapPostGroup] {
        /// MapPostGroup postIDs will already be sorted
        group.sorted(by: { g1, g2 in
            guard (g1.postIDs.first?.seen ?? true) == (g2.postIDs.first?.seen ?? true) else {
                return !(g1.postIDs.first?.seen ?? true) && (g2.postIDs.first?.seen ?? true)
            }
            return g1.postIDs.first?.timestamp.seconds ?? 0 > g2.postIDs.first?.timestamp.seconds ?? 0
        })
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
}
