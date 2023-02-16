//
//  UserDataModelFetch.swift
//  Spot
//
//  Created by Kenny Barone on 2/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

// notifications and map fetches
extension UserDataModel {
    func addUserListener() {
        userListener = db.collection("users").document(uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (userSnap, err) in
            guard let self = self else { return }
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }

            /// get current user info
            let actUser = try? userSnap?.data(as: UserProfile.self)
            guard let activeUser = actUser else { return }
            if userSnap?.documentID ?? "" != self.uid { return } // logout + object not being destroyed

            if self.userInfo.id == "" {
                let mapsList = self.userInfo.mapsList
                self.userInfo = activeUser
                self.userInfo.mapsList = mapsList
            } else {
                self.updateUserInfo(user: activeUser)
            }

            NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))

            for userID in self.userInfo.friendIDs {
                Task {
                    do {
                        let userService = try ServiceContainer.shared.service(for: \.userService)
                        let friend = try await userService.getUserInfo(userID: userID)

                        if !self.userInfo.friendsList.contains(where: { $0.id == userID }) && !self.deletedFriendIDs.contains(userID) {
                            self.userInfo.friendsList.append(friend)

                            if self.userInfo.friendsList.count == self.userInfo.friendIDs.count {
                                self.userInfo.sortFriends() /// sort for top friends
                                NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                            }
                        }
                    } catch {
                        self.userInfo.friendIDs.removeAll(where: { $0 == userID })
                    }
                }
            }
        })
    }

    private func updateUserInfo(user: UserProfile) {
        // set manually to avoid overwriting fetched values
        userInfo.avatarURL = user.avatarURL
        userInfo.currentLocation = user.currentLocation
        userInfo.imageURL = user.imageURL
        userInfo.name = user.name
        userInfo.hiddenUsers = user.hiddenUsers
        userInfo.pendingFriendRequests = user.pendingFriendRequests
        userInfo.spotScore = user.spotScore
        userInfo.topFriends = user.topFriends
        userInfo.friendIDs = user.friendIDs
        userInfo.username = user.username
    }

    func addMapsListener() {
        mapsListener = db.collection("maps").whereField("likers", arrayContains: uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            for doc in snap.documents {
                do {
                    let mapIn = try? doc.data(as: CustomMap.self)
                    guard let mapInfo = mapIn else { continue }
                    if self.deletedMapIDs.contains(where: { $0 == mapInfo.id }) { continue }
                    if let i = self.userInfo.mapsList.firstIndex(where: { $0.id == mapInfo.id }) {
                        self.updateMap(map: mapInfo, index: i)
                        continue
                    }
                    //   mapInfo.addSpotGroups()
                    self.userInfo.mapsList.append(mapInfo)
                }
            }

            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
            self.userInfo.sortMaps()
        })
    }

    private func updateMap(map: CustomMap, index: Int) {
        // might not need to update values separately on new fetch
        let oldMap = userInfo.mapsList[index]
        var newMap = map
        newMap.postsDictionary = oldMap.postsDictionary
        newMap.postGroup = oldMap.postGroup
        userInfo.mapsList[index] = newMap
    }

    func addNotificationsListener() {
        let query = db.collection("users").document(uid).collection("notifications").limit(to: 12).order(by: "seen").order(by: "timestamp", descending: true)
        notificationsListener = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            if snap?.metadata.isFromCache ?? false { return }
            guard let snap = snap else { return }
            print("set noti info")
            self.setNotiInfo(snap: snap, newFetch: !self.notificationsFetched)
        })
    }

    public func getNotifications() {
        notificationsRefreshStatus = .activelyRefreshing
        var query = db.collection("users").document(uid).collection("notifications").limit(to: 12).order(by: "seen").order(by: "timestamp", descending: true)
        if let notificationsEndDocument { print("end document id", notificationsEndDocument.documentID); query = query.start(afterDocument: notificationsEndDocument) }
        query.getDocuments { snap, _ in
            guard let snap = snap else { return }
            // set seen on get fetch because tableView is already present
            DispatchQueue.global(qos: .utility).async { self.setSeenForDocumentIDs(docIDs: snap.documents.map { $0.documentID }) }
            self.setNotiInfo(snap: snap, newFetch: true)
        }
    }

    private func setNotiInfo(snap: QuerySnapshot, newFetch: Bool) {
        if newFetch && snap.documents.count < 12 {
            notificationsRefreshStatus = .refreshDisabled
        } else {
            notificationsEndDocument = snap.documents.last
        }

        Task {
            for doc in snap.documents {
                do {
                    let unwrappedNotification = try? doc.data(as: UserNotification.self)
                    guard var notification = unwrappedNotification else { continue }
                    if self.notifications.contains(where: { $0.id ?? "" == notification.id ?? "" }) { continue }
                    let user = try await self.userService?.getUserInfo(userID: notification.senderID)
                    if user?.id == "" { continue }
                    notification.userInfo = user

                    if notification.type != "friendRequest" {
                        let postID = notification.postID ?? ""
                        let post = try await self.mapService?.getPost(postID: postID)
                        if post?.id ?? "" == "" { continue }
                        notification.postInfo = post

                    } else if notification.status == "pending" {
                        self.pendingFriendRequests.append(notification)
                        continue
                    }
                    self.localNotis.append(notification)
                }
            }
            self.sortAndReloadNotifications()
        }
    }

    private func sortAndReloadNotifications() {
        notificationsFetched = true
        pendingFriendRequests.sort(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        localNotis.sort(by: { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen })
        notifications.append(contentsOf: localNotis)
        localNotis.removeAll()
        if notificationsRefreshStatus != .refreshDisabled { print("set refresh enabled"); notificationsRefreshStatus = .refreshEnabled }
        if notifications.count < 8 && notificationsRefreshStatus == .refreshEnabled {
            DispatchQueue.global(qos: .utility).async { self.getNotifications() }
        }
        NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsLoad")))
    }

    public func setSeenForDocumentIDs(docIDs: [String]) {
        let batch = db.batch()
        for docID in docIDs {
            if let i = notifications.firstIndex(where: { $0.id ?? "" == docID }) {
                notifications[i].seen = true
            }
            let docRef = db.collection("users").document(uid).collection("notifications").document(docID)
            batch.updateData(["seen": true], forDocument: docRef)
        }
        batch.commit()
        // sepearate notification to avoid uneccessary noti table view reloading
        NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsSeenSet")))
    }

    @objc func notifyFriendRequestAccept(_ notification: NSNotification) {
        if !pendingFriendRequests.isEmpty {
            for i in 0...pendingFriendRequests.count - 1 {
                if let noti = notification.userInfo?["notiID"] as? String {
                    if pendingFriendRequests[safe: i]?.id == noti {
                        var newNoti = pendingFriendRequests.remove(at: i)
                        newNoti.status = "accepted"
                        newNoti.timestamp = Timestamp()
                        UserDataModel.shared.notifications.append(newNoti)
                    }
                }
            }
        }
        self.sortAndReloadNotifications()
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        notifications.removeAll(where: { $0.postID == post.id })
        if mapDelete {
            notifications.removeAll(where: { $0.mapID == post.mapID })
        }
        sortAndReloadNotifications()
    }
}