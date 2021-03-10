//
//  SpotSimple.swift
//  Spot
//
//  Created by kbarone on 6/28/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation

class SpotSimple {
    
    var spotID: String
    var spotName: String
    var spotPicURL: String!
    var spotImage: NSObject
    var spotLat : Double
    var spotLong : Double
    var time: Int64!
    var userPostID: String!
    var founderID: String
    var visitorList: [String]!
    var privacyLevel: String!
    
    init(spotID : String, spotName : String, spotPicURL : String, spotImage: NSObject, spotLat : Double, spotLong : Double, time: Int64, userPostID: String, founderID: String, privacyLevel: String) {
        self.spotID = spotID
        self.spotName = spotName
        self.spotPicURL = spotPicURL
        self.spotImage = spotImage
        self.spotLat = spotLat
        self.spotLong = spotLong
        self.time = time
        self.userPostID = userPostID
        self.founderID = founderID
        self.privacyLevel = privacyLevel
    }
    //for nearbyspotscontroller
    init(spotID : String, spotName : String, spotImage: NSObject, spotLat : Double, spotLong : Double, founderID: String, visitorList: [String], privacyLevel: String) {
        self.spotID = spotID
        self.spotName = spotName
        self.spotImage = spotImage
        self.spotLat = spotLat
        self.spotLong = spotLong
        self.founderID = founderID
        self.visitorList = visitorList
        self.privacyLevel = privacyLevel
    }
}
