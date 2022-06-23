//
//  CustomMap.swift
//  Spot
//
//  Created by Kenny Barone on 6/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift

struct CustomMap: Identifiable, Codable {
    
    @DocumentID var id: String?
    
    var founderID: String
    var imageURL: String
    var likers: [String]
    var memberIDs: [String]
    var postIDs: [String]
    var spotIDs: [String]
    
    enum CodingKeys: String, CodingKey {
        case founderID
        case imageURL
        case likers
        case memberIDs
        case postIDs
        case spotIDs
    }
}
