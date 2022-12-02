//
//  NotificationsFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

extension NotificationsController {
    func fetchNotifications(refresh: Bool) {
        // fetchGroup is the high-level dispatch for both fetches
        fetchGroup.enter()
        fetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getFriendRequests(refresh: refresh)
            self.getActivityNotifications(refresh: refresh)
        }

        fetchGroup.notify(queue: DispatchQueue.main) { [weak self] in
            guard let self = self else { return }
            self.sortAndReload()
        }
    }

    func getFriendRequests(refresh: Bool) {
        let friendReqRef = db.collection("users").document(uid).collection("notifications")
        let friendRequestQuery = friendReqRef.whereField("type", isEqualTo: "friendRequest").whereField("status", isEqualTo: "pending")

        friendRequestQuery.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { self.fetchGroup.leave(); return }
            // checking if all pending friend requests have been queried
            if allDocs.isEmpty || allDocs.count == self.pendingFriendRequests.count {
                self.fetchGroup.leave()
                return
            }

            let friendRequestGroup = DispatchGroup()
            for doc in allDocs {
                friendRequestGroup.enter()
                do {
                    let unwrappedNotification = try doc.data(as: UserNotification.self)
                    guard var notification = unwrappedNotification else { friendRequestGroup.leave(); continue }
                    notification.id = doc.documentID

                    if !notification.seen {
                        doc.reference.updateData(["seen": true])
                    }
                    self.getUserInfo(userID: notification.senderID) { [weak self] (user) in
                        guard let self = self else { return }
                        if user.id != "" {
                            notification.userInfo = user
                            self.pendingFriendRequests.append(notification)
                        }
                        friendRequestGroup.leave()
                    }

                } catch {
                    friendRequestGroup.leave() }
            }
            // leave friend request group once all friend requests are appended
            friendRequestGroup.notify(queue: .main) {
                self.fetchGroup.leave()
            }
        }
    }

    func getActivityNotifications(refresh: Bool) {
        let notiRef = db.collection("users").document(uid).collection("notifications").limit(to: 15)
        var notiQuery = notiRef.order(by: "timestamp", descending: true)

        if let endDocument, !refresh {
            notiQuery = notiQuery.start(atDocument: endDocument)
        }

        notiQuery.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }

            if allDocs.isEmpty {
                self.fetchGroup.leave(); return }
            if allDocs.count < 15 {
                self.refresh = .refreshDisabled
            }

            self.endDocument = allDocs.last
            let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()

            let notiGroup = DispatchGroup()
            for doc in docs {
                notiGroup.enter()
                do {
                    let notif = try doc.data(as: UserNotification.self)
                    guard var notification = notif else { notiGroup.leave(); continue }
                    notification.id = doc.documentID

                    if !notification.seen {
                        doc.reference.updateData(["seen": true])
                    }

                    if notification.status == "pending" {
                        notiGroup.leave(); continue }

                    // enter user group to ensure that both getUserInfo and getPost have both returned before appending the new notification
                    let userGroup = DispatchGroup()
                    userGroup.enter()
                    self.getUserInfo(userID: notification.senderID) { user in
                        notification.userInfo = user
                        userGroup.leave()
                    }

                    var brokenPost = false
                    if notification.type != "friendRequest" {
                        userGroup.enter()
                        let postID = notification.postID ?? ""
                        self.getPost(postID: postID) { post in
                            brokenPost = (post.id ?? "") == ""
                            notification.postInfo = post
                            userGroup.leave()
                        }
                    }

                    userGroup.notify(queue: .main) { [weak self] in
                        guard let self = self else { return }
                        if !brokenPost { self.notifications.append(notification) }
                        notiGroup.leave()
                    }
                } catch { notiGroup.leave() }
            }
            notiGroup.notify(queue: .main) {
                self.fetchGroup.leave()
            }
        }
    }

    func sortAndReload() {
        self.notifications = self.notifications.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        self.pendingFriendRequests = self.pendingFriendRequests.sorted(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        // so notfications aren't empty if the user is pendingFriendRequest heavy
        if((pendingFriendRequests.isEmpty && notifications.count < 11) || (!pendingFriendRequests.isEmpty && notifications.count < 7)) && refresh == .refreshEnabled {
            fetchNotifications(refresh: false)
        }
        if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // tries to query more data when the user is about 5 cells from hitting the end
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 350)) && refresh == .refreshEnabled {
            // reload to show activity indicator
            DispatchQueue.main.async { self.tableView.reloadData() }
            fetchNotifications(refresh: false)
            refresh = .activelyRefreshing
        }
    }
}
