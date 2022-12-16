//
//  FindFriendsFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension FindFriendsController {
    func fetchTableData() {
        // run fetch only once friends list fetched from map
        if UserDataModel.shared.userInfo.friendsList.isEmpty { return }
        dispatch.enter()
        dispatch.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getSuggestedFriends()
            self.getContacts()
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }

    func runNewAuthContactsFetch() {
        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        dispatch.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getContacts()
        }

        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }

    func getContacts() {
        // show contacts empty state
        if self.contactsAuth != .authorized {
            self.dispatch.leave()
            return
        }

        let contactsFetcher = ContactsFetcher()
        contactsFetcher.runFetch { contacts, err in
            if err != nil { print("err", err as Any) }
            for contact in contacts {
                self.contacts.append((contact, .none))
            }
            self.contacts.sort(by: { $0.0.name < $1.0.name })
            self.dispatch.leave()
        }
    }

    func getSuggestedFriends() {
        // get mutual friends by cycling through friends of everyone on friendsList
        for friend in UserDataModel.shared.userInfo.friendsList where !UserDataModel.shared.adminIDs.contains(friend.id ?? "") {
            for mutual in friend.topFriends ?? [:] {
                let id = mutual.key
                // only add non-friends + people we haven't sent a request to yet
                if shouldAddToMutuals(id: id) {
                    addToMutuals(id: id, mutualValue: mutual.value, friendValue: UserDataModel.shared.userInfo.topFriends?[friend.id ?? ""] ?? 0)
                }
            }
        }

        mutuals.sort(by: { $0.score > $1.score })
        if mutuals.count < 10 {
            // go through users friend requests to suggest users
            getPendingFriends()
        } else {
            getSuggestedFriendProfiles()
        }
    }

    func shouldAddToMutuals(id: String) -> Bool {
        let addToMutuals =
        !(UserDataModel.shared.userInfo.friendIDs.contains(id) ||
        UserDataModel.shared.userInfo.pendingFriendRequests.contains(id) ||
        UserDataModel.shared.adminIDs.contains(id) ||
        (UserDataModel.shared.userInfo.hiddenUsers?.contains(id) ?? false) ||
        id == uid ||
        id == "")
        return addToMutuals
    }

    func addToMutuals(id: String, mutualValue: Int, friendValue: Int) {
        let compositeRating = friendValue * 3 + mutualValue
        if let i = mutuals.firstIndex(where: { $0.id == id }) {
            mutuals[i].score += compositeRating
        } else {
            mutuals.append((id: id, score: compositeRating))
        }
    }

    func getPendingFriends() {
        // get "mutuals" from pending friend requests to fill up the rest of suggestions
        let pendingRequests = UserDataModel.shared.userInfo.pendingFriendRequests
        // if no pending requests either get users who have posted near user's location or just roll with mutuals we have
        print("mutuals count", mutuals.count)
        if pendingRequests.isEmpty {
            if mutuals.count < 5 {
                getNearbyUsers(radius: 500)
            } else {
                getSuggestedFriendProfiles()
            }
            return
        }

        let dispatch = DispatchGroup()
        for id in pendingRequests {
            dispatch.enter()
            self.db.collection("users").document(id).getDocument { [weak self] (snap, _) in
                guard let self = self else { return }
                do {
                    let unwrappedUser = try snap?.data(as: UserProfile.self)
                    guard let user = unwrappedUser else { dispatch.leave(); return }
                    for user in user.topFriends ?? [:] {
                        if self.shouldAddToMutuals(id: user.key) { self.addToMutuals(id: user.key, mutualValue: user.value, friendValue: 0)}
                        dispatch.leave()
                    }
                } catch { dispatch.leave() }
            }
        }

        dispatch.notify(queue: .global()) {
            self.getSuggestedFriendProfiles()
        }
    }

    func getSuggestedFriendProfiles() {
        let topMutuals = mutuals.prefix(25)
        let dispatch = DispatchGroup()
        for user in topMutuals {
            dispatch.enter()
            self.db.collection("users").document(user.id).getDocument { [weak self] (snap, _) in
                guard let self = self else { return }
                do {
                    let userIn = try snap?.data(as: UserProfile.self)
                    guard var userInfo = userIn else { dispatch.leave(); return }
                    userInfo.mutualFriendsScore = user.score
                    self.suggestedUsers.append((userInfo, .none))
                    dispatch.leave()
                } catch {
                    dispatch.leave()
                }
            }
        }
        dispatch.notify(queue: .global()) {
            self.finishSuggestedLoad()
        }
    }

    func finishSuggestedLoad() {
        // sort by combined spots x mutual friends
        suggestedUsers.sort(by: { $0.0.mutualFriendsScore > $1.0.mutualFriendsScore })
        dispatch.leave()
    }
}

// fetch nearby posts to find top users in area
extension FindFriendsController {
    func getNearbyUsers(radius: CGFloat? = 500) {
        let center = UserDataModel.shared.currentLocation.coordinate
        let searchLimit = 20
        let radius = radius ?? 500

        DispatchQueue.global().async {
            Task {
                await self.mapPostService?.getNearbyPosts(center: center, radius: radius, searchLimit: searchLimit, completion: { [weak self] posts in
                    guard let self = self else { return }
                    // get more posts to show more users
                    if posts.count < 5 && radius < 16_000 {
                        self.getNearbyUsers(radius: radius * 2)
                    } else {
                        self.addNearbyUsersFrom(posts: posts)
                    }
                })
            }
        }
    }

    func addNearbyUsersFrom(posts: [MapPost]) {
        var nearbyUserIDs: [(id: String, score: Int)] = []
        for post in posts {
            if let i = nearbyUserIDs.firstIndex(where: { $0.id == post.posterID }) {
                nearbyUserIDs[i].score += 1
            } else {
                nearbyUserIDs.append((id: post.posterID, score: 0))
            }
        }
        fetchNearbyUserProfiles(userIDs: nearbyUserIDs)
    }

    func fetchNearbyUserProfiles(userIDs: [(id: String, score: Int)]) {
        // fetching individual users slowing nearby posts fetch down
        // fetch nearby users when its actually time to add them
        let dispatch = DispatchGroup()
        for userID in userIDs {
            dispatch.enter()
            Task {
                do {
                    let user = try await userService?.getUserInfo(userID: userID.id)
                    // filter out old users (no avatar set)
                    guard var user, user.avatarURL ?? "" != "" else { dispatch.leave(); return }
                    user.mutualFriendsScore = userID.score
                    self.suggestedUsers.append((user, .none))
                    dispatch.leave()
                } catch {
                    dispatch.leave()
                    return
                }
            }
        }
        dispatch.notify(queue: .global()) {
            self.finishSuggestedLoad()
        }
    }
}
