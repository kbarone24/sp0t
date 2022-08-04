//
//  UserProfile.swift
//  Spot
//
//  Created by kbarone on 8/4/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//


import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift

struct UserProfile: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    var avatarURL: String? = ""
    var currentLocation: String
    var friendIDs: [String] = []
    var imageURL: String
    var name: String
    var pendingFriendRequests: [String] = []
    var phone: String? = ""
    var sentInvites: [String] = []
    var spotScore: Int? = 0
    var tagDictionary: [String: Int] = [:]
    var topFriends: [String: Int] = [:]
    var tutorialList: [Bool] = []
    var userBio: String
    var username: String

    // supplemental values
    var profilePic: UIImage = UIImage()
    var avatarPic: UIImage = UIImage()
    
    var mapsList: [CustomMap] = []
    var spotsList: [String] = []
    var friendsList: [UserProfile] = []
    var mutualFriends: Int = 0
    var selected: Bool = false
    
    
    enum CodingKeys: String, CodingKey {
        case id
        case avatarURL
        case currentLocation
        case friendIDs = "friendsList"
        case imageURL
        case name
        case pendingFriendRequests
        case phone
        case sentInvites
        case spotScore
        case tagDictionary
        case topFriends
        case tutorialList
        case userBio
        case username
    }
    
    mutating func sortMaps() {
        /// sort first by maps that have an unseen post, then by most recent post timestamp
        mapsList = mapsList.sorted(by: { m1, m2 in
            guard m1.hasNewPost == m2.hasNewPost else {
                return m1.hasNewPost && !m2.hasNewPost
            }
            return m1.postTimestamps.last!.seconds > m2.postTimestamps.last!.seconds
        })
    }
}
