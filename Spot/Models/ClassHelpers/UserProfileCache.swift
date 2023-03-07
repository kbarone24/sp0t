//
//  UserProfileCache.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

final class UserProfileCache: NSObject, NSCoding {
    let id: String?
    let avatarURL: String?
    let blockedBy: [String]?
    let blockedUsers: [String]?
    let currentLocation: String?
    let friendIDs: [String]?
    let hiddenUsers: [String]?
    let imageURL: String?
    let name: String?
    let pendingFriendRequests: [String]?
    let phone: String?
    let sentInvites: [String]?
    let spotScore: Int?
    let topFriends: [String: Int]?
    let userBio: String?
    let username: String?
    let profilePic: UIImage?
    let avatarPic: UIImage?
    let spotsList: [String]?
    let friendsList: [UserProfileCache]?
    let mutualFriendsScore: Int?
    let selected: Bool?
    let mapsList: [CustomMapCache]?
    let pending: Bool?
    let friend: Bool?
    let respondedToCampusMap: Bool?
    
    init(userProfile: UserProfile) {
        self.id = userProfile.id
        self.avatarURL = userProfile.avatarURL
        self.blockedBy = userProfile.blockedBy
        self.blockedUsers = userProfile.blockedUsers
        self.currentLocation = userProfile.currentLocation
        self.friendIDs = userProfile.friendIDs
        self.hiddenUsers = userProfile.hiddenUsers
        self.imageURL = userProfile.imageURL
        self.name = userProfile.name
        self.pendingFriendRequests = userProfile.pendingFriendRequests
        self.phone = userProfile.phone
        self.sentInvites = userProfile.sentInvites
        self.spotScore = userProfile.spotScore
        self.topFriends = userProfile.topFriends
        self.userBio = userProfile.userBio
        self.username = userProfile.username
        self.profilePic = userProfile.profilePic
        self.avatarPic = userProfile.avatarPic
        self.spotsList = userProfile.spotsList
        self.friendsList = userProfile.friendsList.map { UserProfileCache(userProfile: $0) }
        self.mutualFriendsScore = userProfile.mutualFriendsScore
        self.selected = userProfile.selected
        self.mapsList = userProfile.mapsList.map { CustomMapCache(customMap: $0) }
        self.pending = userProfile.pending
        self.friend = userProfile.friend
        self.respondedToCampusMap = userProfile.respondedToCampusMap
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(avatarURL, forKey: "avatarURL")
        coder.encode(blockedBy, forKey: "blockedBy")
        coder.encode(blockedUsers, forKey: "blockedUsers")
        coder.encode(currentLocation, forKey: "currentLocation")
        coder.encode(friendIDs, forKey: "friendIDs")
        coder.encode(hiddenUsers, forKey: "hiddenUsers")
        coder.encode(imageURL, forKey: "imageURL")
        coder.encode(name, forKey: "name")
        coder.encode(pendingFriendRequests, forKey: "pendingFriendRequests")
        coder.encode(phone, forKey: "phone")
        coder.encode(sentInvites, forKey: "sentInvites")
        coder.encode(spotScore, forKey: "spotScore")
        coder.encode(topFriends, forKey: "topFriends")
        coder.encode(userBio, forKey: "userBio")
        coder.encode(username, forKey: "username")
        coder.encode(profilePic, forKey: "profilePic")
        coder.encode(avatarPic, forKey: "avatarPic")
        coder.encode(spotsList, forKey: "spotsList")
        coder.encode(friendsList, forKey: "friendsList")
        coder.encode(mutualFriendsScore, forKey: "mutualFriendsScore")
        coder.encode(selected, forKey: "selected")
        coder.encode(mapsList, forKey: "mapsList")
        coder.encode(pending, forKey: "pending")
        coder.encode(friend, forKey: "friend")
        coder.encode(respondedToCampusMap, forKey: "respondedToCampusMap")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String
        self.avatarURL = coder.decodeObject(forKey: "avatarURL") as? String
        self.blockedBy = coder.decodeObject(forKey: "blockedBy") as? [String]
        self.blockedUsers = coder.decodeObject(forKey: "blockedUsers") as? [String]
        self.currentLocation = coder.decodeObject(forKey: "currentLocation") as? String
        self.friendIDs = coder.decodeObject(forKey: "friendIDs") as? [String]
        self.hiddenUsers = coder.decodeObject(forKey: "hiddenUsers") as? [String]
        self.imageURL = coder.decodeObject(forKey: "imageURL") as? String
        self.name = coder.decodeObject(forKey: "name") as? String
        self.pendingFriendRequests = coder.decodeObject(forKey: "pendingFriendRequests") as? [String]
        self.phone = coder.decodeObject(forKey: "phone") as? String
        self.sentInvites = coder.decodeObject(forKey: "sentInvites") as? [String]
        self.spotScore = coder.decodeInteger(forKey: "spotScore")
        self.topFriends = coder.decodeObject(forKey: "topFriends") as? [String: Int]
        self.userBio = coder.decodeObject(forKey: "userBio") as? String
        self.username = coder.decodeObject(forKey: "username") as? String
        self.profilePic = coder.decodeObject(forKey: "profilePic") as? UIImage
        self.avatarPic = coder.decodeObject(forKey: "avatarPic") as? UIImage
        self.spotsList = coder.decodeObject(forKey: "spotsList") as? [String]
        self.friendsList = coder.decodeObject(forKey: "friendsList") as? [UserProfileCache]
        self.mutualFriendsScore = coder.decodeInteger(forKey: "mutualFriendsScore")
        self.selected = coder.decodeBool(forKey: "selected")
        self.mapsList = coder.decodeObject(forKey: "mapsList") as? [CustomMapCache]
        self.pending = coder.decodeBool(forKey: "pending")
        self.friend = coder.decodeBool(forKey: "friend")
        self.respondedToCampusMap = coder.decodeBool(forKey: "respondedToCampusMap")
        
        super.init()
    }
}

extension UserProfileCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}
