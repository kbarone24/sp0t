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
    var userInfo: UserProfile!
    var spotID: String? = ""
    var gif: Bool? = false
    var city: String? = ""

    var imageURLs: [String] = []
    var postImage: [UIImage] = []
    var seconds: Int64 = 0
    var selectedImageIndex = 0
    var commentList: [MapComment] = []
    var likers: [String]
    var taggedUsers: [String]? = []
    
    // all of these will only return for feed post
    var spotName: String? = ""
    var spotLat: Double? = 0.0
    var spotLong: Double? = 0.0
    var privacyLevel: String? = ""
    var spotPrivacy: String? = ""
    var createdBy: String? = ""
    var inviteList: [String]? = []
    var isFirst: Bool? = false
    
    enum CodingKeys: String, CodingKey {
        case caption
        case postLat
        case postLong
        case spotID
        case spotLat
        case spotLong
        case posterID
        case imageURLs
        case timestamp
        case likers
        case gif
        case city
        case taggedUsers
        case spotName
        case privacyLevel
        case spotPrivacy
        case createdBy
        case inviteList
        case isFirst
    }
}
