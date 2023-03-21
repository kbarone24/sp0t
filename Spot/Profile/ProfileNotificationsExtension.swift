//
//  ProfileNotificationsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

/// notifications
extension ProfileViewController {
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost, let postID = post.id else { return }
        postsList.removeAll(where: { $0.id == postID })
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }

    @objc func notifyUserLoad(_ notification: NSNotification) {
        if userProfile?.username ?? "" != "" { return }
        userProfile = UserDataModel.shared.userInfo
        getUserRelation()
        viewSetup()
        runFetches()
    }

    @objc func notifyFriendsLoad() {
        // update active user friends list when all friends load on userListener fetch
        guard let userID = userProfile?.id as? String else { return }
        if userID == UserDataModel.shared.uid {
            userProfile?.friendsList = UserDataModel.shared.userInfo.friendsList
        }
    }

    @objc func notifyFriendRequestAccept(_ notification: NSNotification) {
        relation = .friend
        userProfile?.friendIDs.append(UserDataModel.shared.uid)
        userProfile?.friendsList.append(UserDataModel.shared.userInfo)
        userProfile?.topFriends?[UserDataModel.shared.uid] = 0

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.activityIndicator.startAnimating()
        }

        // run get nine posts once friendslist field has started to be updated
        // delay is hacky but cant think of another way rn
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            self.getPosts()
        }
    }

    @objc func notifyNewPost(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        postsList.insert(post, at: 0)
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    @objc func notifyPostChanged(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        if let i = postsList.firstIndex(where: { $0.id == post.id }) {
            postsList[i].likers = post.likers
            postsList[i].commentList = post.commentList
            postsList[i].commentCount = post.commentCount
        }
    }
}
