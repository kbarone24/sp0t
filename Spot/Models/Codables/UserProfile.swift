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
    var username: String
    var name: String
    var imageURL: String
    var currentLocation: String
    var userBio: String

    var profilePic: UIImage = UIImage()
    var spotsList: [String] = []
    var spotScore: Int? = 0
    var friendIDs: [String] = []
    var friendsList: [UserProfile] = []
    var phone: String? = ""
    var tutorialList: [Bool] = []
    
    var pendingFriendRequests: [String] = []
    var sentInvites: [String] = []
    var mutualFriends: Int = 0 
    
    enum CodingKeys: String, CodingKey {
        case username
        case name
        case imageURL
        case currentLocation
        case userBio
        case spotScore
        case friendIDs = "friendsList"
        case phone
        case tutorialList
        case pendingFriendRequests
        case sentInvites
    }
}
