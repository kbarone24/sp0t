//
//  AboutSpot.swift
//  Spot
//
//  Created by kbarone on 7/17/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit

class AboutSpot {

    var spotImage: [UIImage]
    var spotName: String
    var userImage: UIImage
    var username: String
    var description: String
    var tags: [String]
    var address: String
    var directions: String
    var tips: String
    var labelType: String
    var founderID: String
    var spotID: String

    init(spotImage: [UIImage], spotName: String, userImage: UIImage, username: String, description: String, tags: [String], address: String, directions: String, tips: String, labelType: String, founderID: String, spotID: String) {
        self.spotImage = spotImage
        self.spotName = spotName
        self.userImage = userImage
        self.username = username
        self.description = description
        self.tags = tags
        self.address = address
        self.directions = directions
        self.tips = tips
        self.labelType = labelType
        self.founderID = founderID
        self.spotID = spotID
    }
}
