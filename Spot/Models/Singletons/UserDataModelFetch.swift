//
//  UserDataModelFetch.swift
//  Spot
//
//  Created by Kenny Barone on 2/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseFirestore

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
            
            Task(priority: .utility) {
                do {
                    let userService = try ServiceContainer.shared.service(for: \.userService)
                    let fetchedList = try await userService.getUserFriends()
                    let cachedList = self.userInfo.friendsList
                    // patch fix intended to run this function less due to double ptr crash
                    
                    guard fetchedList != cachedList else {
                        return
                    }
                    
                    let combinedList = (cachedList + fetchedList).removingDuplicates()

                    // Trying to move to main thread to avoid bad access crashes
                    DispatchQueue.main.async {
                        self.userInfo.friendsList = combinedList
                        if !self.friendsFetched {
                            // sort for top friends
                            self.userInfo.sortFriends()
                        }
                    }

                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                    self.friendsFetched = true
                } catch {
                    return
                }
            }
        })
    }

    private func updateUserInfo(user: UserProfile) {
        // set manually to avoid overwriting fetched values
        userInfo.avatarURL = user.avatarURL
        userInfo.avatarFamily = user.avatarFamily
        userInfo.avatarItem = user.avatarItem
        userInfo.userBio = user.userBio
        userInfo.currentLocation = user.currentLocation
        userInfo.imageURL = user.imageURL
        userInfo.name = user.name
        userInfo.hiddenUsers = user.hiddenUsers
        userInfo.pendingFriendRequests = user.pendingFriendRequests
        userInfo.spotScore = user.spotScore
        userInfo.topFriends = user.topFriends
        userInfo.friendIDs = user.friendIDs
        userInfo.username = user.username
        userInfo.newAvatarNoti = user.newAvatarNoti
        NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileUpdate")))
    }

    private func updateMap(map: CustomMap, index: Int) {
        // might not need to update values separately on new fetch
        userInfo.mapsList[index] = map
    }

    func addNotificationsListener() {
        if ContactsFetcher.shared.contactsAuth == .authorized { ContactsFetcher.shared.getContacts() }
        let query = db.collection("users").document(uid).collection("notifications").limit(to: 12).order(by: "seen").order(by: "timestamp", descending: true)
        notificationsListener = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            if snap?.metadata.isFromCache ?? false { return }
            guard let snap = snap else { return }
            self.setNotiInfo(snap: snap, newFetch: !self.notificationsFetched)
        })
    }

    public func getNotifications() {
        notificationsRefreshStatus = .activelyRefreshing
        var query = db.collection("users").document(uid).collection("notifications").limit(to: 12).order(by: "seen").order(by: "timestamp", descending: true)
        if let notificationsEndDocument { query = query.start(afterDocument: notificationsEndDocument) }
        query.getDocuments { snap, _ in
            guard let snap = snap else { return }
            // reached end of documents
            guard !snap.documents.isEmpty else {
                self.notificationsRefreshStatus = .refreshDisabled
                NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsLoad")))
                return
            }
            // set seen on get fetch because tableView is already present
            DispatchQueue.global(qos: .utility).async { self.setSeenForDocumentIDs(docIDs: snap.documents.map { $0.documentID }) }
            self.setNotiInfo(snap: snap, newFetch: true)
        }
    }

    private func setNotiInfo(snap: QuerySnapshot, newFetch: Bool) {
        if newFetch, snap.documents.count < 12 {
            notificationsRefreshStatus = .refreshDisabled
        } else {
            notificationsEndDocument = snap.documents.last
        }

        Task {
            var localNotis: [UserNotification] = []
            var appendedFriendRequest = false
            for doc in snap.documents {
                do {
                    let unwrappedNotification = try? doc.data(as: UserNotification.self)
                    guard var notification = unwrappedNotification else { continue }
                    if self.notifications.contains(where: { $0.id ?? "" == notification.id ?? "" }) || self.pendingFriendRequests.contains(where: { $0.id ?? "" == notification.id ?? "" }) { continue }
                    let user = try await self.userService?.getUserInfo(userID: notification.senderID)
                    guard var user, user.id != "" else { continue }

                    if notification.type != "friendRequest" && notification.type != "contactJoin" {
                        let postID = notification.postID ?? ""
                        let post = try await self.mapService?.getPost(postID: postID)
                        if post?.id ?? "" == "" { continue }
                        notification.postInfo = post

                    } else if notification.status == "pending" {
                        user.contactInfo = getContactFor(number: user.phone ?? "")
                        notification.userInfo = user
                        self.pendingFriendRequests.append(notification)
                        appendedFriendRequest = true
                        continue

                    } else if notification.type == "contactJoin" {
                        user.contactInfo = getContactFor(number: user.phone ?? "")
                    }

                    notification.userInfo = user
                    localNotis.append(notification)
                }
            }
            if !localNotis.isEmpty || appendedFriendRequest {
                sortAndReloadNotifications(newFetch: newFetch, localNotis: localNotis)
            }
        }
    }

    private func sortAndReloadNotifications(newFetch: Bool, localNotis: [UserNotification]) {
        notificationsFetched = true
        pendingFriendRequests.sort(by: { $0.timestamp.seconds > $1.timestamp.seconds })
        var localNotis = localNotis
        localNotis.sort(by: { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen })
        if newFetch {
            notifications.append(contentsOf: localNotis)
        } else {
            // inserting and removing duplicates was causing seenList to reset on new values
            for noti in localNotis where !notifications.contains(where: { $0.id == noti.id }) {
                notifications.insert(noti, at: 0)

                // update old post objects if this is a new like / comment on a post
                for i in 0..<notifications.count {
                    if notifications[i].postID == noti.postID {
                        notifications[i].postInfo = noti.postInfo
                    }
                }
            }
            // resort due to random old notis coming through on the listener query and getting appended at the front
            notifications.sort(by: { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen })
        }
        notifications.removeDuplicates()
        pendingFriendRequests.removeDuplicates()

        if notificationsRefreshStatus != .refreshDisabled { notificationsRefreshStatus = .refreshEnabled }
        NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsLoad")))

        // re-run fetch if fetch pulled in a bunch of old friend requests and notis dont fill screen
        if notifications.count < 8, newFetch, notificationsRefreshStatus == .refreshEnabled {
            DispatchQueue.global(qos: .userInitiated).async { self.getNotifications() }
        }
    }

    private func getContactFor(number: String) -> ContactInfo? {
        let number = String(number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().suffix(10))
        return ContactsFetcher.shared.contactInfos.first(where: { $0.formattedNumber == number })
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
        if let notiID = notification.userInfo?.values.first as? String {
            if let i = pendingFriendRequests.firstIndex(where: { $0.id == notiID }) {
                pendingFriendRequests[i].seen = true
                pendingFriendRequests[i].status = "accepted"
                pendingFriendRequests[i].timestamp = Timestamp()
            }
        }
        NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsSeenSet")))
    }

    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        guard let mapDelete = notification.userInfo?["mapDelete"] as? Bool else { return }
        notifications.removeAll(where: { $0.postID == post.id })
        if mapDelete {
            notifications.removeAll(where: { $0.mapID == post.mapID })
            userInfo.mapsList.removeAll(where: { $0.id == post.mapID })
        }
        NotificationCenter.default.post(Notification(name: Notification.Name("NotificationsLoad")))
    }
}
