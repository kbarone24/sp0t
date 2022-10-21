//
//  Friend.swift
//  Spot
//
//  Created by kbarone on 6/27/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit

class Friend {

    var id: String
    var username: String
    var profilePicURL: String
    var profileImage: UIImage
    var name: String

    init(id: String, username: String, profilePicURL: String, profileImage: UIImage, name: String) {
        self.id = id
        self.username = username
        self.profilePicURL = profilePicURL
        self.profileImage = profileImage
        self.name = name
    }
}
