//
//  City.swift
//  Spot
//
//  Created by Kenny Barone on 2/3/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift

struct City: Identifiable, Codable, Hashable {
    
    @DocumentID var id: String?
    var cityName: String
    
    var cityLat: Double = 0
    var cityLong: Double = 0
    var spotCount: Int = 0
    var friends: [String] = []
    var activeCity = false
    var score: Double = 0 
    
    enum CodingKeys: String, CodingKey {
        case id
        case cityName
    }
}
