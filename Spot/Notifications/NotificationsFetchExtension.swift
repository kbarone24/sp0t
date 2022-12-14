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
            
            Task {
                for doc in allDocs {
                    do {
                        let unwrappedNotification = try doc.data(as: UserNotification.self)
                        guard var notification = unwrappedNotification else { continue }
                        notification.id = doc.documentID

                        if !notification.seen {
                            try await doc.reference.updateData(["seen": true])
                        }
                        
                        let user = try await self.userService?.getUserInfo(userID: notification.senderID)
                        if user?.id != "" {
                            notification.userInfo = user
                            self.pendingFriendRequests.append(notification)
                        }

                    } catch {
                        self.fetchGroup.leave()
                    }
                }
                
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

            Task {
                for doc in docs {
                    do {
                        let notif = try doc.data(as: UserNotification.self)
                        guard var notification = notif else { continue }
                        notification.id = doc.documentID

                        if !notification.seen {
                            try await doc.reference.updateData(["seen": true])
                        }

                        if notification.status == "pending" {
                            continue
                        }
                        
                        let user = try await self.userService?.getUserInfo(userID: notification.senderID)
                        notification.userInfo = user

                        var brokenPost = false
                        if notification.type != "friendRequest" {
                            let postID = notification.postID ?? ""
                            let post = try await self.mapService?.getPost(postID: postID)
                            brokenPost = (post?.id ?? "") == ""
                            notification.postInfo = post
                        }

                            if !brokenPost {
                                self.notifications.append(notification)
                            }
                        
                    } catch {}
                }
                
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
