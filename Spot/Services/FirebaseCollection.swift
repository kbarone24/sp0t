//
//  FirebaseCollection.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

enum FirebaseStorageFolder {
    case videos
    case pictures
    
    var reference: String {
        switch self {
        case .videos: return "spotVideos"
        case .pictures: return "spotPics-dev"
        }
    }
}

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
    case comments
}

enum FirebaseCollectionFields: String {
    case communityMap
    case friendsList
    case posterID
    case mapID
    case timestamp
    case likers
    case seenList
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
    case city
    case secret
    case dislikers
}

enum FuctionsHttpsCall: String {
    case sendPostNotification
}
