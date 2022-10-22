//
//  ResultSpot.swift
//  Spot
//
//  Created by kbarone on 6/25/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import FirebaseFirestoreSwift
import Foundation
import UIKit

struct ResultSpot: Identifiable, Codable, Hashable {

    @DocumentID var id: String?
    var spotName: String
    var l: [Double] = []
    var spotLat: Double = 0.0
    var spotLong: Double = 0.0
    var founderID: String
    var privacyLevel: String
    var imageURL: String

    var visitorList: [String] = []
    var inviteList: [String]? = []
    var spotImage: UIImage = UIImage()

    /// for add new
    enum CodingKeys: String, CodingKey {
        case id
        case spotName
        case founderID = "createdBy"
        case privacyLevel
        case visitorList
        case inviteList
        case imageURL
        case l
    }
}