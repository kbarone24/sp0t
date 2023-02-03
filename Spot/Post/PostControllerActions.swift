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

    @objc func tablePan(_ gesture: UIPanGestureRecognizer) {
        let velocity = gesture.velocity(in: gesture.view)
        let translation = gesture.translation(in: gesture.view)
        let composite = translation.y + velocity.y / 4

        switch gesture.state {
        case .began:
            if imageViewOffset { return }
            if abs(velocity.y) > abs(velocity.x) {
                tableViewOffset = true
            }
        case .changed:
            if !tableViewOffset { return }
            contentTable.setContentOffset(CGPoint(x: 0, y: currentRowContentOffset - translation.y), animated: false)
        case .ended:
            if composite < -(rowHeight / 4) && selectedPostIndex < postsList.count - 1 {
                selectedPostIndex += 1
            } else if composite > rowHeight / 4 && selectedPostIndex != 0 {
                selectedPostIndex -= 1
            }
            scrollToSelectedRow(animated: true)
        default:
            scrollToSelectedRow(animated: true)
        }
    }

    func scrollToSelectedRow(animated: Bool) {
        var duration: TimeInterval = 0.05
        if animated {
            let offset = abs(currentRowContentOffset - contentTable.contentOffset.y)
            duration = max(TimeInterval(0.35 * offset / rowHeight), 0.2)
        }
        UIView.animate(withDuration: duration, animations: {
            self.contentTable.scrollToRow(at: IndexPath(row: self.selectedPostIndex, section: 0), at: .top, animated: false)
        }) { [weak self] _ in
            self?.tableViewOffset = false
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

    func goToNextPost() {
        if selectedPostIndex < postsList.count - 1 {
            selectedPostIndex += 1
            DispatchQueue.main.async { self.scrollToSelectedRow(animated: true) }
        } else {
            containerDrawerView?.closeAction()
        }
    }

    func goToPreviousPost() {
        if selectedPostIndex > 0 {
            selectedPostIndex -= 1
            DispatchQueue.main.async { self.scrollToSelectedRow(animated: true) }
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

    func updateDrawerViewOnIndexChange() {
      //  containerDrawerView?.swipeUpToDismiss = selectedPostIndex == postsList.count - 1
     //   containerDrawerView?.swipeDownToDismiss = selectedPostIndex == 0
    }

    // call to let table know cell is swiping
    func imageViewOffset(offset: Bool) {
        imageViewOffset = offset
    }
}
