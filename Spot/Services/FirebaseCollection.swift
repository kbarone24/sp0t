//
//  FirebaseCollection.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

enum FirebaseCollectionNames: String {
    case maps
    case posts
    case tags
    case users
    case spots
    case submissions
    case notifications
    case mapLocations
    case usernames
}

enum FireBaseCollectionFields: String {
    case communityMap
    case friendsList
    case posterID
    case mapID
    case timestamp
    case likers
    case memberIDs
    case hideFromFeed
    case inviteList
    case privacyLevel
    case topFriends
    case notifications
    case status
    case senderID
    case senderUsername
    case username
    case seen
    case type
    case comments
    case pendingFriendRequests
    case friendIDs
    case imageURLs
    case mapMembers
    case mapName
    case postID
    case posterUsername
    case spotID
    case spotName
    case spotVisitors
    case taggedUserIDs
    case posterUsernames
    case usernameKeywords
}

enum FuctionsHttpsCall: String {
    case sendPostNotification
}
