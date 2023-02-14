//
//  PostFeedExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import MapKit

extension PostController {
    func getNearbyPosts() {
        nearbyRefreshStatus = .activelyRefreshing
        let db = Firestore.firestore()
        var nearbyQuery = db.collection("posts").limit(to: 300).whereField("city", isEqualTo: UserDataModel.shared.userCity).order(by: "timestamp", descending: true)
        if let nearbyPostEndDocument { nearbyQuery = nearbyQuery.start(afterDocument: nearbyPostEndDocument) }
        var currentFetchPosts: [MapPost] = []

        nearbyQuery.getDocuments { snap, _ in
            guard let snap = snap else { return }

            let recentGroup = DispatchGroup()
            for doc in snap.documents {
                do {
                    let postIn = try? doc.data(as: MapPost.self)
                    guard let postInfo = postIn else { continue }
                    if postInfo.privacyLevel != "public" && !postInfo.friendsList.contains(UserDataModel.shared.uid) && !(postInfo.inviteList?.contains(UserDataModel.shared.uid) ?? false) { continue }
                    if self.postsContains(postID: postInfo.id ?? "", fetchType: .NearbyPosts) || self.filteredFromFeed(post: postInfo) { continue }

                    recentGroup.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            if post.id ?? "" != "" {
                                if !self.postsContains(postID: post.id ?? "", fetchType: .NearbyPosts) {
                                    var post = post
                                    post.postScore = post.getNearbyPostScore()
                                    currentFetchPosts.append(post)
                                }
                            }
                            recentGroup.leave()
                        }
                    }
                    continue
                }
            }
            // TODO: add nearby refresh control
            recentGroup.notify(queue: .main) {
                currentFetchPosts.sort(by: { $0.postScore ?? 0 > $1.postScore ?? 0 })
                self.nearbyPosts.append(contentsOf: currentFetchPosts)
                self.nearbyPostsFetched = true
                self.nearbyRefreshStatus = .refreshEnabled
                self.refetchAndRefreshIfNecessary(currentFetchCount: currentFetchPosts.count, fetchType: .NearbyPosts)
            }
        }
    }

    func getMyPosts() {
        // fetch all posts in last 7 days
        let db = Firestore.firestore()
        let recentQuery = db.collection("posts").limit(to: 5).order(by: "timestamp", descending: true)

        var friendsQuery = recentQuery.whereField("friendsList", arrayContains: UserDataModel.shared.uid)
        if let friendsPostEndDocument { friendsQuery = friendsQuery.start(afterDocument: friendsPostEndDocument) }

        var mapsQuery = recentQuery.whereField("inviteList", arrayContains: UserDataModel.shared.uid)
        if let mapPostEndDocument { mapsQuery = mapsQuery.start(afterDocument: mapPostEndDocument) }

        myPostsRefreshStatus = .activelyRefreshing
        homeFetchLeaveCount = 0
        localPosts.removeAll()
        
        homeFetchGroup.enter()
        if !myPostsFetched {
            addFriendsListener(query: friendsQuery)
        } else {
            getFriendsPosts(query: friendsQuery)
        }

        homeFetchGroup.enter()
        if !myPostsFetched {
            addMapListener(query: mapsQuery)
        } else {
            getMapPosts(query: mapsQuery)
        }

        homeFetchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let localCount = self.localPosts.count
            self.localPosts.sort(by: { $0.timestamp.seconds > $1.timestamp.seconds })
            self.myPosts.append(contentsOf: self.localPosts)
            self.localPosts.removeAll()

            self.myPostsFetched = true
            self.myPostsRefreshStatus = .refreshEnabled
            self.refetchAndRefreshIfNecessary(currentFetchCount: localCount, fetchType: .MyPosts)
        }
    }

    private func addFriendsListener(query: Query) {
        friendsListener = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }

            // check for deleted post on listener
            var newPost = false
            let postIDs = snap.documents.map({ $0.documentID })
            self.friendsFetchIDs = postIDs
            if self.myPostsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, friendsFetch: true) }
            self.setFriendPostDetails(snap: snap, newPost: newPost, newFetch: !self.myPostsFetched)
        }
    }

    private func addMapListener(query: Query) {
        mapsListener = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }

            // check for deleted post on listener
            var newPost = false
            let postIDs = snap.documents.map({ $0.documentID })
            self.mapFetchIDs = postIDs
            if self.myPostsFetched { newPost = self.checkForPostDelete(postIDs: postIDs, friendsFetch: false) }
            self.setMapPostDetails(snap: snap, newPost: newPost, newFetch: !self.myPostsFetched)
        }
    }
    
    private func getFriendsPosts(query: Query) {
        query.getDocuments { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            self.setFriendPostDetails(snap: snap, newPost: false, newFetch: true)
        }
    }
    
    private func getMapPosts(query: Query) {
        query.getDocuments { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            self.setMapPostDetails(snap: snap, newPost: false, newFetch: true)
        }
    }

    private func setFriendPostDetails(snap: QuerySnapshot, newPost: Bool, newFetch: Bool) {
        if newFetch { friendsPostEndDocument = snap.documents.last }
        self.setPostDetails(snap: snap, newPost: newPost, newFetch: newFetch)
    }

    private func setMapPostDetails(snap: QuerySnapshot, newPost: Bool, newFetch: Bool) {
        if newFetch { mapPostEndDocument = snap.documents.last }
        setPostDetails(snap: snap, newPost: newPost, newFetch: newFetch)
    }

    private func setPostDetails(snap: QuerySnapshot, newPost: Bool, newFetch: Bool) {
        if snap.documents.isEmpty { leaveHomeFetchGroup(newPost: false, newFetch: newFetch); return }
        var newPost = newPost
        let recentGroup = DispatchGroup()
        for doc in snap.documents {
            do {
                let postIn = try? doc.data(as: MapPost.self)
                /// if !contains, run query, else update with new values + update comments
                guard let postInfo = postIn else { continue }
                if self.postsContains(postID: postInfo.id ?? "", fetchType: .MyPosts) {
                    self.updatePost(post: postInfo)
                    continue
                }
                if self.filteredFromFeed(post: postInfo) { continue }

                recentGroup.enter()
                self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if post.id ?? "" != "" {
                            if !self.postsContains(postID: post.id ?? "", fetchType: .MyPosts) {
                                newPost = true
                                self.localPosts.append(post)
                            }
                        }
                        recentGroup.leave()
                    }
                }
                continue
            }
        }
        recentGroup.notify(queue: .global()) {
            self.leaveHomeFetchGroup(newPost: newPost, newFetch: newFetch)
        }
    }

    private func leaveHomeFetchGroup(newPost: Bool, newFetch: Bool) {
        if homeFetchLeaveCount < 2 && newFetch {
            homeFetchLeaveCount += 1
            homeFetchGroup.leave()
        } else if newPost {
            // replace 1st post if user hasnt started scrolling yet or show as next post
            let newPostIndex = selectedPostIndex == 0 ? 0 : selectedPostIndex + 1
            self.postsList.insert(contentsOf: localPosts, at: newPostIndex)
            self.localPosts.removeAll()
            DispatchQueue.main.async { self.contentTable.reloadData() }
        }
    }
    
    private func postsContains(postID: String, fetchType: FetchType) -> Bool {
        switch fetchType {
        case .MyPosts:
            return localPosts.contains(where: { $0.id == postID }) || myPosts.contains(where: { $0.id == postID })
        case .NearbyPosts:
            return nearbyPosts.contains(where: { $0.id == postID })
        }
    }

    private func refetchAndRefreshIfNecessary(currentFetchCount: Int, fetchType: FetchType) {
        // re-run fetch if not enough posts returned or scrolled to bottom of table while fetch was happening
        if currentFetchCount < 5 || (selectedSegment == fetchType && postsList.count - self.selectedPostIndex < 5) {
            switch fetchType {
            case .MyPosts:
                DispatchQueue.global().async { self.getMyPosts() }
            case .NearbyPosts:
                DispatchQueue.global().async { self.getNearbyPosts() }
            }
        } else {
            switch fetchType {
            case .MyPosts:
                if !nearbyPostsFetched { DispatchQueue.global().async { self.getNearbyPosts() } }
            case .NearbyPosts:
                if !myPostsFetched { DispatchQueue.global().async { self.getMyPosts() } }
            }
        }

        if self.selectedSegment == fetchType {
            print("set posts list", selectedSegmentPosts.count)
            postsList = selectedSegmentPosts
            DispatchQueue.main.async { self.contentTable.reloadData() }
        }
    }
    
    private func filteredFromFeed(post: MapPost) -> Bool {
        if (post.userInfo?.id?.isBlocked() ?? false) ||
        (post.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) ||
            UserDataModel.shared.deletedPostIDs.contains(post.id ?? "") {
            return true
        }
        return false
    }

    private func updatePost(post: MapPost) {
        Task {
            // use old post to only update values that CHANGE -> comments and likers
            var oldPost = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            if let post = postsList.first(where: { $0.id ?? "" == post.id ?? "" }) {
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
            if let i = postsList.firstIndex(where: { $0.id ?? "" == post.id ?? "" }) {
                postsList[i] = oldPost
            }
        }
    }

    private func checkForPostDelete(postIDs: [String], friendsFetch: Bool) -> Bool {
        // check which id is not included in postIDs from previous fetch
        var deletedPostID = ""

        if friendsFetch, let postID = friendsFetchIDs.first(where: { !postIDs.contains($0) }) {
            // check came from friends fetch
            deletedPostID = postID

        } else if !friendsFetch, let postID = mapFetchIDs.first(where: { !postIDs.contains($0) }) {
            // check came from maps fetch
            deletedPostID = postID

        } else {
            return false
        }

        postsList.removeAll(where: { $0.id == deletedPostID })
        UserDataModel.shared.deletedPostIDs.append(deletedPostID)
        return true
    }
}
