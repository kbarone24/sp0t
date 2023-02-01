//
//  PostControllerActions.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension PostController {
    func openComments(row: Int, animated: Bool) {
        if presentedViewController != nil { return }
        if let commentsVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Comments") as? CommentsController {

            Mixpanel.mainInstance().track(event: "PostOpenComments")

            let post = self.postsList[selectedPostIndex]
            commentsVC.commentList = post.commentList
            commentsVC.post = post
            commentsVC.postVC = self
            present(commentsVC, animated: animated, completion: nil)
        }
    }

    @objc func backTap() {
        containerDrawerView?.closeAction()
    }

    @objc func elipsesTap() {
        Mixpanel.mainInstance().track(event: "PostPageElipsesTap")
        addActionSheet()
    }

    @objc func commentsTap() {
        openComments(row: selectedPostIndex, animated: true)
    }

    @objc func likeTap() {
        if let i = postsList[selectedPostIndex].likers.firstIndex(where: { $0 == UserDataModel.shared.uid }) {
            Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            postsList[selectedPostIndex].likers.remove(at: i)
            mapPostService?.unlikePostDB(post: postsList[selectedPostIndex])
        } else {
            Mixpanel.mainInstance().track(event: "PostPageLikePost")
            postsList[selectedPostIndex].likers.append(UserDataModel.shared.uid)
            mapPostService?.likePostDB(post: postsList[selectedPostIndex])
        }
        updateButtonView()
    }

    func removeTableAnimations() {
        for cell in contentTable.visibleCells {
            if let contentCell = cell as? ContentViewerCell {
                contentCell.post = nil
                contentCell.stopLocationAnimation()
            }
        }
    }
}

extension PostController: ContentViewerDelegate {
    func getSelectedPostIndex() -> Int {
        return selectedPostIndex
    }

    func openPostComments() {
        openComments(row: selectedPostIndex, animated: true)
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
}
