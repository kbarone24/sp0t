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
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        guard let spotRemove = notification.userInfo?["spotRemove"] as? Bool else { return }
        guard let postID = post.id else { return }

        if posts.contains(where: { $0.id == postID }) {
            posts.removeAll()
            DispatchQueue.main.async { self.collectionView.reloadData() }
            DispatchQueue.global().async { self.getNinePosts() }
        }
        if mapDelete {
            maps.removeAll(where: { $0.id == post.mapID ?? "" })
            DispatchQueue.main.async { self.collectionView.reloadData() }

        } else if post.mapID ?? "" != "" {
            if let i = maps.firstIndex(where: { $0.id == post.mapID ?? "" }) {
                maps[i].removePost(postID: postID, spotID: spotDelete || spotRemove ? post.spotID ?? "" : "")
            }
        }
    }

    @objc func notifyMapChange(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        guard let mapID = userInfo["mapID"] as? String else { return }
        guard let likers = userInfo["mapLikers"] as? [String] else { return }
        if let i = maps.firstIndex(where: { $0.id == mapID }) {
            /// remove if this user
            if !likers.contains(userProfile?.id ?? "") {
                DispatchQueue.main.async {
                    self.maps.remove(at: i)
                    self.collectionView.reloadData()
                }
            } else {
                /// update likers if current user liked map through another users mapsList
                self.maps[i].likers = likers
            }
        } else {
            if likers.contains(self.userProfile?.id ?? "") {
                getMaps()
            }
        }
    }

    @objc func notifyUserLoad(_ notification: NSNotification) {
        print("notify user load")
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

    @objc func notifyMapsLoad(_ notification: NSNotification) {
        getMaps()
    }

    @objc func notifyEditMap(_ notification: NSNotification) {
        guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if let i = maps.firstIndex(where: { $0.id == map.id }) {
            maps[i].memberIDs = map.memberIDs
            maps[i].likers = map.likers
            maps[i].memberProfiles = map.memberProfiles
            maps[i].imageURL = map.imageURL
            maps[i].mapName = map.mapName
            maps[i].mapDescription = map.mapDescription
            maps[i].secret = map.secret
            DispatchQueue.main.async { self.collectionView.reloadData() }
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
            self.getNinePosts()
        }
    }

    @objc func notifyDrawerViewReset() {
        collectionView.isScrollEnabled = true
    }

    @objc func notifyDrawerViewOffset() {
        collectionView.isScrollEnabled = false
    }
}
