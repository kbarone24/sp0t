//
//  TabBarFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension SpotTabBarController {
    func getAdmins() {
        db.collection("users").whereField("admin", isEqualTo: true).getDocuments { (snap, _) in
            guard let snap = snap else { return }
            for doc in snap.documents { UserDataModel.shared.adminIDs.append(doc.documentID)
            }
        }
        // opt kenny/tyler/b0t/hog/test/john/ella out of tracking
        let uid = UserDataModel.shared.uid
        if uid == "djEkPdL5GQUyJamNXiMbtjrsUYM2" ||
            uid == "kwpjnnDCSKcTZ0YKB3tevLI1Qdi2" ||
            uid == "T4KMLe3XlQaPBJvtZVArqXQvaNT2" ||
            uid == "Za1OQPFoCWWbAdxB5yu98iE8WZT2" ||
            uid == "oAKwM2NgLjTlaE2xqvKEXiIVKYu1" ||
            uid == "2MpKovZvUYOR4h7YvAGexGqS7Uq1" ||
            uid == "W75L1D248ibsm6heDoV8AzlWXCx2" {
            Mixpanel.mainInstance().optOutTracking()
        }
    }

    func getActiveUser() {
        userListener = self.db.collection("users").document(UserDataModel.shared.uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (userSnap, err) in
            guard let self = self else { return }
            if userSnap?.metadata.isFromCache ?? false { return }
            if err != nil { return }

            /// get current user info
            let actUser = try? userSnap?.data(as: UserProfile.self)
            guard let activeUser = actUser else { return }
            if userSnap?.documentID ?? "" != UserDataModel.shared.uid { return } // logout + object not being destroyed

            if UserDataModel.shared.userInfo.id == "" {
                UserDataModel.shared.userInfo = activeUser
                self.getUserMaps()
            } else {
                self.updateUserInfo(user: activeUser)
            }

            NotificationCenter.default.post(Notification(name: Notification.Name("UserProfileLoad")))

            for userID in UserDataModel.shared.userInfo.friendIDs {
                Task {
                    do {
                        let userService = try ServiceContainer.shared.service(for: \.userService)
                        let friend = try await userService.getUserInfo(userID: userID)

                        if !UserDataModel.shared.userInfo.friendsList.contains(where: { $0.id == userID }) && !UserDataModel.shared.deletedFriendIDs.contains(userID) {
                            UserDataModel.shared.userInfo.friendsList.append(friend)

                            if UserDataModel.shared.userInfo.friendsList.count == UserDataModel.shared.userInfo.friendIDs.count {
                                UserDataModel.shared.userInfo.sortFriends() /// sort for top friends
                                NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListLoad")))
                            }
                        }
                    } catch {
                        UserDataModel.shared.userInfo.friendIDs.removeAll(where: { $0 == userID })
                    }
                }
            }
        })
    }

    private func updateUserInfo(user: UserProfile) {
        // set manually to avoid overwriting fetched values
        UserDataModel.shared.userInfo.avatarURL = user.avatarURL
        UserDataModel.shared.userInfo.currentLocation = user.currentLocation
        UserDataModel.shared.userInfo.imageURL = user.imageURL
        UserDataModel.shared.userInfo.name = user.name
        UserDataModel.shared.userInfo.hiddenUsers = user.hiddenUsers
        UserDataModel.shared.userInfo.pendingFriendRequests = user.pendingFriendRequests
        UserDataModel.shared.userInfo.spotScore = user.spotScore
        UserDataModel.shared.userInfo.topFriends = user.topFriends
        UserDataModel.shared.userInfo.friendIDs = user.friendIDs
        UserDataModel.shared.userInfo.username = user.username
        print("update user info", user.username)
    }

    func getUserMaps() {
        mapsListener = db.collection("maps").whereField("likers", arrayContains: UserDataModel.shared.uid).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] snap, _ in
            guard let self = self else { return }
            guard let snap = snap else { return }
            if snap.metadata.isFromCache { return }
            for doc in snap.documents {
                do {
                    let mapIn = try? doc.data(as: CustomMap.self)
                    guard var mapInfo = mapIn else { continue }
                    if UserDataModel.shared.deletedMapIDs.contains(where: { $0 == mapInfo.id }) { continue }
                    if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapInfo.id }) {
                        self.updateMap(map: mapInfo, index: i)
                        continue
                    }
                 //   mapInfo.addSpotGroups()
                    UserDataModel.shared.userInfo.mapsList.append(mapInfo)
                    print("maps list", UserDataModel.shared.userInfo.mapsList.count)
                }
            }

            NotificationCenter.default.post(Notification(name: Notification.Name("UserMapsLoad")))
            UserDataModel.shared.userInfo.sortMaps()
        })
    }

    private func updateMap(map: CustomMap, index: Int) {
        // might not need to update values separately on new fetch
        let oldMap = UserDataModel.shared.userInfo.mapsList[index]
        var newMap = map
        newMap.postsDictionary = oldMap.postsDictionary
        newMap.postGroup = oldMap.postGroup
        UserDataModel.shared.userInfo.mapsList[index] = newMap
    }
}
