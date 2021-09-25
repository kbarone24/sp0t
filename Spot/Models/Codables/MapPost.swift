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

struct MapPost: Identifiable, Codable {
    
    @DocumentID var id: String?
    var caption: String
    var postLat: Double
    var postLong: Double
    var posterID: String
    var timestamp: Firebase.Timestamp
    var actualTimestamp: Firebase.Timestamp? 
    var userInfo: UserProfile!
    var spotID: String? = ""
    var city: String? = ""
    var frameIndexes: [Int]? = []
    var aspectRatios: [CGFloat]? = []
    
    var imageURLs: [String] = []
    var postImage: [UIImage] = []
    var seconds: Int64 = 0
    var selectedImageIndex = 0
    var postScore: Double = 0
    var commentList: [MapComment] = []
    var likers: [String]
    var taggedUsers: [String]? = []
    
    var captionHeight: CGFloat = 0
    var imageHeight: CGFloat = 0
    var cellHeight: CGFloat = 0
    
    var spotName: String? = ""
    var spotLat: Double? = 0.0
    var spotLong: Double? = 0.0
    var privacyLevel: String? = "friends"
    var spotPrivacy: String? = ""
    var createdBy: String? = ""
    var inviteList: [String]? = []
    var friendsList: [String] = [] 
    var isFirst: Bool? = false
    var hideFromFeed: Bool? = false
    var gif: Bool? = false
    
    var addedUsers: [String]? = []
    var addedUserProfiles: [UserProfile] = []
    var tag: String? = ""
    
    enum CodingKeys: String, CodingKey {
        case caption
        case postLat
        case postLong
        case spotID
        case spotLat
        case spotLong
        case posterID
        case imageURLs
        case frameIndexes
        case aspectRatios
        case timestamp
        case actualTimestamp
        case likers
        case city
        case taggedUsers
        case spotName
        case privacyLevel
        case spotPrivacy
        case createdBy
        case inviteList
        case isFirst
        case hideFromFeed
        case gif
        case addedUsers
        case tag
    }
}
