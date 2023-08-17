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
    case notifications
    case comments
    case usernames
    case feedback
}

enum PostCollectionFields: String {
    case id
    case aspectRatios
    case boostMultiplier
    case caption
    case city
    case commentCount
    case createdBy
    case dislikers
    case friendsList
    case g
    case hiddenBy
    case hideFromFeed
    case imageURLs
    case inviteList
    case likers
    case postLat
    case postLong
    case posterID
    case posterUsername
    case privacyLevel
    case reportedBy
    case seenList
    case spotID
    case spotLat
    case spotLong
    case spotName
    case spotPOICategory
    case spotPrivacy
    case taggedUserIDs
    case taggedUsers
    case timestamp
    case videoURL

    case commentIDs
    case commentLikeCounts
    case commentDislikeCounts
    case commentTimestamps
    case commentPosterIDs
    case commentReplyToIDs
}

enum SpotCollectionFields: String {
    case id
    case city
    case founderID = "createdBy"
    case g
    case imageURL
    case inviteList
    case lowercaseName
    case phone
    case poiCategory
    case postIDs
    case postMapIDs
    case postPrivacies
    case postTimestamps
    case posterDictionary
    case posterIDs
    case posterUsername
    case privacyLevel
    case searchKeywords
    case spotDescription = "description"
    case spotLat
    case spotLong
    case spotName
    case visitorList

    case hereNow
    case lastPostTimestamp
    case postCaptions
    case postImageURLs
    case postVideoURLs
    case postCommentCounts
    case postLikeCounts
    case postDislikeCounts
    case postSeenCounts
    case postUsernames
    case seenList
}

enum UserCollectionFields: String {
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
    case newAvatarNoti
    case pendingFriendRequests
    case phone
    case sentInvites
    case spotScore
    case topFriends
    case userBio
    case username
    case spotsList
    case postCount
    case usernameKeywords
}

enum NotificationCollectionFields: String {
    case seen
    case senderID
    case timestamp
    case type
    case mapID
    case mapName
    case spotID
    case commentID
    case imageURL
    case originalPoster
    case postID
    case senderUsername
    case status
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

enum NotificationType: String {
    case like
    case comment
    case friendRequest
    case commentTag
    case commentLike
    case commentComment
    case commentOnAdd
    case likeOnAdd
    case mapInvite
    case mapPost
    case post
    case postAdd
    case postTag
    case publicSpotAccepted
    case mapJoin
    case mapFollow
    case contactJoin
}

enum NotificationStatus: String {
    case accepted
    case pending
}

enum FuctionsHttpsCall: String {
    case sendPostNotification
}
