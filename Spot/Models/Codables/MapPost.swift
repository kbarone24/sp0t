//
//  MapPost.swift
//  Spot
//
//  Created by kbarone on 7/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift
import CoreLocation

struct MapPost: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    var addedUsers: [String]? = []
    var aspectRatios: [CGFloat]? = []
    var caption: String
    var city: String? = ""
    var createdBy: String? = ""
    var frameIndexes: [Int]? = []
    var friendsList: [String]
    var hideFromFeed: Bool? = false
    var imageLocations: [[String: Double]]? = [[:]]
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
    var seconds: Int64? = 0
    var selectedImageIndex: Int? = 0
    var imageHeight: CGFloat? = 0
    var captionHeight: CGFloat? = 0
    var cellHeight: CGFloat? = 0
    var commentsHeight: CGFloat? = 0
    
    var seen: Bool? = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case addedUsers
        case aspectRatios
        case caption
        case city
        case createdBy
        case frameIndexes
        case friendsList
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
}
