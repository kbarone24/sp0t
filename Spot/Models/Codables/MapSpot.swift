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
    
    /// used for nearby spots in choose spot sections on Upload and LocationPicker. Similar logic as get post score
    func getSpotRank(location: CLLocation) -> Double {
        
        var scoreMultiplier = postIDs.isEmpty ? 10.0 : 50.0 /// 5x boost to any spot that has posts at it
        let distance = max(CLLocation(latitude: spotLat, longitude: spotLong).distance(from: location), 1)
        
        if postIDs.count > 0 { for i in 0 ... postIDs.count - 1 {

            var postScore: Double = 10
            
            /// increment for each friend post
            if posterIDs.count <= i { continue }
            if isFriends(id: posterIDs[i]) { postScore += 5 }

            let timestamp = postTimestamps[i]
            let postTime = Double(timestamp.seconds)
            
            let current = NSDate().timeIntervalSince1970
            let currentTime = Double(current)
            let timeSincePost = currentTime - postTime
            
            /// add multiplier for recent posts
            var factor = min(1 + (1000000 / timeSincePost), 5)
            let multiplier = pow(1.2, factor)
            factor = multiplier
            
            postScore *= factor
            scoreMultiplier += postScore
        } }

        let finalScore = scoreMultiplier/pow(distance, 1.7)
        return finalScore
    }

    func isFriends(id: String) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if id == uid || (UserDataModel.shared.friendIDs.contains(where: {$0 == id}) && !(UserDataModel.shared.adminIDs.contains(id))) { return true }
        return false
    }
}
