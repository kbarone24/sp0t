//
//  POI.swift
//  Spot
//
//  Created by Kenny Barone on 1/21/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Foundation
import MapKit

struct POI {

    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var type: MKPointOfInterestCategory
    var phone: String
    var address: String = ""
    var selected: Bool = false

    // init for nearby
    init(name: String, coordinate: CLLocationCoordinate2D, distance: CLLocationDistance, type: MKPointOfInterestCategory, phone: String) {
        self.id = UUID().uuidString
        self.name = name
        self.coordinate = coordinate
        self.distance = distance
        self.type = type
        self.phone = phone
    }

    // init for search
    init(name: String, coordinate: CLLocationCoordinate2D, distance: CLLocationDistance, type: MKPointOfInterestCategory, phone: String, address: String) {
        self.id = UUID().uuidString
        self.name = name
        self.coordinate = coordinate
        self.distance = distance
        self.type = type
        self.phone = phone
        self.address = address
    }
}
