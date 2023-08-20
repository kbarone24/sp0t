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
import Mixpanel

// notifications and map fetches
extension UserDataModel {
    func addUserListener() {
        userListener = db.collection("users").document(uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (userSnap, err) in
            guard let self = self else { return }
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }

            /// get current user info
            guard let activeUser = try? userSnap?.data(as: UserProfile.self) else { return }
            if userSnap?.documentID ?? "" != self.uid { return } // logout + object not being destroyed

            if self.userInfo.username == "" {
                self.userInfo = activeUser

                if AdminsAndBurners().containsUserPhoneNumber() {
                    Mixpanel.mainInstance().optOutTracking()
                }

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
        userInfo.hiddenUsers = user.hiddenUsers
        userInfo.pendingFriendRequests = user.pendingFriendRequests
        userInfo.spotScore = user.spotScore
        userInfo.topFriends = user.topFriends
        userInfo.friendIDs = user.friendIDs
        userInfo.username = user.username
        userInfo.newAvatarNoti = user.newAvatarNoti
    }
}
