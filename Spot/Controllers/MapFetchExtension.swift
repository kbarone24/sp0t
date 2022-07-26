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
    
    @objc func notifyFriendsLoad(_ notification: NSNotification) {
        friendsLoaded = true
                
        homeFetchGroup.enter()
        homeFetchGroup.enter()
        getFriendPosts()
        getMaps()
        getUnseenPosts()
        
        homeFetchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.feedLoaded = true
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
                                
                let friendsListGroup = DispatchGroup()
                
                friendsListGroup.notify(queue: .global()) {
                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                }

                for friend in UserDataModel.shared.friendIDs {
                    friendsListGroup.enter()
                    self.db.collection("users").document(friend).getDocument { (friendSnap, err) in
                        do {
                            let friendInfo = try friendSnap?.data(as: UserProfile.self)
                            guard var info = friendInfo else { UserDataModel.shared.friendIDs.removeAll(where: {$0 == friend}); friendsListGroup.leave(); return }

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
                friendsListGroup.leave() /// initial user leave
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


    func getFriendPosts() {
        
        let postsGroup = DispatchGroup()
        postsGroup.enter()
        postsGroup.enter()
        postsGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            /// sort friends posts
            print("frineds posts leave")
            self.homeFetchGroup.leave()
        }
        
        /// fetch all posts in last 24 hours
        let todaySeconds = Date().timeIntervalSince1970
        let yesterdaySeconds = Date().timeIntervalSince1970 - 86400
        let yesterdayTimestamp = Timestamp(seconds: Int64(yesterdaySeconds), nanoseconds: 0)
        let recentQuery = db.collection("posts").whereField("timestamp", isGreaterThanOrEqualTo: yesterdayTimestamp)
        
        recentQuery.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            if snap.documents.count == 0 { postsGroup.leave(); return }
            
            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    /// if !contains, run query, else update with new values + update comments
                    guard let postInfo = postIn else { continue }
                    if self.friendsPostsDictionary[postInfo.id!] != nil { self.updatePost(post: postInfo); continue } /// update post on active listener change
                    recentGroup.enter()
                    self.setPostDetails(post: postInfo) { post in
                        if post.id ?? "" != "" { self.addPostToDictionary(post: post) }
                        recentGroup.leave()
                    }
                    continue
                    
                } catch {
                    continue
                }
            }
            recentGroup.notify(queue: .global()) {
                postsGroup.leave()
            }
        }
        
        /// fetch unseen posts between 1 - 7 day old
        let lowerBound = todaySeconds - 86400 * 7
        let weekAgoTimestamp = Timestamp(seconds: Int64(lowerBound), nanoseconds: 0)
        let oldQuery = db.collection("posts").whereField("seen", isEqualTo: false).whereField("timestamp", isLessThanOrEqualTo: yesterdayTimestamp).whereField("timestamp", isGreaterThanOrEqualTo: weekAgoTimestamp)
        oldQuery.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.documents.count == 0 { postsGroup.leave(); return }
            
            let oldGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    guard let postInfo = postIn else { continue }
                    if self.friendsPostsDictionary[postInfo.id!] != nil { self.updatePost(post: postInfo); continue } /// update post on active listener change
                    oldGroup.enter()
                    self.setPostDetails(post: postInfo) { post in
                        if post.id ?? "" != "" {
                            self.addPostToDictionary(post: post)
                        }
                        oldGroup.leave()
                    }
                } catch {
                    continue
                }
            }
            oldGroup.notify(queue: .global()) {
                postsGroup.leave()
            }
        }
    }
    
    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void) {
        var postInfo = post
        if let user = UserDataModel.shared.friendsList.first(where: {$0.id == postInfo.posterID}) {
            postInfo.userInfo = user
        } else if postInfo.posterID == self.uid {
            postInfo.userInfo = UserDataModel.shared.userInfo
        } else {
            /// need to update this func for map post (not all users will be friends) 
            /// friend not in users friendslist, might have removed them as a friend
            completion(MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp()))
            return
        }
        
        /// detail group tracks comments and added users fetches
        let detailGroup = DispatchGroup()
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
    
    func addPostToDictionary(post: MapPost) {
        friendsPostsDictionary[post.id!] = post
        
        if !friendsPostsGroup.contains(where: {$0.posterID == post.posterID}) {
            friendsPostsGroup.append(FriendsPostGroup(posterID: post.posterID, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen!)]))
            
        } else if let i = friendsPostsGroup.firstIndex(where: {$0.posterID == post.posterID}) {
            if !friendsPostsGroup[i].postIDs.contains(where: {$0.0 == post.id!}) {
                friendsPostsGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen!))
                friendsPostsGroup[i].postIDs.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
            }
        }
    }
    
    func updatePost(post: MapPost) {
        var post = post
        let oldPost = friendsPostsDictionary[post.id!]
        if (post.likers.count != oldPost!.likers.count) || (post.commentCount != oldPost!.commentCount) {
            post.likers = oldPost!.likers
            if post.commentCount != oldPost!.commentCount {
                getComments(postID: post.id!) { [weak self] comments in
                    guard let self = self else { return }
                    post.commentList = comments
                    self.friendsPostsDictionary[post.id!] = post
                }
            } else {
                self.friendsPostsDictionary[post.id!] = post
            }
        }
    }
    
    func getMaps() {
        /// just check for new posts?
        db.collection("users").document(uid).collection("mapsList").getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            for doc in snap.documents {
                let last = doc == snap.documents.last
                do {
                    let mapIn = try doc.data(as: CustomMap.self)
                    guard let mapInfo = mapIn else { if last { self.homeFetchGroup.leave() }; continue }
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                    if last {
                        self.homeFetchGroup.leave()
                    }
                } catch {
                    continue
                }
            }
        }
    }
    
    func getMapPosts(map: CustomMap) {
        db.collection("posts").whereField("mapID", isEqualTo: map.id!).getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            guard let snap = snap else { return }
            
            let postGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try doc.data(as: MapPost.self)
                    guard let postInfo = postIn else { continue }
                    postGroup.enter()
                    self.setPostDetails(post: postInfo) { post in
                        /// append map info
                    }
                    continue
                } catch {
                    continue
                }
            }
        }
    }
    
    func getUnseenPosts() {
        
    }
}
