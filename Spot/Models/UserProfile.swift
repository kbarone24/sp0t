//
//  UserProfile.swift
//  Spot
//
//  Created by kbarone on 8/4/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import UIKit

struct UserProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    var avatarURL: String? = ""
    var avatarFamily: String? = ""
    var avatarItem: String? = ""
    var blockedBy: [String]?
    var blockedUsers: [String]? = []
    var currentLocation: String
    var friendIDs: [String] = []
    var hiddenUsers: [String]? = []
    var imageURL: String
    var name: String
    var pendingFriendRequests: [String] = []
    var phone: String? = ""
    var sentInvites: [String] = []
    var spotScore: Int? = 0
    var topFriends: [String: Int]? = [:]
    var userBio: String
    var username: String

    // supplemental values
    var avatarPic: UIImage = UIImage()
    var contactInfo: ContactInfo?

    var spotsList: [String] = []
    var friendsList: [UserProfile] = []
    var mutualFriendsScore: Int = 0
    var selected: Bool = false
    var mapsList: [CustomMap] = []

    var pending: Bool?
    var friend: Bool?
    var respondedToCampusMap: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case blockedBy
        case blockedUsers
        case avatarURL
        case avatarFamily
        case avatarItem
        case currentLocation
        case friendIDs = "friendsList"
        case hiddenUsers
        case imageURL
        case name
        case pendingFriendRequests
        case phone
        case sentInvites
        case respondedToCampusMap
        case spotScore
        case topFriends
        case userBio
        case username
    }

    mutating func sortMaps() {
        // sort first by maps that have an unseen post, then by most recent post timestamp
        mapsList = mapsList.sorted(by: { m1, m2 in
            guard m1.hasNewPost == m2.hasNewPost else {
                return m1.hasNewPost && !m2.hasNewPost
            }
            return m1.postTimestamps.last?.seconds ?? 0 > m2.postTimestamps.last?.seconds ?? 0
        })
    }

    func getSelectedFriends(memberIDs: [String]) -> [UserProfile] {
        var selectedFriends = friendsList
        for member in memberIDs {
            if let i = friendsList.firstIndex(where: { $0.id == member }) {
                selectedFriends[i].selected = true
            }
        }
        return selectedFriends
    }

    func friendsContains(id: String) -> Bool {
        return id == self.id || friendIDs.contains(id)
    }

    mutating func sortFriends() {
        // sort friends based on user's top friends
        if topFriends?.isEmpty ?? true { return }

        let topFriendsDictionary = topFriends ?? [:]
        let sortedFriends = topFriendsDictionary.sorted(by: { $0.value > $1.value })
        friendIDs = sortedFriends.map({ $0.key })

        let topFriends = Array(sortedFriends.map({ $0.key }))
        var friendObjects: [UserProfile] = []

        for friend in topFriends {
            if let object = friendsList.first(where: { $0.id == friend }) {
                friendObjects.append(object)
            }
        }
        // add any friend not in top friends
        for friend in friendsList where !friendObjects.contains(where: { $0.id == friend.id }) {
            friendObjects.append(friend)
        }
        friendsList = friendObjects
    }

    func getAvatarImage() -> UIImage {
        guard let avatarFamily, avatarFamily != "" else { return UIImage() }
        let item = avatarItem ?? ""
        let avatarProfile = AvatarProfile(family: AvatarFamily(rawValue: avatarFamily) ?? .Bear, item: AvatarItem(rawValue: item) ?? .none)
        return UIImage(named: avatarProfile.avatarName) ?? UIImage()
    }
}

extension UserProfile {
    init(from userProfile: UserProfileCache) {
        self.id = userProfile.id
        self.avatarURL = userProfile.avatarURL
        self.blockedBy = userProfile.blockedBy
        self.blockedUsers = userProfile.blockedUsers
        self.currentLocation = userProfile.currentLocation ?? ""
        self.friendIDs = userProfile.friendIDs ?? []
        self.hiddenUsers = userProfile.hiddenUsers
        self.imageURL = userProfile.imageURL ?? ""
        self.name = userProfile.name ?? ""
        self.pendingFriendRequests = userProfile.pendingFriendRequests ?? []
        self.phone = userProfile.phone
        self.sentInvites = userProfile.sentInvites ?? []
        self.spotScore = userProfile.spotScore
        self.topFriends = userProfile.topFriends
        self.userBio = userProfile.userBio ?? ""
        self.username = userProfile.username ?? ""
        self.avatarPic = userProfile.avatarPic ?? UIImage()
        self.spotsList = userProfile.spotsList ?? []
        self.friendsList = userProfile.friendsList?.map { UserProfile(from: $0) } ?? []
        self.mutualFriendsScore = userProfile.mutualFriendsScore ?? 0
        self.selected = userProfile.selected ?? false
        self.mapsList = userProfile.mapsList?.map { CustomMap(customMap: $0) } ?? []
        self.pending = userProfile.pending
        self.friend = userProfile.friend
        self.respondedToCampusMap = userProfile.respondedToCampusMap
    }
}
