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
            
            // self.setFriendPostDetails(snap: snap, newPost: newPost, newFetch: !self.myPostsFetched)
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
            // self.setMapPostDetails(snap: snap, newPost: newPost, newFetch: !self.myPostsFetched)
        }
    }

    private func updatePost(post: MapPost) {
        Task {
            // use old post to only update values that CHANGE -> comments and likers. Otherwise post images will get reset
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
            if let i = myPosts.firstIndex(where: { $0.id ?? "" == post.id ?? "" }) {
                myPosts[i] = oldPost
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
