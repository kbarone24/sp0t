//
//  CustomMap.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import MapKit
import UIKit

struct CustomMap: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var communityMap: Bool? = false
    var founderID: String
    var imageURL: String
    var likers: [String]
    var lowercaseName: String?
    var mainCampusMap: Bool? = false
    var mapDescription: String?
    var mapName: String
    var memberIDs: [String]
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postImageURLs: [String]
    var postLocations: [[String: Double]] = []
    var postSpotIDs: [String] = []
    var postTimestamps: [Firebase.Timestamp] = []
    var searchKeywords: [String]? = []
    var secret: Bool
    var spotIDs: [String]
    var spotNames: [String] = []
    var spotLocations: [[String: Double]] = []

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
        case postSpotIDs
        case postLocations
        case postTimestamps
        case searchKeywords
        case secret
        case spotIDs
        case spotNames
        case spotLocations
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
                let mapPostGroup = MapPostGroup(
                    id: spotIDs[i],
                    coordinate: coordinate,
                    spotName: spotNames[safe: i] ?? "",
                    postIDs: [],
                    postsToSpot: postsToSpot,
                    postTimestamps: postSpotTimestamps,
                    numberOfPosters: postersAtSpot.count
                )
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
            posterIDs.remove(at: i)
            posterUsernames.remove(at: i)
            postIDs.remove(at: i)
            postImageURLs.remove(at: i)
            postLocations.remove(at: i)
            postTimestamps.remove(at: i)
            postSpotIDs.remove(at: i)
        }
        if spotID != "" {
            if let i = spotIDs.firstIndex(where: { $0 == spotID }) {
                spotIDs.remove(at: i)
                spotNames.remove(at: i)
                spotLocations.remove(at: i)
            }
            postGroup.removeAll(where: { $0.id == spotID })
        }
    }
}
