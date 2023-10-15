//
//  CustomMap.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore
import Foundation
import MapKit
import UIKit

struct CustomMap: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var communityMap: Bool? = false
    var founderID: String
    var imageURL: String
    var lastPostTimestamp: Timestamp?
    var likers: [String]
    var lowercaseName: String?
    var mainCampusMap: Bool?
    var mapDescription: String?
    var mapName: String
    var memberIDs: [String]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postImageURLs: [String]
    var postCommentCounts: [Int]? = []
    var postLikeCounts: [Int]? = []
    var postLocations: [[String: Double]] = []
    var postSpotIDs: [String] = []
    var postTimestamps: [Timestamp] = []
    var searchKeywords: [String]? = []
    var secret: Bool
    var spotIDs: [String]
    var spotNames: [String] = []
    var spotLocations: [[String: Double]] = []
    var spotPOICategories: [String] = []

    var mapScore: Double? = 0
    var adjustedMapScore: Double = 0
    var boostMultiplier: Double? = 1.0

    var newMap = false
    var selected = false
    var memberProfiles: [UserProfile]? = []
    var coverImage: UIImage? = UIImage()

    var userTimestamp: Timestamp {
        if let lastUserPostIndex = posterIDs.lastIndex(where: { $0 == UserDataModel.shared.uid }) {
            return postTimestamps[safe: lastUserPostIndex] ?? postTimestamps.first ?? Timestamp()
        }
        return postTimestamps.first ?? postTimestamps.first ?? Timestamp()
    }

    var userURL: String {
        if let lastUserPostIndex = posterIDs.lastIndex(where: { $0 == UserDataModel.shared.uid }) {
            return postImageURLs[safe: lastUserPostIndex] ?? postImageURLs.first ?? ""
        }
        return postImageURLs.first ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case communityMap
        case founderID
        case imageURL
        case lastPostTimestamp
        case lowercaseName
        case likers
        case mainCampusMap
        case mapDescription
        case mapName
        case memberIDs
        case posterIDs
        case posterUsernames
        case postIDs
        case postImageURLs
        case postCommentCounts
        case postLikeCounts
        case postSpotIDs
        case postLocations
        case postTimestamps
        case searchKeywords
        case secret
        case spotIDs
        case spotNames
        case spotLocations
        case spotPOICategories
        case mapScore
        case boostMultiplier
    }

    init(id: String, mapName: String) {
        self.id = id
        self.mapName = mapName

        self.founderID = ""
        self.imageURL = ""
        self.likers = []
        self.memberIDs = []
        self.posterIDs = []
        self.posterUsernames = []
        self.postIDs = []
        self.postImageURLs = []
        self.postLocations = [[:]]
        self.postSpotIDs = []
        self.postTimestamps = []
        self.spotLocations = [[:]]
        self.spotPOICategories = []
        self.secret = false
        self.spotIDs = []
        self.spotNames = []
    }

    init(uid: String) {
        self.id = UUID().uuidString
        self.mapName = ""

        self.founderID = uid
        self.imageURL = ""
        self.likers = [uid]
        self.memberIDs = [uid]
        self.posterIDs = []
        self.posterUsernames = []
        self.postIDs = []
        self.postImageURLs = []
        self.postLocations = [[:]]
        self.postSpotIDs = []
        self.postTimestamps = []
        self.spotLocations = [[:]]
        self.spotPOICategories = []
        self.secret = false
        self.spotIDs = []
        self.spotNames = []

        self.coverImage = UIImage()
        self.memberProfiles = [UserDataModel.shared.userInfo]
    }

    mutating func updatePostLevelValues(post: Post?) {
        /// update post values on new post
        guard let postID = post?.id else { return }
        if !postIDs.contains(postID) {
            postIDs.append(postID)
            postCommentCounts?.append(0)
            postLikeCounts?.append(0)
            posterIDs.append(post?.posterID ?? "")
            posterUsernames.append(post?.userInfo?.username ?? "")
            postSpotIDs.append(post?.spotID ?? "")

            let timestamp = post?.timestamp ?? Timestamp()
            postTimestamps.append(timestamp)
            lastPostTimestamp = timestamp

            if !(post?.imageURLs.isEmpty ?? true) { postImageURLs.append(post?.imageURLs.first ?? "") }

            let postLocation = ["lat": post?.postLat ?? 0, "long": post?.postLong ?? 0]
            postLocations.append(postLocation)

            var posters = post?.taggedUsers ?? []
            posters.append(UserDataModel.shared.uid)
        }
    }

    mutating func updateSpotLevelValues(spot: Spot) {
        /// update spot values on new post
        if !spotIDs.contains(spot.id ?? "") {
            spotIDs.append(spot.id ?? "")
            spotNames.append(spot.spotName)
            spotLocations.append(["lat": spot.spotLat, "long": spot.spotLong])
            spotPOICategories.append(spot.poiCategory ?? "")
        }
    }

    mutating func setAdjustedMapScore() {
        var adjustedMapScore: CGFloat = 0
        // var adjustedMapScore = (mapScore ?? 1) / 4
        // boost for recent posts
        // measure posts based on total # likes + ratio of likes to views
        var postLevelScore: Double = 0
        var posters: [String] = []
        for i in postIDs.count - 6...postIDs.count - 1 {
            var newPosterBonus = false
            var post = Post(spotID: "", spotName: "", mapID: "", mapName: "")
            post.timestamp = postTimestamps[safe: i] ?? Timestamp(seconds: 0, nanoseconds: 0)

            // bonus for new poster
            let poster = posterIDs[safe: i] ?? ""
            newPosterBonus = !posters.contains(poster)
            posters.append(poster)

            post.posterID = posterIDs[safe: i] ?? ""
            var postScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, dislikeCount: 0, passedCommentCount: postCommentCounts?[safe: i] ?? 0, feedMode: false)
            if newPosterBonus { postScore *= 1.25 }
            postLevelScore += postScore
        }
        adjustedMapScore += postLevelScore
        let boost = boostMultiplier ?? 1
        adjustedMapScore *= boost
        self.adjustedMapScore = adjustedMapScore
    }
}
