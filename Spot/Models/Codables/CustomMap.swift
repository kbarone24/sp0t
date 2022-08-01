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
        case mapDescription
    }
}

struct MapPostGroup {
    var spotID: String?
    var postIDs: [(id: String, timestamp: Timestamp, seen: Bool)]
}
