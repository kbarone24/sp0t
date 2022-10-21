//
//  MapNotifications.swift
//  Spot
//
//  Created by Kenny Barone on 8/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension MapController {
    @objc func notifyPostOpen(_ notification: NSNotification) {
        guard let postID = notification.userInfo?.first?.value as? String else { return }
        /// check every map for post and update if necessary
        /// check coordinate to refresh annotation on the map
        var coordinate: CLLocationCoordinate2D?
        if var post = friendsPostsDictionary[postID] {
            if !post.seenList!.contains(uid) { post.seenList?.append(uid) }
            friendsPostsDictionary.updateValue(post, forKey: postID)
            coordinate = post.coordinate
        }
        updateFriendsPostGroupSeen(postID: postID)

        for i in 0..<UserDataModel.shared.userInfo.mapsList.count {
            UserDataModel.shared.userInfo.mapsList[i].updateSeen(postID: postID)
            if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
                coordinate = UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]?.coordinate
            }
        }
        
        DispatchQueue.main.async {
            self.reloadMapsCollection(resort: false, newPost: false)
            if coordinate != nil {
                if let annotation = self.mapView.annotations.first(where: {$0.coordinate.isEqualTo(coordinate: coordinate!)}) {
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
        var map = notification.userInfo?["map"] as? CustomMap
        let emptyMap = map == nil || map?.id ?? "" == ""
        if !emptyMap && !(UserDataModel.shared.userInfo.mapsList.contains(where: {$0.id == map!.id!})) {
            map!.addSpotGroups()
            UserDataModel.shared.userInfo.mapsList.append(map!)
        }
        let mapIndex = post.mapID == "" ? 0 : 1
        let dictionaryIndex = post.mapID == "" ? 0 : -1
        DispatchQueue.main.async {
            self.addPostToDictionary(post: post, map: map, newPost: true, index: dictionaryIndex)
            self.selectMapAt(index: 0) /// select map at 0 to reset selected index (resort might mess with selecting index 1)
            self.reloadMapsCollection(resort: true, newPost: true)
            if mapIndex == 1 {
                self.selectMapAt(index: mapIndex)
                self.reloadMapsCollection(resort: false, newPost: true)
            }
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
        let spotID = spotDelete || spotRemove ? post.spotID! : ""
        removePost(post: post, spotID: spotID, mapID: mapID, mapDelete: mapDelete)
        DispatchQueue.main.async { self.reloadMapsCollection(resort: false, newPost: false) }
    }
    
    func removePost(post: MapPost, spotID: String, mapID: String, mapDelete: Bool) {
        /// remove from friends stuff
        friendsPostsDictionary.removeValue(forKey: post.id!)
        removeFromFriendsPostGroup(postID: post.id!, spotID: spotID)
        UserDataModel.shared.deletedPostIDs.append(post.id!)
        /// remove from map
        if mapID != "" {
            if mapDelete {
                selectedItemIndex = 0 /// reset to avoid index out of bounds
                UserDataModel.shared.userInfo.mapsList.removeAll(where: {$0.id == mapID})
            } else if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == mapID}) {
                DispatchQueue.main.async { UserDataModel.shared.userInfo.mapsList[i].removePost(postID: post.id!, spotID: spotID) }
            }
        }
        if let anno = mapView.annotations.first(where: {$0.coordinate.isEqualTo(coordinate: post.coordinate)}) {
            DispatchQueue.main.async { self.mapView.removeAnnotation(anno) }
        }
        reloadMapsCollection(resort: false, newPost: false)
    }
    
    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }
        
        if friendsPostsDictionary[postID] != nil {
            friendsPostsDictionary[postID]!.commentList = commentList
            friendsPostsDictionary[postID]!.commentCount = max(0, commentList.count - 1)
        }
        
        for i in 0..<UserDataModel.shared.userInfo.mapsList.count {
            if UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID] != nil {
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]!.commentList = commentList
                UserDataModel.shared.userInfo.mapsList[i].postsDictionary[postID]!.commentCount = max(0, commentList.count - 1)
            }
        }
    }
                
    @objc func notifyFriendsListAdd() {
        print("notify friends list add")
        /// query friends posts again
        homeFetchGroup.enter()
        homeFetchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.reloadMapsCollection(resort: false, newPost: false)
        }
        
        DispatchQueue.global().async {
            self.getRecentPosts(map: nil)
        }
    }
    
    @objc func notifyEditMap(_ notification: NSNotification) {
        print("notify edit", UserDataModel.shared.userInfo.mapsList.map({$0.mapName}))
        reloadMapsCollection(resort: true, newPost: true) /// set newPost to true to avoid map centering
        /// update should happen by listener
      /*  guard let map = notification.userInfo?["map"] as? CustomMap else { return }
        if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: {$0.id == map.id}) {
            UserDataModel.shared.userInfo.mapsList[i].memberIDs = map.memberIDs
            UserDataModel.shared.userInfo.mapsList[i].likers = map.likers
            UserDataModel.shared.userInfo.mapsList[i].memberProfiles = map.memberProfiles
            UserDataModel.shared.userInfo.mapsList[i].imageURL = map.imageURL
            UserDataModel.shared.userInfo.mapsList[i].mapName = map.mapName
            UserDataModel.shared.userInfo.mapsList[i].mapDescription = map.mapDescription
            UserDataModel.shared.userInfo.mapsList[i].secret = map.secret
            DispatchQueue.main.async { self.mapsCollection.reloadItems(at: [IndexPath(item: i + 1, section: 0)]) }
        } */
    }
    
    @objc func notifyFriendRemove(_ notifications: NSNotification) {
        print("notify friend remove")
        guard let friendID = notifications.userInfo?.first?.value as? String else { return }
        print("friend id", friendID)
        for post in friendsPostsDictionary {
            print("doc id", post.value.posterID)
            if post.value.posterID == friendID { removePost(post: post.value, spotID: post.value.spotID ?? "", mapID: "", mapDelete: false) }
        }
    }
    
    @objc func enterForeground() {
        /// check for activity indicator will begin animation
        if !checkForActivityIndicator() {
            /// re-run fetch, listener might missed posts when app in background
            reRunMapFetch()
        }
    }
    
    @objc func notifyLogout() {
        userListener.remove()
        newPostListener.remove()
        mapsListener.remove()
    }
}
