//
//  CustomMap.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift
import MapKit

struct CustomMap: Identifiable, Codable {
    @DocumentID var id: String?
    
    var communityMap: Bool? = false
    var founderID: String
    var imageURL: String
    var likers: [String]
    var lowercaseName: String?
    var mapBio: String?
    var mapDescription: String?
    var mapName: String
    var memberIDs: [String]
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postImageURLs: [String]
    var postLocations: [[String: Double]] = []
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
        if let lastUserPostIndex = posterIDs.lastIndex(where: {$0 == UserDataModel.shared.uid}) {
            return postTimestamps[safe: lastUserPostIndex] ?? postTimestamps.first!
        }
        return postTimestamps.first!
    }
    
    var userURL: String {
        if let lastUserPostIndex = posterIDs.lastIndex(where: {$0 == UserDataModel.shared.uid}) {
            return postImageURLs[safe: lastUserPostIndex] ?? postImageURLs.first!
        }
        return postImageURLs.first!
    }
    
    var hasNewPost: Bool {
        return postsDictionary.contains(where: { !$0.value.seen} )
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case communityMap
        case founderID
        case imageURL
        case lowercaseName
        case likers
        case mapName
        case memberIDs
        case posterDictionary
        case posterIDs
        case posterUsernames
        case postIDs
        case postImageURLs
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
        if !post.seenList!.contains(uid) { post.seenList?.append(uid) }
        postsDictionary[postID] = post
        if let i = postGroup.firstIndex(where: {$0.postIDs.contains(where: {$0.id == postID})}) {
            if let j = postGroup[i].postIDs.firstIndex(where: {$0.id == postID}) {
                postGroup[i].postIDs[j].seen = true
                postGroup[i].sortPostIDs()
            }
        }
    }
    
    mutating func addSpotGroups() {
        /// append spots to show on map even if there's no post attached
        if !spotIDs.isEmpty {
            for i in 0...spotIDs.count - 1 {
                let coordinate = CLLocationCoordinate2D(latitude: spotLocations[safe: i]?["lat"] ?? 0.0, longitude: spotLocations[safe: i]?["long"] ?? 0.0)
                if !postGroup.contains(where: {$0.id == spotIDs[i]}) { postGroup.append(MapPostGroup(id: spotIDs[i], coordinate: coordinate, spotName: spotNames[safe: i] ?? "", postIDs: [])) }
            }
        }
    }
    
    mutating func updateGroup(post: MapPost) -> (group: MapPostGroup?, newGroup: Bool) {
        if post.spotID ?? "" == "" {
            /// attach by postID
            let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            let newGroup = MapPostGroup(id: post.id!, coordinate: coordinate, spotName: "", postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)])
            postGroup.append(newGroup)
            return (newGroup, true)
            
        } else if !postGroup.contains(where: {$0.id == post.spotID!}) {
            let coordinate = CLLocationCoordinate2D(latitude: post.spotLat!, longitude: post.spotLong!)
            let newGroup = MapPostGroup(id: post.spotID!, coordinate: coordinate, spotName: post.spotName!, postIDs: [(id: post.id!, timestamp: post.timestamp, seen: post.seen)])
            postGroup.append(newGroup)
            spotIDs.append(post.spotID!)
            spotLocations.append(["lat": post.spotLat ?? post.postLat, "long": post.spotLong ?? post.postLong])
            spotNames.append(post.spotName ?? "")
            return (newGroup, true)

        } else if let i = postGroup.firstIndex(where: {$0.id == post.spotID}) {
            if !postGroup[i].postIDs.contains(where: {$0.id == post.id}) {
                postGroup[i].postIDs.append((id: post.id!, timestamp: post.timestamp, seen: post.seen))
                postGroup[i].sortPostIDs()
                return (postGroup[i], false)
            }
        }
        return (nil, false)
    }
    
    mutating func createPosts(posts: [MapPost]) {
        for post in posts {
            postsDictionary.updateValue(post, forKey: post.id!)
            let _ = updateGroup(post: post)
        }
    }
    /// spotID == "" when not deleting spot
    mutating func removePost(postID: String, spotID: String) {
        /// remove from dictionary
        postsDictionary.removeValue(forKey: postID)
        /// remove id from post group
        if let i = postGroup.firstIndex(where: {$0.postIDs.contains(where: {$0.id == postID})}) {
            if let j = postGroup[i].postIDs.firstIndex(where: {$0.id == postID}) {
                postGroup[i].postIDs.remove(at: j)
                /// remove from post group entirely if no spot attached
                if postGroup[i].postIDs.count == 0 && postGroup[i].spotName == "" { postGroup.remove(at: i) }
            }
        }
        /// remove associated values
        posterDictionary.removeValue(forKey: postID)
        if let i = postIDs.firstIndex(where: {$0 == postID}) {
            posterIDs.remove(at: i)
            posterUsernames.remove(at: i)
            postIDs.remove(at: i)
            postImageURLs.remove(at: i)
            postLocations.remove(at: i)
         //   postTimestamps.remove(at: i)
        }
        if spotID != "" {
            if let i = spotIDs.firstIndex(where: {$0 == spotID}) {
                spotIDs.remove(at: i)
                spotNames.remove(at: i)
                spotLocations.remove(at: i)
            }
            postGroup.removeAll(where: {$0.id == spotID})
        }
    }
}

struct MapPostGroup {
    var id: String /// can be post or spotID
    var coordinate: CLLocationCoordinate2D
    var spotName: String
    var postIDs: [(id: String, timestamp: Timestamp, seen: Bool)]
    
    mutating func sortPostIDs() {
        postIDs = postIDs.sorted(by: { p1, p2 in
            guard p1.seen == p2.seen else {
                return !p1.seen && p2.seen
            }
            return p1.timestamp.seconds > p2.timestamp.seconds
        })
    }
}
