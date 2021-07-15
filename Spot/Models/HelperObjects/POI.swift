//
//  POI.swift
//  Spot
//
//  Created by Kenny Barone on 1/21/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class POI {
    
    var id: String
    var name: String
    var coordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var type: MKPointOfInterestCategory
    var phone: String
    var address: String = ""
    
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
