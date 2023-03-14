//
//  Contact.swift
//  Spot
//
//  Created by kbarone on 10/9/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation

class Contact {
    var id: String
    var username: String
    var name: String
    var profilePicURL: String
    var number: String
    var friend: Bool
    var pending: Bool

    init(id: String, username: String, name: String, profilePicURL: String, number: String, friend: Bool, pending: Bool) {
        self.id = id
        self.username = username
        self.name = name
        self.profilePicURL = profilePicURL
        self.number = number
        self.friend = friend
        self.pending = pending
    }
}
