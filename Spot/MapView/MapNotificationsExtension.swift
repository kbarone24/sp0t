//
//  MapNotifications.swift
//  Spot
//
//  Created by Kenny Barone on 8/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import MapKit
import UIKit

extension MapController {
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
                self.setNewPostsButtonCount()
                self.loadAdditionalOnboarding()

                if self.sheetView == nil {
                    // unhide supplemental buttons + add annotations
                    self.toggleHomeAppearance(hidden: false)
                }

                self.finishPostsLoad(resort: true, newPost: false, upload: false)
            }
        }
    }

    @objc func notifyPostOpen(_ notification: NSNotification) {
        guard let post = notification.userInfo?.first?.value as? MapPost else { return }
        guard let postID = post.id else { return }
        // check coordinate to refresh annotation on the map
        var coordinate: CLLocationCoordinate2D?
        if var post = postDictionary[postID] {
            if !(post.seenList?.contains(uid) ?? false) { post.seenList?.append(uid) }
            postDictionary.updateValue(post, forKey: postID)
            coordinate = post.coordinate
        }
        updateFriendsPostGroupSeen(postID: post.id ?? "")

        DispatchQueue.main.async {
            // moved to main thread to try to solve memory crash
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == post.mapID ?? "" }) {
                UserDataModel.shared.userInfo.mapsList[i].updateSeen(postID: postID)
                if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
                    coordinate = UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]?.coordinate
                }
            }

            self.finishPostsLoad(resort: false, newPost: false, upload: false)
            if let coordinate {
                if let annotation = self.mapView.annotations.first(where: { $0.coordinate.isEqualTo(coordinate: coordinate) }) {
                    self.mapView.removeAnnotation(annotation)
                    self.mapView.addAnnotation(annotation)
                }
            }
        }
    }

    @objc func notifyNewPost(_ notification: NSNotification) {
        /// add new post + zoom in on map
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        uploadMapReset()

        mapView.shouldCluster = false
        mapView.lockClusterOnUpload = true
        /// add new map to mapsList if applicable
        let map = notification.userInfo?["map"] as? CustomMap
        let spot = notification.userInfo?["spot"] as? MapSpot
        let emptyMap = map == nil || map?.id ?? "" == ""
        if !emptyMap {
            // update post/spot values for existing map
            if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == map?.id ?? "" }) {
                UserDataModel.shared.userInfo.mapsList[i].updatePostLevelValues(post: post)
                if let spot = spot { UserDataModel.shared.userInfo.mapsList[i].updateSpotLevelValues(spot: spot) }
            } else if var map = map {
                /// finish creating new map object
                map.addSpotGroups()
                UserDataModel.shared.userInfo.mapsList.append(map)
            }
        }

        let mapIndex = post.mapID == "" ? 0 : 1
        let dictionaryIndex = post.mapID == "" ? 0 : -1
        DispatchQueue.main.async {
            self.addPostToDictionary(post: post, map: map, newPost: true)
            self.finishPostsLoad(resort: true, newPost: true, upload: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            /// animate to spot if post to map, to post location if friends map
            self.animateTo(coordinate: post.coordinate)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.mapView.lockClusterOnUpload = false
        }
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapID = notification.userInfo?["mapID"] as? String else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        guard let spotDelete = notification.userInfo?["spotDelete"] as? Bool else { return }
        guard let spotRemove = notification.userInfo?["spotRemove"] as? Bool else { return }
        /// only pass through spot ID if removing from the map
        let spotID = spotDelete || spotRemove ? post.spotID ?? "" : ""
        removePost(post: post, spotID: spotID, mapID: mapID, mapDelete: mapDelete)
        DispatchQueue.main.async { self.finishPostsLoad(resort: false, newPost: false, upload: false) }
    }

    func removePost(post: MapPost, spotID: String, mapID: String, mapDelete: Bool) {
        /// remove from friends stuff
        postDictionary.removeValue(forKey: post.id ?? "")
        removeFromFriendsPostGroup(postID: post.id ?? "", spotID: spotID)
        UserDataModel.shared.deletedPostIDs.append(post.id ?? "")
        /// remove from map
        if mapID != "" {
            if mapDelete {
                UserDataModel.shared.userInfo.mapsList.removeAll(where: { $0.id == mapID })
            } else if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapID }) {
                DispatchQueue.main.async { UserDataModel.shared.userInfo.mapsList[i].removePost(postID: post.id ?? "", spotID: spotID) }
            }
        }
        if let anno = mapView.annotations.first(where: { $0.coordinate.isEqualTo(coordinate: post.coordinate) }) {
            DispatchQueue.main.async { self.mapView.removeAnnotation(anno) }
        }
        finishPostsLoad(resort: false, newPost: false, upload: false)
    }

    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }

        if postDictionary[postID] != nil {
            postDictionary[postID]?.commentList = commentList
            postDictionary[postID]?.commentCount = max(0, commentList.count - 1)
        }

        for i in 0..<UserDataModel.shared.userInfo.mapsList.count where
        UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
            UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]?.commentList = commentList
            UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]?.commentCount = max(0, commentList.count - 1)
        }
    }

    @objc func notifyEditMap(_ notification: NSNotification) {
        finishPostsLoad(resort: true, newPost: true, upload: false) /// set newPost to true to avoid map centering
    }

    @objc func notifyFriendRemove(_ notification: NSNotification) {
        guard let friendID = notification.userInfo?.first?.value as? String else { return }
        for post in postDictionary where post.value.posterID == friendID {
            removePost(post: post.value, spotID: post.value.spotID ?? "", mapID: "", mapDelete: false)
        }
    }

    @objc func notifyBlockUser(_ notification: NSNotification) {
        guard let friendID = notification.userInfo?.first?.value as? String else { return }
        for map in UserDataModel.shared.userInfo.mapsList where map.memberIDs.contains(friendID) {
            for post in map.postsDictionary where post.value.posterID == friendID {
                DispatchQueue.main.async {
                    if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == map.id }) {
                        UserDataModel.shared.userInfo.mapsList[i].removePost(postID: post.key, spotID: post.value.spotID ?? "")
                    }
                }
            }
        }
    }

    @objc func enterForeground() {
        checkForActivityIndicator()
    }

    @objc func notifyLogout() {
        userListener?.remove()
        mapsPostsListener?.remove()
        friendsPostsListener?.remove()
        mapsListener?.remove()
        notiListener?.remove()
    }
}
