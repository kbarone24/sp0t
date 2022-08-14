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
    var topFriends: [String: Int]? = [:]
    var tutorialList: [Bool] = []
    var userBio: String
    var username: String

    // supplemental values
    var profilePic: UIImage = UIImage()
    var avatarPic: UIImage = UIImage()
    
    var spotsList: [String] = []
    var friendsList: [UserProfile] = []
    var postCount: Int = 0
    var mutualFriends: Int = 0
    var selected: Bool = false
    var mapsList: [CustomMap] = []
    
    var pending: Bool?
    var friend: Bool?

    
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
    
    mutating func sortFriends() {
        /// sort friends based on user's top friends
        if topFriends?.isEmpty ?? true { return }
        
        let sortedFriends = topFriends!.sorted(by: {$0.value > $1.value})
        self.friendIDs = sortedFriends.map({$0.key})
        
        let topFriends = Array(sortedFriends.map({$0.key}))
        var friendObjects: [UserProfile] = []
        
        for friend in topFriends {
            if let object = friendsList.first(where: {$0.id == friend}) {
                friendObjects.append(object)
            }
        }
        /// add any friend not in top friends
        for friend in friendsList {
            if !friendObjects.contains(where: {$0.id == friend.id}) { friendObjects.append(friend) }
        }
        friendsList = friendObjects
    }
    
    func getSelectedFriends(memberIDs: [String]) -> [UserProfile] {
        var selectedFriends = friendsList
        for member in memberIDs {
            if let i = friendsList.firstIndex(where: {$0.id == member}) {
                selectedFriends[i].selected = true
            }
        }
        return selectedFriends
    }
}
