//
//  ContactFriend.swift
//  Spot
//
//  Created by Kenny Barone on 6/5/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class Friend {
    
    var id: String
    var username: String
    var profilePicURL: String
    var profileImage: UIImage
    var name: String
    
    init(id : String, username : String, profilePicURL : String, profileImage: UIImage, name: String) {
        self.id = id
        self.username = username
        self.profilePicURL = profilePicURL
        self.profileImage = profileImage
        self.name = name
    }
}

