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

extension MapController {
    
    func runMapFetches() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getFriends()
        }
    }
    
    @objc func notifyUserLoad(_ notification: NSNotification) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.getMaps()
        }
    }
    
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        friendsLoaded = true
        
        homeFetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async { self.getRecentPosts(map: nil) }
        
        homeFetchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if !self.feedLoaded {
                self.feedLoaded = true
                self.attachNewPostListener()
            }
            self.reloadMapsCollection()
        }
    }
    
    func reloadMapsCollection() {
        /// sort first by maps that have an unseen post, then by most recent post timestamp
        UserDataModel.shared.userInfo.mapsList.sort(by: {$0.postsDictionary.contains(where: {!$0.value.seen}) && $1.postsDictionary.contains(where: {!$0.value.seen}) ? $0.postTimestamps.last!.seconds > $1.postTimestamps.last!.seconds : $0.postsDictionary.contains(where: {!$0.value.seen}) && !$1.postsDictionary.contains(where: {!$0.value.seen})})

        DispatchQueue.main.async {
            self.mapsCollection.reloadData()
            self.mapsCollection.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .left)
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
    
    func getFriends() {
        
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
                
                UserDataModel.shared.userInfo = activeUser
                if UserDataModel.shared.userInfo.profilePic == UIImage() { self.getUserProfilePics() }
                
                UserDataModel.shared.friendIDs = userSnap?.get("friendsList") as? [String] ?? []
                for id in self.deletedFriendIDs { UserDataModel.shared.friendIDs.removeAll(where: {$0 == id}) } /// unfriended friend reentered from cache
                NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))

                let friendsListGroup = DispatchGroup()
                friendsListGroup.enter()
                var leftDummy = false /// enter friends list group immediately due to group leaving before loop executes
                friendsListGroup.notify(queue: .global()) {
                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                }

                for friend in UserDataModel.shared.friendIDs {
                    DispatchQueue.main.async { friendsListGroup.enter() }
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        if !leftDummy { friendsListGroup.leave(); leftDummy = true }
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard var info = friendInfo else { UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend}); if !self.friendsLoaded { friendsListGroup.leave() }; return }

                            info.id = friendSnap!.documentID
                            if !UserDataModel.shared.friendsList.contains(where: {$0.id == friend}) {
                                UserDataModel.shared.friendsList.append(info)
                            }
                            if !self.friendsLoaded { friendsListGroup.leave() }
                            
                        } catch {
                            /// remove broken friend object
                            UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend})
                            if !self.friendsLoaded { friendsListGroup.leave() }
                            return
                        }
                    }
                }
            } catch {  return }
        })
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
                        if post.id ?? "" != "" { self.addPostToDictionary(post: post, map: map) }
                        recentGroup.leave()
                    }
                    continue
                    
                } catch {
                    print("catch")
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
        if map == nil {
            friendsPostsDictionary[post.id!] = post
            /// add to group containing all of this posterIDs posts
            if !friendsPostsGroup.contains(where: {$0.posterID == post.posterID}) {
                friendsPostsGroup.append(FriendsPostGroup(posterID: post.posterID, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)]))
                
            } else if let i = friendsPostsGroup.firstIndex(where: {$0.posterID == post.posterID}) {
                if !friendsPostsGroup[i].postIDs.contains(where: {$0.0 == post.id!}) {
                    friendsPostsGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen))
                    friendsPostsGroup[i].postIDs.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
                }
            }
        } else {
            /// map posts are sorted by spot rather than user
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == map!.id!}) {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[post.id!] = post
                if post.spotID == "" || !map!.postGroup.contains(where: {$0.spotID == post.spotID!}) {
                    UserDataModel.shared.userInfo.mapsList[i].postGroup.append(MapPostGroup(spotID: post.spotID!, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)]))
                } else if let i = map!.postGroup.firstIndex(where: {$0.spotID == post.id}) {
                    UserDataModel.shared.userInfo.mapsList[i].postGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen))
                    UserDataModel.shared.userInfo.mapsList[i].postGroup[i].postIDs.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
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
        db.collection("users").document(uid).collection("mapsList").getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for doc in snap.documents {
                let last = doc == snap.documents.last
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard let mapInfo = mapIn else { if last { self.homeFetchGroup.leave() }; continue }
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
                                    self.addPostToDictionary(post: postInfo, map: map)
                                    self.reloadMapsCollection()
                                }
                            }
                        }
                    }
                
                    if postInfo.friendsList.contains(self.uid) {
                        if !self.postsContains(postID: postInfo.id!, mapID: "") {
                            self.setPostDetails(post: postInfo) { [weak self] post in
                                guard let self = self else { return }
                                self.addPostToDictionary(post: postInfo, map: nil)
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
}
