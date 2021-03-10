//
//  CityUser.swift
//  Spot
//
//  Created by kbarone on 1/11/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
//
//  Tag.swift
//  Spot
//
//  Created by kbarone on 1/8/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CityUser {
    
    var user: UserProfile
    var spotsList: [(spot: MapSpot, filtered: Bool)]
    var selected: Bool
    var filteredCount: Int
    
    init(user: UserProfile) {
        self.user = user
        selected = false
        spotsList = []
        filteredCount = 0
    }
}
