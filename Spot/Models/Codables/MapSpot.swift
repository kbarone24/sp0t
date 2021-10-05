//
//  MapSpot.swift
//  Spot
//
//  Created by kbarone on 6/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Firebase
import FirebaseFirestoreSwift

struct MapSpot: Identifiable, Codable {
    
    @DocumentID var id: String?
    var spotDescription: String
    var spotName: String
    var spotLat: Double
    var spotLong: Double
    var founderID: String
    var privacyLevel: String
    var postIDs: [String] = []
    var posterIDs: [String] = []
    var postTimestamps: [Firebase.Timestamp] = []
    var postPrivacies: [String] = []
    var posterUsername: String? = ""
    var visitorList: [String] = [] 
    var inviteList: [String]? = []
    var tags: [String] = []
    var imageURL: String
    var spotImage: UIImage = UIImage()
    var taggedUsers: [String]? = []
    var city: String? = ""
    var phone: String? = ""
    var poiCategory: String? ///  poi category is a nil value to check on uploadPost for spot v poi
    
    var checkInTime: Int64 = 0
    var friendVisitors = 0
    var visiblePosts = 0
    var spotScore: Double = 0
    var distance: CLLocationDistance = CLLocationDistance()
    var friendImage = false
    var selected: Bool? = false
    var postFetchID = "" 
    
    enum CodingKeys: String, CodingKey {
        case id = "spotID"
        case spotDescription = "description"
        case spotName
        case founderID = "createdBy"
        case privacyLevel
        case visitorList
        case inviteList
        case imageURL
        case taggedUsers
        case spotLat
        case spotLong
        case city
        case phone
        case poiCategory
        case postIDs
        case posterIDs
        case postTimestamps
        case postPrivacies
        case posterUsername
    }
}
