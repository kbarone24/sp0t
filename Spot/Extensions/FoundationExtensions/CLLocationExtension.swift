//
//  CLLocationExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import CoreLocation

extension CLLocation {
    func userInChapelHill() -> Bool {
        let chapelHillLocation = CLLocation(latitude: 35.9132, longitude: -79.0558)
        let distance = distance(from: chapelHillLocation)
        return distance / 1_000 < 10
    }
}
