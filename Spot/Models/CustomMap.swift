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
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postImageURLs: [String]
    var postCommentCounts: [Int]? = []
    var postLikeCounts: [Int]? = []
    var postSeenCounts: [Int]? = []
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
    var boostMultiplier: Double? = 0

    var selected = false
    var memberProfiles: [UserProfile]? = []
    var coverImage: UIImage? = UIImage()

    var postsDictionary = [String: MapPost]()
    var postGroup: [MapPostGroup] = []

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

    var hasNewPost: Bool {
        return postsDictionary.contains(where: { !$0.value.seen })
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
        case posterDictionary
        case posterIDs
        case posterUsernames
        case postIDs
        case postImageURLs
        case postCommentCounts
        case postLikeCounts
        case postSeenCounts
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

    mutating func updateSeen(postID: String) {
        guard var post = postsDictionary[postID] else { return }
        let uid = UserDataModel.shared.uid
        if !(post.seenList?.contains(uid) ?? false) { post.seenList?.append(uid) }
        postsDictionary[postID] = post
        if let i = postGroup.firstIndex(where: { $0.postIDs.contains(where: { $0.id == postID }) }) {
            if let j = postGroup[i].postIDs.firstIndex(where: { $0.id == postID }) {
                postGroup[i].postIDs[j].seen = true
                postGroup[i].sortPostIDs()
            }
        }
    }
    
    mutating func addSpotGroups() {
        // append spots to show on map even if there's no post attached
        for i in 0..<spotIDs.count {
            var postsToSpot: [String] = []
            var postSpotTimestamps: [Timestamp] = []
            var postersAtSpot: [String] = []
            /// get  postSpotIDs and matching timestamps
            for j in 0..<postSpotIDs.count where postSpotIDs[j] == spotIDs[i] {
                postsToSpot.append(postSpotIDs[j])
                postSpotTimestamps.append(postTimestamps[safe: j] ?? Timestamp(seconds: 1, nanoseconds: 1))
                if !postersAtSpot.contains(posterIDs[safe: j] ?? "") { postersAtSpot.append(posterIDs[safe: j] ?? "")
                }
            }
            
            let coordinate = CLLocationCoordinate2D(
                latitude: spotLocations[safe: i]?["lat"] ?? 0.0,
                longitude: spotLocations[safe: i]?["long"] ?? 0.0
            )
            
            if !postGroup.contains(where: { $0.id == spotIDs[i] }) {
                var mapPostGroup = MapPostGroup(
                    id: spotIDs[i],
                    coordinate: coordinate,
                    spotName: spotNames[safe: i] ?? "",
                    postIDs: [],
                    postsToSpot: postsToSpot,
                    postTimestamps: postSpotTimestamps,
                    numberOfPosters: postersAtSpot.count
                )
                if let poiCategory = POICategory(rawValue: spotPOICategories[safe: i] ?? "") {
                    mapPostGroup.poiCategory = poiCategory
                }
                postGroup.append(mapPostGroup)
            }
        }
    }
    
    mutating func updateGroup(post: MapPost) -> (group: MapPostGroup?, newGroup: Bool) {
        if let spotID = post.spotID, spotID == "", let id = post.id {
            /// attach by postID
            let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            let newGroup = MapPostGroup(
                id: id,
                coordinate: coordinate,
                spotName: "",
                postIDs: [
                    MapPostGroup.PostID(
                        id: id,
                        timestamp: post.timestamp,
                        seen: post.seen
                    )
                ]
            )

            postGroup.append(newGroup)
            return (newGroup, true)

        } else if let spotID = post.spotID,
                  let id = post.id,
                  let spotName = post.spotName,
                  !postGroup.contains(where: { $0.id == spotID }),
                  let spotLatitude = post.spotLat,
                  let spotLongitude = post.spotLong {

            let coordinate = CLLocationCoordinate2D(
                latitude: spotLatitude,
                longitude: spotLongitude
            )
            let newGroup = MapPostGroup(
                id: spotID,
                coordinate: coordinate,
                spotName: spotName,
                postIDs: [
                    MapPostGroup.PostID(
                        id: id,
                        timestamp: post.timestamp,
                        seen: post.seen
                    )
                ]
            )

            postGroup.append(newGroup)
            spotIDs.append(spotID)

            spotLocations.append(
                [
                    "lat": spotLatitude,
                    "long": spotLongitude
                ]
            )
            spotNames.append(spotName)
            return (newGroup, true)

        } else if let i = postGroup.firstIndex(where: { $0.id == post.spotID }),
                  let id = post.id,
                  !postGroup[i].postIDs.contains(where: { $0.id == post.id }) {

            let group = MapPostGroup.PostID(
                id: id,
                timestamp: post.timestamp,
                seen: post.seen
            )

            postGroup[i].postIDs.append(group)
            postGroup[i].sortPostIDs()
            return (postGroup[i], false)
        }

        return (nil, false)
    }

    mutating func updatePostLevelValues(post: MapPost?) {
        /// update post values on new post
        guard let postID = post?.id else { return }
        if !postIDs.contains(postID) {
            postIDs.append(postID)
            postCommentCounts?.append(0)
            postLikeCounts?.append(0)
            postSeenCounts?.append(0)
            posterIDs.append(post?.posterID ?? "")
            posterUsernames.append(post?.userInfo?.username ?? "")
            postTimestamps.append(post?.timestamp ?? Timestamp())
            postSpotIDs.append(post?.spotID ?? "")

            if !(post?.imageURLs.isEmpty ?? true) { postImageURLs.append(post?.imageURLs.first ?? "") }

            let postLocation = ["lat": post?.postLat ?? 0, "long": post?.postLong ?? 0]
            postLocations.append(postLocation)

            var posters = post?.addedUsers ?? []
            posters.append(UserDataModel.shared.uid)
            posterDictionary[postID] = posters
        }
    }

    mutating func updateSpotLevelValues(spot: MapSpot) {
        /// update spot values on new post
        if !spotIDs.contains(spot.id ?? "") {
            spotIDs.append(spot.id ?? "")
            spotNames.append(spot.spotName)
            spotLocations.append(["lat": spot.spotLat, "long": spot.spotLong])
            spotPOICategories.append(spot.poiCategory ?? "")
        }
    }

    mutating func createPosts(posts: [MapPost]) {
        for post in posts {
            postsDictionary.updateValue(post, forKey: post.id ?? "")
            _ = updateGroup(post: post)
        }
    }
    /// spotID == "" when not deleting spot
    mutating func removePost(postID: String, spotID: String) {
        /// remove from dictionary
        postsDictionary.removeValue(forKey: postID)
        /// remove id from post group
        if let i = postGroup.firstIndex(where: { $0.postIDs.contains(where: { $0.id == postID }) }) {
            if let j = postGroup[i].postIDs.firstIndex(where: { $0.id == postID }) {
                postGroup[i].postIDs.remove(at: j)
                /// remove from post group entirely if no spot attached
                if postGroup[i].postIDs.isEmpty && postGroup[i].spotName == "" { postGroup.remove(at: i) }
            }
        }
        /// remove associated values
        posterDictionary.removeValue(forKey: postID)
        if let i = postIDs.firstIndex(where: { $0 == postID }) {
            // check to make sure all of these values were consistently updated along postIDs
            if posterIDs.count == postIDs.count { posterIDs.remove(at: i) }
            if posterUsernames.count == postIDs.count { posterUsernames.remove(at: i) }
            if postImageURLs.count == postIDs.count { postImageURLs.remove(at: i) }
            if postLocations.count == postIDs.count { postLocations.remove(at: i) }
            if postSpotIDs.count == postIDs.count { postSpotIDs.remove(at: i) }
            if postTimestamps.count == postIDs.count { postTimestamps.remove(at: i) }
            postIDs.remove(at: i)
        }
        if spotID != "" {
            if let i = spotIDs.firstIndex(where: { $0 == spotID }) {
                // check to make sure all of these values were consistently updated along spotIDs
                // crash was happening due to poi categories not existing on old maps
                if spotNames.count == spotIDs.count { spotNames.remove(at: i) }
                if spotLocations.count == spotIDs.count { spotLocations.remove(at: i) }
                if spotPOICategories.count == spotIDs.count { spotPOICategories.remove(at: i)
                }
                spotIDs.remove(at: i)
            }
            postGroup.removeAll(where: { $0.id == spotID })
        }
    }

    mutating func setAdjustedMapScore() {
        var adjustedMapScore = mapScore ?? 0
        // mapScore should be about 1/2 of the maps total ranking
        // boost for recent posts
        // measure posts based on total # likes + ratio of likes to views
        // boostMap god mode feature should have the ability to shoot a map to the top
        var postLevelScore: Double = 0
        var posters: [String] = []
        for i in postIDs.count - 10...postIDs.count - 1 {
            var newPosterBonus = false
            var post = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            post.timestamp = postTimestamps[safe: i] ?? Timestamp(seconds: 0, nanoseconds: 0)

            let seenCount = postSeenCounts?[safe: i] ?? 10

            // bonus for new poster
            let poster = posterIDs[safe: i] ?? ""
            newPosterBonus = !posters.contains(poster)
            posters.append(poster)

            post.posterID = posterIDs[safe: i] ?? ""
            var postScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, seenCount: seenCount, commentCount: postCommentCounts?[safe: i] ?? 0)
            if newPosterBonus { postScore *= 1.25 }
            postLevelScore += postScore
        }
        adjustedMapScore += postLevelScore
        let boost = boostMultiplier ?? 1
        adjustedMapScore *= boost
        self.adjustedMapScore = adjustedMapScore
    }
}

extension CustomMap {
    init(customMap: CustomMapCache) {
        self.id = customMap.id
        self.communityMap = customMap.communityMap
        self.founderID = customMap.founderID
        self.imageURL = customMap.imageURL
        self.likers = customMap.likers
        self.lowercaseName = customMap.lowercaseName
        self.mainCampusMap = customMap.mainCampusMap
        self.mapDescription = customMap.mapDescription
        self.mapName = customMap.mapName
        self.memberIDs = customMap.memberIDs
        self.posterDictionary = customMap.posterDictionary
        self.posterIDs = customMap.postIDs
        self.posterUsernames = customMap.posterUsernames
        self.postIDs = customMap.postIDs
        self.postImageURLs = customMap.postImageURLs
        self.postLocations = customMap.postLocations
        self.postSpotIDs = customMap.postSpotIDs
        self.postTimestamps = customMap.postTimestamps
        self.searchKeywords = customMap.searchKeywords
        self.secret = customMap.secret
        self.spotIDs = customMap.spotIDs
        self.spotNames = customMap.spotNames
        self.spotLocations = customMap.spotLocations
        self.spotPOICategories = customMap.spotPOICategories
        self.selected = customMap.selected
        self.memberProfiles = customMap.memberProfiles?.map { UserProfile(from: $0) }
        self.coverImage = customMap.coverImage
        self.postsDictionary = customMap.postsDictionary.mapValues { MapPost(mapPost: $0) }
        self.postGroup = customMap.postGroup.map { MapPostGroup(group: $0) }
    }
}
