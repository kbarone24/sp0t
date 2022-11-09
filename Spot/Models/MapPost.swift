//
//  MapPost.swift
//  Spot
//
//  Created by kbarone on 7/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFirestoreSwift
import Foundation
import UIKit

struct MapPost: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    var addedUsers: [String]? = []
    var aspectRatios: [CGFloat]? = []
    var caption: String
    var city: String? = ""
    var createdBy: String? = ""
    var commentCount: Int? = 0
    var frameIndexes: [Int]? = []
    var friendsList: [String]
    var hiddenBy: [String]? = []
    var hideFromFeed: Bool? = false
    var imageLocations: [[String: Double]]? = []
    var imageURLs: [String]
    var inviteList: [String]? = []
    var likers: [String]
    var mapID: String? = ""
    var mapName: String? = ""
    var postLat: Double
    var postLong: Double
    var posterID: String
    var posterUsername: String? = ""
    var privacyLevel: String? = "friends"
    var seenList: [String]? = []
    var spotID: String? = ""
    var spotLat: Double? = 0.0
    var spotLong: Double? = 0.0
    var spotName: String? = ""
    var spotPrivacy: String? = ""
    var tag: String? = ""
    var taggedUserIDs: [String]? = []
    var taggedUsers: [String]? = []
    var timestamp: Firebase.Timestamp

    // supplemental values
    var addedUserProfiles: [UserProfile]? = []
    var userInfo: UserProfile?
    var mapInfo: CustomMap?
    var commentList: [MapComment] = []
    var postImage: [UIImage] = []

    var postScore: Double? = 0
    var selectedImageIndex: Int? = 0
    var imageHeight: CGFloat? = 0
    var captionHeight: CGFloat? = 0
    var cellHeight: CGFloat? = 0
    var commentsHeight: CGFloat? = 0

    var setImageLocation = false

    var seen: Bool {
        let twoWeeks = Date().timeIntervalSince1970 - 86_400 * 14
        return (seenList?.contains(UserDataModel.shared.uid) ?? true) || timestamp.seconds < Int64(twoWeeks)
    }

    var seconds: Int64 {
        return timestamp.seconds
    }

    var coordinate: CLLocationCoordinate2D {
        return spotID ?? "" == "" ? CLLocationCoordinate2D(latitude: postLat, longitude: postLong) : CLLocationCoordinate2D(latitude: spotLat ?? postLat, longitude: spotLong ?? postLong)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case addedUsers
        case aspectRatios
        case caption
        case city
        case commentCount
        case createdBy
        case frameIndexes
        case friendsList
        case hiddenBy
        case hideFromFeed
        case imageLocations
        case imageURLs
        case inviteList
        case likers
        case mapID
        case mapName
        case postLat
        case postLong
        case posterID
        case posterUsername
        case privacyLevel
        case seenList
        case spotID
        case spotLat
        case spotLong
        case spotName
        case spotPrivacy
        case taggedUserIDs
        case taggedUsers
        case timestamp
    }

    init(
        id: String,
        posterID: String,
        postDraft: PostDraft,
        mapInfo: CustomMap?,
        actualTimestamp: Timestamp,
        uploadImages: [UIImage],
        imageURLs: [String],
        aspectRatios: [CGFloat],
        imageLocations: [[String: Double]] = [],
        likers: [String]
    ) {
        self.id = id
        self.addedUsers = postDraft.addedUsers
        self.aspectRatios = aspectRatios
        self.caption = postDraft.caption ?? ""
        self.city = postDraft.city
        self.createdBy = postDraft.createdBy
        self.frameIndexes = postDraft.frameIndexes
        self.friendsList = postDraft.friendsList ?? []
        self.hideFromFeed = postDraft.hideFromFeed
        self.imageLocations = imageLocations
        self.imageURLs = imageURLs
        self.inviteList = postDraft.inviteList ?? []
        self.likers = likers
        self.mapID = postDraft.mapID ?? ""
        self.mapName = postDraft.mapName ?? ""
        self.postLat = postDraft.postLat
        self.postLong = postDraft.postLong
        self.posterID = posterID
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.privacyLevel = postDraft.privacyLevel ?? ""
        self.seenList = []
        self.spotID = postDraft.spotID ?? ""
        self.spotLat = postDraft.spotLat
        self.spotLong = postDraft.spotLong
        self.spotName = postDraft.spotName
        self.spotPrivacy = postDraft.spotPrivacy
        self.tag = ""
        self.taggedUserIDs = postDraft.taggedUserIDs ?? []
        self.taggedUsers = postDraft.taggedUsers ?? []
        self.timestamp = actualTimestamp
        self.addedUserProfiles = []
        self.userInfo = UserDataModel.shared.userInfo
        self.mapInfo = mapInfo
        self.commentList = []
        self.postImage = uploadImages
        self.postScore = 0
        self.selectedImageIndex = 0
        self.imageHeight = 0
        self.captionHeight = 0
        self.cellHeight = 0
        self.commentsHeight = 0
    }

    init(spotID: String, spotName: String, mapID: String, mapName: String) {
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.id = UUID().uuidString
        self.spotID = spotID
        self.spotName = spotName
        self.mapID = mapID
        self.mapName = mapName
        self.caption = ""
        self.friendsList = []
        self.imageURLs = []
        self.likers = []
        self.postLat = 0
        self.postLong = 0
        self.timestamp = Timestamp(date: Date())
        self.mapInfo = nil
        self.commentList = []
        self.postImage = []
        self.postScore = 0
        self.selectedImageIndex = 0
        self.imageHeight = 0
        self.captionHeight = 0
        self.cellHeight = 0
        self.commentsHeight = 0
        self.posterID = ""
    }

    init(
        posterUsername: String,
        caption: String,
        privacyLevel: String,
        longitude: Double,
        latitude: Double,
        timestamp: Timestamp
    ) {
        self.id = UUID().uuidString
        self.posterUsername = posterUsername
        self.posterID = UserDataModel.shared.uid
        self.privacyLevel = privacyLevel
        self.postLat = latitude
        self.postLong = longitude
        self.timestamp = timestamp
        self.caption = caption
        self.likers = []
        self.imageURLs = []
        self.mapInfo = nil
        self.commentList = []
        self.postImage = []
        self.postScore = 0
        self.selectedImageIndex = 0
        self.imageHeight = 0
        self.captionHeight = 0
        self.cellHeight = 0
        self.commentsHeight = 0
        self.friendsList = []
    }
}
