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

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?

    var avatarURL: String? = ""
    var avatarFamily: String? = ""
    var avatarItem: String? = ""
    var blockedBy: [String]?
    var blockedUsers: [String]? = []
    var friendIDs: [String] = []
    var hiddenUsers: [String]? = []
    var pendingFriendRequests: [String] = []
    var phone: String? = ""
    var sentInvites: [String] = []
    var spotScore: Int? = 0
    var topFriends: [String: Int]? = [:]
    var userBio: String
    var username: String
    var spotsList: [String]? = []
    var postCount: Int?
    var reportedBy: [String]? = []

    var lastSeen: Timestamp?
    var lastHereNow: String?

    // supplemental values
    var avatarPic: UIImage = UIImage()
    var contactInfo: ContactInfo?

    var friendsList: [UserProfile] = []
    var mutualFriendsScore: Int = 0
    var selected: Bool = false
    var mapsList: [CustomMap] = []

    var newAvatarNoti: Bool? = false

    // used to force profile table updates because it won't recognize when friend status has changed
    var updateToggle = false

    var friendStatus: FriendStatus? {
        if let id {
            let friendStatus = id == Auth.auth().currentUser?.uid ?? "" ? FriendStatus.activeUser
            : UserDataModel.shared.userInfo.blockedUsers?.contains(id) ?? false ? FriendStatus.blocked
            // switched to check user's friendID's rather than userdatamodel due to exc_bad_access crash
            : friendIDs.contains(UserDataModel.shared.uid) ? FriendStatus.friends
            : UserDataModel.shared.userInfo.pendingFriendRequests.contains(id) ? FriendStatus.pending
            : pendingFriendRequests.contains(UserDataModel.shared.uid) ? FriendStatus.acceptable
            : FriendStatus.none
            return friendStatus
        }
        return nil
    }

    var flagged: Bool {
        return reportedBy?.count ?? 0 > 4
    }

    enum CodingKeys: String, CodingKey {
        case id
        case blockedBy
        case blockedUsers
        case avatarURL
        case avatarFamily
        case avatarItem
        case friendIDs = "friendsList"
        case hiddenUsers
        case newAvatarNoti
        case pendingFriendRequests
        case phone
        case spotScore
        case topFriends
        case userBio
        case username
        case spotsList
        case postCount
        case lastSeen
        case lastHereNow
        case reportedBy
    }

    init() {
        self.friendIDs = []
        self.pendingFriendRequests = []
        self.sentInvites = []
        self.userBio = ""
        self.username = ""
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
        guard let family = AvatarFamily(rawValue: avatarFamily) else { return UIImage() }
        let item = avatarItem ?? ""
        let avatarProfile = AvatarProfile(family: family, item: AvatarItem(rawValue: item) ?? .none)
        return UIImage(named: avatarProfile.avatarName) ?? UIImage()
    }
}

extension UserProfile: Hashable {
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        return lhs.id == rhs.id &&
        lhs.friendStatus == rhs.friendStatus &&
        lhs.avatarURL == rhs.avatarURL &&
        lhs.blockedBy == rhs.blockedBy &&
        lhs.blockedUsers == rhs.blockedUsers &&
        lhs.friendIDs == rhs.friendIDs &&
        lhs.hiddenUsers == rhs.hiddenUsers &&
        lhs.pendingFriendRequests == rhs.pendingFriendRequests &&
        lhs.phone == rhs.phone &&
        lhs.spotScore == rhs.spotScore &&
        lhs.userBio == rhs.userBio &&
        lhs.username == rhs.username &&
        lhs.spotsList == rhs.spotsList &&
        lhs.updateToggle == rhs.updateToggle &&
        lhs.newAvatarNoti == rhs.newAvatarNoti
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(friendStatus)
        hasher.combine(avatarURL)
        hasher.combine(blockedBy)
        hasher.combine(blockedUsers)
        hasher.combine(friendIDs)
        hasher.combine(hiddenUsers)
        hasher.combine(pendingFriendRequests)
        hasher.combine(phone)
        hasher.combine(spotScore)
        hasher.combine(userBio)
        hasher.combine(username)
        hasher.combine(spotsList)
        hasher.combine(updateToggle)
        hasher.combine(newAvatarNoti)
    }
}
