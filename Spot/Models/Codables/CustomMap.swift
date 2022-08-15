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
    
    var founderID: String
    var imageURL: String
    var likers: [String]
    var mapBio: String?
    var mapName: String
    var memberIDs: [String]
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postImageURLs: [String]
    var postLocations: [[String: Double]] = [[:]]
    var postTimestamps: [Firebase.Timestamp] = []
    var secret: Bool
    var spotIDs: [String]
    var spotNames: [String] = []
    var spotLocations: [[String: Double]] = [[:]]
    var mapDescription: String?
    
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
        case founderID
        case imageURL
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
}

struct MapPostGroup {
    var id: String /// can be post or spotID
    var coordinate: CLLocationCoordinate2D
    var spotName: String
    var postIDs: [(id: String, timestamp: Timestamp, seen: Bool)]
    
    mutating func sortPostIDs() {
        postIDs = postIDs.sorted(by: { p1, p2 in
            guard p1.seen == p2.seen else {
                return p1.seen && !p2.seen
            }
            
            return p1.timestamp.seconds > p2.timestamp.seconds
        })
    }
}
