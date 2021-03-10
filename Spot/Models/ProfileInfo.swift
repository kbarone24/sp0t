//
//  ProfileInfo.swift
//  Spot
//
//  Created by kbarone on 6/9/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ProfileInfo {
    var name: String
    var username: String
    var profilePic: UIImage
    var city: String
    var bio: String
    
    init(name: String, username: String, profilePic: UIImage, city: String, bio: String) {
        self.name = name
        self.username = username
        self.profilePic = profilePic
        self.city = city
        self.bio = bio
    }
}

