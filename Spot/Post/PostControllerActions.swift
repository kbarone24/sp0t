//
//  PostControllerActions.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension PostController {
    func openComments(row: Int, animated: Bool) {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "PostOpenComments")
        let post = postsList[selectedPostIndex]
        let commentsVC = CommentsController(commentsList: post.commentList, post: post)
        commentsVC.delegate = self
        DispatchQueue.main.async {
            self.present(commentsVC, animated: animated, completion: nil)
        }
    }

    @objc func findFriendsTap() {
        Mixpanel.mainInstance().track(event: "HomeScreenFindFriendsTap")
        let findFriendsController = FindFriendsController()
        navigationController?.pushViewController(findFriendsController, animated: true)
    }

    @objc func backTap() {
        exitPosts()
    }

    func exitPosts() {
        for cell in contentTable.visibleCells { cell.layer.removeAllAnimations() }
        navigationController?.popViewController(animated: true)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
    }

    @objc func notifyNewPost(_ notification: NSNotification) {
        if parentVC == .Home {
            guard let post = notification.userInfo?["post"] as? MapPost else { return }
            DispatchQueue.main.async {
                self.myPosts.insert(post, at: 0)
                self.selectedSegment = .MyPosts
                self.scrollToTop()
            }
        }
    }

    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }
        if let i = postsList.firstIndex(where: { $0.id == postID }) {
            postsList[i].commentCount = max(0, commentList.count - 1)
            postsList[i].commentList = commentList
            DispatchQueue.main.async {
                self.updateCommentsAndLikes(row: i)
            }
        }
    }

    func setSeen(post: MapPost) {
        /// set seen on map
        db.collection("posts").document(post.id ?? "").updateData(["seenList": FieldValue.arrayUnion([uid])])
        NotificationCenter.default.post(Notification(name: Notification.Name("PostOpen"), object: nil, userInfo: ["post": post as Any]))
        /// show notification as seen
        updateNotifications(postID: post.id ?? "")
    }

    func checkForUpdates(postID: String, index: Int) {
        Task {
            /// update just the necessary info -> comments and likes
            guard let post = try? await mapPostService?.getPost(postID: postID) else {
                return
            }

            if let i = self.postsList.firstIndex(where: { $0.id == postID }) {
                self.postsList[i].commentList = post.commentList
                self.postsList[i].commentCount = post.commentCount
                self.postsList[i].likers = post.likers
                /// update button view if this is the current post
                if index == self.selectedPostIndex {
                    self.updateCommentsAndLikes(row: index)
                }
            }
        }
    }

    func updateCommentsAndLikes(row: Int) {
        if let cell = self.contentTable.cellForRow(at: IndexPath(row: row, section: 0)) as? ContentViewerCell {
            // set values individually to avoid overwriting image data
            cell.post?.commentList = postsList[row].commentList
            cell.post?.commentCount = postsList[row].commentCount
            cell.post?.likers = postsList[row].likers
            cell.setCommentsAndLikes()
        }
    }

    func updateNotifications(postID: String) {
        db.collection("users").document(uid).collection("notifications").whereField("postID", isEqualTo: postID).getDocuments { snap, _ in
            guard let snap = snap else { return }
            for doc in snap.documents {
                doc.reference.updateData(["seen": true])
            }
        }
    }

    func updatePostIndex() {
        guard let post = postsList[safe: selectedPostIndex] else { return }
        DispatchQueue.global().async {
            self.setSeen(post: post)
            self.checkForUpdates(postID: post.id ?? "", index: self.selectedPostIndex)

            if self.parentVC == .Home {
                switch self.selectedSegment {
                case .MyPosts:
                    self.myPostIndex = self.selectedPostIndex
                    if self.postsList.count - self.selectedPostIndex < 5 {
                        if self.myPostsRefreshStatus == .refreshEnabled { self.getMyPosts() }
                    }
                case .NearbyPosts:
                    self.nearbyPostIndex = self.selectedPostIndex
                    if self.postsList.count - self.selectedPostIndex < 5 {
                        if self.nearbyRefreshStatus == .refreshEnabled { self.getNearbyPosts() }
                    }
                }
            }
        }
    }

    func removeTableAnimations() {
        for cell in contentTable.visibleCells {
            if let contentCell = cell as? ContentViewerCell {
                contentCell.post = nil
                contentCell.stopLocationAnimation()
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if parentVC == .Home { return }
        // disables scroll view "bounce" and enables drawer view swipeToDismiss method to take priority
        if scrollView.contentOffset.y < 0 {
            scrollView.contentOffset.y = 0
        }
        if scrollView.contentOffset.y > maxRowContentOffset {
            scrollView.contentOffset.y = maxRowContentOffset
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let velocity = scrollView.panGestureRecognizer.velocity(in: view)
        let translation = scrollView.panGestureRecognizer.translation(in: view)
        let composite = translation.y + velocity.y / 4

        let rowHeight = contentTable.bounds.height
        if composite < -(rowHeight / 4) && selectedPostIndex < postsList.count - 1 {
            selectedPostIndex += 1
        } else if composite > rowHeight / 4 && selectedPostIndex != 0 {
            selectedPostIndex -= 1
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - 1), animated: true)
        scrollView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y + 1), animated: true)
        scrollToSelectedRow(animated: true)
    }

    func scrollToSelectedRow(animated: Bool) {
        var duration: TimeInterval = 0.15
        if animated {
            let offset = abs(currentRowContentOffset - contentTable.contentOffset.y)
            duration = max(TimeInterval(0.25 * offset / contentTable.bounds.height), 0.15)
        }
        animatingToNextRow = true

        UIView.transition(with: contentTable, duration: duration, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.contentTable.setContentOffset(CGPoint(x: 0, y: CGFloat(self.currentRowContentOffset)), animated: false)
            self.contentTable.layoutIfNeeded()

        }, completion: { [weak self] _ in
            self?.tableViewOffset = false
            if let cell = self?.contentTable.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? ContentViewerCell {
                cell.animateLocation()
                self?.animatingToNextRow = false
            }
        })
    }

    func tapToSelectedRow(increment: Int? = 0) {
        // animate scroll view animation so that prefetch methods are called
        animatingToNextRow = true
        DispatchQueue.main.async {
            self.contentTable.scrollToRow(at: IndexPath(row: self.selectedPostIndex + (increment ?? 0), section: 0), at: .top, animated: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            // set selected post index after main animation to avoid clogging main thread
            if let increment, increment != 0 { self?.selectedPostIndex += increment }
            self?.animatingToNextRow = false
            if let cell = self?.contentTable.cellForRow(at: IndexPath(row: self?.selectedPostIndex ?? 0, section: 0)) as? ContentViewerCell {
                cell.animateLocation()
            }
        }
    }

    // called if table view or container view removal has begun
    func setCellOffsets(offset: Bool) {
        for cell in contentTable.visibleCells {
            if let cell = cell as? ContentViewerCell {
                cell.cellOffset = tableViewOffset
            }
        }
    }

    @objc func myWorldTap() {
        switch selectedSegment {
        case .MyPosts:
            scrollToTop()
        case .NearbyPosts:
            selectedSegment = .MyPosts
        }
    }

    @objc func nearbyTap() {
        switch selectedSegment {
        case .NearbyPosts:
            scrollToTop()
        case .MyPosts:
            selectedSegment = .NearbyPosts
        }
    }

    public func scrollToTop() {
        DispatchQueue.main.async { self.contentTable.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
        selectedPostIndex = 0
    }

    func setButtonBar(animated: Bool) {
        buttonBar.snp.removeConstraints()
        switch selectedSegment {
        case .NearbyPosts:
            nearbyButton.alpha = 1.0
            myWorldButton.alpha = 0.5
            buttonBar.snp.makeConstraints {
                $0.top.equalTo(nearbyButton.snp.bottom).offset(5)
                $0.centerX.equalTo(nearbyButton)
                $0.width.equalTo(65)
                $0.height.equalTo(3)
            }
        case .MyPosts:
            myWorldButton.alpha = 1.0
            nearbyButton.alpha = 0.5
            buttonBar.snp.makeConstraints {
                $0.top.equalTo(myWorldButton.snp.bottom).offset(5)
                $0.centerX.equalTo(myWorldButton)
                $0.width.equalTo(65)
                $0.height.equalTo(3)
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        }
    }
}
