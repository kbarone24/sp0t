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
import FirebaseFirestore
import UIKit

struct MapPost: Identifiable, Codable {
    typealias Section = MapPostImageCell.Section
    typealias Item = MapPostImageCell.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    @DocumentID var id: String?
    var addedUsers: [String]? = []
    var aspectRatios: [CGFloat]? = []
    var boostMultiplier: Double? = 1.0
    var caption: String
    var city: String? = ""
    var createdBy: String? = ""
    var commentCount: Int? = 0
    var frameIndexes: [Int]? = []
    var friendsList: [String]
    var g: String?
    var hiddenBy: [String]? = []
    var hideFromFeed: Bool? = false
    var imageLocations: [[String: Double]]? = []
    var imageURLs: [String]
    var videoURL: String?
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
    var spotPOICategory: String?
    var spotPrivacy: String? = ""
    var tag: String? = ""
    var taggedUserIDs: [String]? = []
    var taggedUsers: [String]? = []
    var timestamp: Timestamp

    // supplemental values
    var addedUserProfiles: [UserProfile]? = []
    var userInfo: UserProfile?
    var mapInfo: CustomMap?
    var commentList: [MapComment] = []
    var postImage: [UIImage] = []
    var postVideo: Data?
    var videoLocalPath: URL?

    var postScore: Double? = 0
    var selectedImageIndex: Int? = 0
    var imageHeight: CGFloat? = 0
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
    
    var imageCollectionSnapshot: Snapshot?

    enum CodingKeys: String, CodingKey {
        case id
        case addedUsers
        case aspectRatios
        case boostMultiplier
        case caption
        case city
        case commentCount
        case createdBy
        case frameIndexes
        case friendsList
        case g
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
        case spotPOICategory
        case spotPrivacy
        case taggedUserIDs
        case taggedUsers
        case timestamp
        case videoURL
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
        self.spotPOICategory = postDraft.poiCategory
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
        self.cellHeight = 0
        self.commentsHeight = 0
        generateSnapshot()
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
        self.cellHeight = 0
        self.commentsHeight = 0
        self.posterID = ""
        generateSnapshot()
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
        self.cellHeight = 0
        self.commentsHeight = 0
        self.friendsList = []
        generateSnapshot()
    }
}

extension MapPost {
    func getNearbyPostScore() -> Double {
        let postScore = getBasePostScore(likeCount: nil, seenCount: nil, commentCount: nil)

        let distance = max(CLLocation(latitude: postLat, longitude: postLong).distance(from: UserDataModel.shared.currentLocation), 1)
        let distanceScore = min(pow(distance / 100, 1.05), 100)

        let boost = max(boostMultiplier ?? 1, 0.1)
        let finalScore = (postScore + distanceScore) * boost
        return finalScore
    }

    func getBasePostScore(likeCount: Int?, seenCount: Int?, commentCount: Int?) -> Double {
        let nearbyPostMode = likeCount == nil
        var postScore: Double = 10
        let postTime = Double(timestamp.seconds)

        // will only increment when called from nearby feed
        if nearbyPostMode {
            postScore += !seen ? 50 : 0
            if UserDataModel.shared.userInfo.friendIDs.contains(where: { $0 == posterID }) {
                postScore += 10
            }
        }

        let seenCount = nearbyPostMode ? Double(seenList?.filter({ $0 != posterID }).count ?? 0) : Double(seenCount ?? 0)
        let likeCount = nearbyPostMode ? Double(likers.filter({ $0 != posterID }).count) : Double(likeCount ?? 0)
        let commentCount = nearbyPostMode ? Double(commentList.count) : Double(commentCount ?? 0)

        postScore += likeCount * 10
        postScore += commentCount * 5
        postScore += likeCount > 2 ? 30 : 0

        let current = Date().timeIntervalSince1970
        let currentTime = Double(current)
        let timeSincePost = currentTime - postTime

        // add multiplier for recency -> heavier weighted for nearby posts
        let maxFactor: Double = nearbyPostMode ? 40 : 15
        let factor = min(1 + (1_000_000 / timeSincePost), maxFactor)
        let timeScore = pow(1.25, factor)
        postScore += timeScore * 5

        // multiply by ratio of likes / people who have seen it. Meant to give new posts with a couple likes a boost
        postScore *= (1 + Double(likeCount / max(seenCount, 1)) * 3)
        return postScore
    }
}

extension [MapPost] {
    // call to always have opened post be first in content viewer
    mutating func sortPostsOnOpen(index: Int) {
        var i = 0
        while i < index {
            let element = remove(at: 0)
            append(element)
            i += 1
        }
    }
}

extension MapPost: Hashable {
    static func == (lhs: MapPost, rhs: MapPost) -> Bool {
        return lhs.id == rhs.id &&
        lhs.addedUsers == rhs.addedUsers &&
        lhs.aspectRatios == rhs.aspectRatios &&
        lhs.caption == rhs.caption &&
        lhs.city == rhs.city &&
        lhs.createdBy == rhs.createdBy &&
        lhs.commentCount == rhs.commentCount &&
        lhs.frameIndexes == rhs.frameIndexes &&
        lhs.friendsList == rhs.friendsList &&
        lhs.g == rhs.g &&
        lhs.hiddenBy == rhs.hiddenBy &&
        lhs.hideFromFeed == rhs.hideFromFeed &&
        lhs.imageLocations == rhs.imageLocations &&
        lhs.imageURLs == rhs.imageURLs &&
        lhs.videoURL == rhs.videoURL &&
        lhs.inviteList == rhs.inviteList &&
        lhs.likers == rhs.likers &&
        lhs.mapID == rhs.mapID &&
        lhs.mapName == rhs.mapName &&
        lhs.postLat == rhs.postLat &&
        lhs.postLong == rhs.postLong &&
        lhs.posterID == rhs.posterID &&
        lhs.posterUsername == rhs.posterUsername &&
        lhs.privacyLevel == rhs.privacyLevel &&
        lhs.seenList == rhs.seenList &&
        lhs.spotID == rhs.spotID &&
        lhs.spotLat == rhs.spotLat &&
        lhs.spotLong == rhs.spotLong &&
        lhs.spotName == rhs.spotName &&
        lhs.spotPOICategory == rhs.spotPOICategory &&
        lhs.spotPrivacy == rhs.spotPrivacy &&
        lhs.tag == rhs.tag &&
        lhs.taggedUserIDs == rhs.taggedUserIDs &&
        lhs.taggedUsers == rhs.taggedUsers &&
        lhs.timestamp == rhs.timestamp &&
        lhs.addedUserProfiles == rhs.addedUserProfiles &&
        lhs.userInfo == rhs.userInfo &&
        lhs.mapInfo == rhs.mapInfo &&
        lhs.commentList == rhs.commentList &&
        lhs.postImage == rhs.postImage &&
        lhs.postVideo == rhs.postVideo &&
        lhs.videoLocalPath == rhs.videoLocalPath &&
        lhs.postScore == rhs.postScore &&
        lhs.selectedImageIndex == rhs.selectedImageIndex &&
        lhs.imageHeight == rhs.imageHeight &&
        lhs.cellHeight == rhs.cellHeight &&
        lhs.commentsHeight == rhs.commentsHeight &&
        lhs.setImageLocation == rhs.setImageLocation
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(addedUsers)
        hasher.combine(aspectRatios)
        hasher.combine(caption)
        hasher.combine(city)
        hasher.combine(createdBy)
        hasher.combine(commentCount)
        hasher.combine(frameIndexes)
        hasher.combine(friendsList)
        hasher.combine(g)
        hasher.combine(hiddenBy)
        hasher.combine(hideFromFeed)
        hasher.combine(imageLocations)
        hasher.combine(imageURLs)
        hasher.combine(videoURL)
        hasher.combine(inviteList)
        hasher.combine(likers)
        hasher.combine(mapID)
        hasher.combine(mapName)
        hasher.combine(postLat)
        hasher.combine(postLong)
        hasher.combine(posterID)
        hasher.combine(posterUsername)
        hasher.combine(privacyLevel)
        hasher.combine(seenList)
        hasher.combine(spotID)
        hasher.combine(spotLat)
        hasher.combine(spotLong)
        hasher.combine(spotName)
        hasher.combine(spotPOICategory)
        hasher.combine(spotPrivacy)
        hasher.combine(tag)
        hasher.combine(taggedUserIDs)
        hasher.combine(taggedUsers)
        hasher.combine(timestamp)
        hasher.combine(addedUserProfiles)
        hasher.combine(userInfo)
        hasher.combine(mapInfo)
        hasher.combine(commentList)
        hasher.combine(postImage)
        hasher.combine(postVideo)
        hasher.combine(videoLocalPath)
        hasher.combine(postScore)
        hasher.combine(selectedImageIndex)
        hasher.combine(imageHeight)
        hasher.combine(cellHeight)
        hasher.combine(commentsHeight)
        hasher.combine(setImageLocation)
    }
}

extension MapPost {
    init(mapPost: MapPostCache) {
        self.id = mapPost.id
        self.addedUsers = mapPost.addedUsers
        self.aspectRatios = mapPost.aspectRatios?.map { CGFloat($0) }
        self.caption = mapPost.caption
        self.city = mapPost.city
        self.createdBy = mapPost.createdBy
        self.commentCount = mapPost.commentCount
        self.frameIndexes = mapPost.frameIndexes
        self.friendsList = mapPost.friendsList
        self.g = mapPost.g
        self.hiddenBy = mapPost.hiddenBy
        self.hideFromFeed = mapPost.hideFromFeed
        self.imageLocations = mapPost.imageLocations
        self.imageURLs = mapPost.imageURLs
        self.videoURL = mapPost.videoURL
        self.inviteList = mapPost.inviteList
        self.likers = mapPost.likers
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.postLat = mapPost.postLat
        self.postLong = mapPost.postLong
        self.posterID = mapPost.posterID
        self.posterUsername = mapPost.posterUsername
        self.privacyLevel = mapPost.privacyLevel
        self.seenList = mapPost.seenList
        self.spotID = mapPost.spotID
        self.spotLat = mapPost.spotLat
        self.spotLong = mapPost.spotLong
        self.spotName = mapPost.spotName
        self.spotPOICategory = mapPost.spotPOICategory
        self.spotPrivacy = mapPost.spotPrivacy
        self.tag = mapPost.tag
        self.taggedUserIDs = mapPost.taggedUserIDs
        self.taggedUsers = mapPost.taggedUsers
        self.timestamp = mapPost.timestamp
        self.addedUserProfiles = mapPost.addedUserProfiles?.map { UserProfile(from: $0) } ?? []
        
        if let userInfo = mapPost.userInfo {
            self.userInfo = UserProfile(from: userInfo)
        } else {
            self.userInfo = nil
        }
        
        if let mapInfo = mapPost.mapInfo {
            self.mapInfo = CustomMap(customMap: mapInfo)
        } else {
            self.mapInfo = nil
        }
        
        self.commentList = mapPost.commentList.map { MapComment(mapComment: $0) }
        self.postImage = mapPost.postImage
        self.postVideo = mapPost.postVideo
        self.videoLocalPath = mapPost.videoLocalPath
        self.postScore = mapPost.postScore
        self.selectedImageIndex = mapPost.selectedImageIndex
        self.imageHeight = CGFloat(mapPost.imageHeight ?? 0.0)
        self.cellHeight = CGFloat(mapPost.cellHeight ?? 0.0)
        self.commentsHeight = CGFloat(mapPost.commentsHeight ?? 0.0)
        self.setImageLocation = mapPost.setImageLocation
        generateSnapshot()
    }
}

extension MapPost {
    mutating func generateSnapshot() {
        var snapshot = Snapshot()
        var appendedImageURLs: Set<String> = []
        snapshot.appendSections([.main])
        
        if let frameIndexes = frameIndexes {
            for (index, imageURL) in imageURLs.enumerated() {
                let gifURLs = getGifImageURLs(imageURLs: imageURLs, frameIndexes: frameIndexes, imageIndex: index)
                
                if !gifURLs.isEmpty {
                    snapshot.appendItems(
                        [
                            .item(gifURLs.filter { !appendedImageURLs.contains($0) })
                        ]
                    )
                    _ = gifURLs.map {
                        appendedImageURLs.insert($0)
                    }
                } else {
                    if !appendedImageURLs.contains(imageURL) {
                        snapshot.appendItems([.item([imageURL])])
                        appendedImageURLs.insert(imageURL)
                    }
                }
            }
        } else {
            _ = imageURLs.map {
                snapshot.appendItems([.item([$0])])
            }
        }
        
        self.imageCollectionSnapshot = snapshot
    }
    
    private func getGifImageURLs(imageURLs: [String], frameIndexes: [Int], imageIndex: Int) -> [String] {
        /// return empty set of images if there's only one image for this frame index (still image), return all images at this frame index if there's more than 1 image
        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }
        guard let selectedImage = imageURLs[safe: selectedFrame] else { return [] }

        if frameIndexes.count == 1 {
            return imageURLs.count > 1 ? imageURLs : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImage != imageURLs.last ? imageURLs.suffix(imageURLs.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(imageURLs[selectedFrame...frame1 - 1]) : []
        }
    }
}
