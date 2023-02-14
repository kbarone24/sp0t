//
//  PostContentViewerDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 2/14/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension PostController: ContentViewerDelegate {
    func likePost(postID: String) {
        HapticGenerator.shared.play(.light)
        if let i = postsList[selectedPostIndex].likers.firstIndex(where: { $0 == UserDataModel.shared.uid }) {
            Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            postsList[selectedPostIndex].likers.remove(at: i)
            mapPostService?.unlikePostDB(post: postsList[selectedPostIndex])
        } else {
            Mixpanel.mainInstance().track(event: "PostPageLikePost")
            postsList[selectedPostIndex].likers.append(UserDataModel.shared.uid)
            mapPostService?.likePostDB(post: postsList[selectedPostIndex])
        }
        updateCommentsAndLikes(row: selectedPostIndex)
    }

    func openPostComments() {
        openComments(row: selectedPostIndex, animated: true)
    }

    func openPostActionSheet() {
        Mixpanel.mainInstance().track(event: "PostPageElipsesTap")
        addActionSheet()
    }

    func getSelectedPostIndex() -> Int {
        return selectedPostIndex
    }

    func openProfile(user: UserProfile) {
        let profileVC = ProfileViewController(userProfile: user, presentedDrawerView: containerDrawerView)
        DispatchQueue.main.async { self.navigationController?.pushViewController(profileVC, animated: true) }
    }

    func openMap(mapID: String, mapName: String) {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: mapName, memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
        navigationController?.pushViewController(customMapVC, animated: true)
    }

    func openSpot(post: MapPost) {
        let spotVC = SpotPageController(mapPost: post, presentedDrawerView: containerDrawerView)
        navigationController?.pushViewController(spotVC, animated: true)
    }

    func tapToNextPost() {
        if animatingToNextRow { return }
        if selectedPostIndex < postsList.count - 1 {
            tapToSelectedRow(increment: 1)
        } else {
            containerDrawerView?.closeAction()
        }
    }

    func tapToPreviousPost() {
        if animatingToNextRow { return }
        if selectedPostIndex > 0 {
            tapToSelectedRow(increment: -1)
        } else {
            containerDrawerView?.closeAction()
        }
    }

    @objc func notifyImageChange(_ notification: NSNotification) {
        if let index = notification.userInfo?.values.first as? Int {
            postsList[selectedPostIndex].selectedImageIndex = index
            containerDrawerView?.canSwipeRightToDismiss = postsList[selectedPostIndex].selectedImageIndex == 0
        }
    }

    @objc func notifyCitySet(_ notification: NSNotification) {
        if (!nearbyPostsFetched && selectedSegment == .NearbyPosts) || (myPostsFetched && selectedSegment == .MyPosts) {
            DispatchQueue.global().async { self.getNearbyPosts() }
        }
    }

    func updateDrawerViewOnIndexChange() {
        containerDrawerView?.canSwipeUpToDismiss = selectedPostIndex == postsList.count - 1
        containerDrawerView?.canSwipeDownToDismiss = selectedPostIndex == 0
    }

    // call to let table know cell is swiping
    func imageViewOffset(offset: Bool) {
        imageViewOffset = offset
    }
}

extension PostController: CommentsDelegate {
    func openProfileFromComments(user: UserProfile) {
        openProfile(user: user)
    }
}
