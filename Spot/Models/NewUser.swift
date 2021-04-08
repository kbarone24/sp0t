//
//  NewUser.swift
//  Spot
//
//  Created by Kenny Barone on 3/24/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation

class NewUser {
    
    var name: String
    var email: String
    var password: String
    var username: String
    var phone: String
    
    init(name: String, email: String, password: String, username: String, phone: String) {
        self.name = name
        self.email = email
        self.password = password
        self.username = username
        self.phone = phone
    }
}
