//
//  ResultSpot.swift
//  Spot
//
//  Created by kbarone on 6/25/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseFirestoreSwift
import CoreLocation

struct ResultSpot: Identifiable, Codable {
    
    @DocumentID var id: String?
    var spotName: String
    var l: [Double] = []
    var spotLat: Double = 0.0
    var spotLong: Double = 0.0
    var founderID: String
    var privacyLevel: String
    var imageURL : String

    var visitorList: [String] = []
    var inviteList: [String]? = []
    var spotImage: UIImage = UIImage()
    
    
    ///for add new
    enum CodingKeys: String, CodingKey {
        case id = "spotID"
        case spotName
        case founderID = "createdBy"
        case privacyLevel
        case visitorList
        case inviteList
        case imageURL
        case l
    }
}
