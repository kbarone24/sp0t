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
    var mapName: String
    var memberIDs: [String]
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String]
    var posterUsernames: [String]
    var postIDs: [String]
    var postLocations: [[String: Double]] = [[:]]
    var postTimestamps: [Firebase.Timestamp] = []
    var secret: Bool
    var spotIDs: [String]
    var userTimestamp: Timestamp? /// != nil when fetched from user's profile
    var userURL: String? /// != nil when fetched from user's profile
    
    var memberProfiles: [UserProfile]? = []
    var coverImage: UIImage? = UIImage()
    
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
        case postLocations
        case postTimestamps
        case secret
        case spotIDs
        case userTimestamp
        case userURL
    }
}
