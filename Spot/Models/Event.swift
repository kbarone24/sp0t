//
//  Event.swift
//  Spot
//
//  Created by kbarone on 11/14/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class Event {

    var spotID: String!
    var eventID: String!
    var time: Int64!
    var date: Date!
    var imageURL: String
    var eventImage: UIImage!
    var spotName: String!
    var eventName: String!
    var spotLat: Double!
    var spotLong: Double!
    var active: Bool!
    var price: Int!
    var description: String!

    init(spotID: String, eventID: String, time: Int64, date: Date, imageURL: String, eventImage: UIImage, spotName: String, eventName: String, spotLat: Double, spotLong: Double, active: Bool, price: Int, description: String) {
        self.spotID = spotID
        self.eventID = eventID
        self.time = time
        self.date = date
        self.imageURL = imageURL
        self.eventImage = eventImage
        self.spotName = spotName
        self.eventName = eventName
        self.spotLat = spotLat
        self.spotLong = spotLong
        self.active = active
        self.price = price
        self.description = description
    }

}
