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
