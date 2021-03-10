//
//  NewSpot.swift
//  Spot
//
//  Created by kbarone on 7/3/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit

class NewSpot {
    
    var name: String
    var description: String
    var directions: String
    var spotLat: Double
    var spotLong: Double
    var tag1: String
    var tag2: String
    var tag3: String
    var createdBy: String
    var tips: String
    var visitorList: [String]
    var spotImages: [UIImage]
    var gifMode: Bool
    var selectedUsers: [(uid: String, username: String)]!
    var draftID: Int64
    
    init(name: String, description: String, directions: String, spotLat: Double, spotLong: Double, tag1: String, tag2: String, tag3: String, createdBy: String, tips: String, visitorList: [String], spotImages: [UIImage], gifMode: Bool, selectedUsers : [(uid: String, username: String)], draftID: Int64) {
        self.name = name
        self.description = description
        self.directions = directions
        self.spotLat = spotLat
        self.spotLong = spotLong
        self.tag1 = tag1
        self.tag2 = tag2
        self.tag3 = tag3
        self.createdBy = createdBy
        self.visitorList = visitorList
        self.spotImages = spotImages
        self.tips = tips
        self.gifMode = gifMode
        self.selectedUsers = selectedUsers
        self.draftID = draftID
    }
}
