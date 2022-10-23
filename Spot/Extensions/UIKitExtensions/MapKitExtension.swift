//
//  MapKitExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(location)
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.location == rhs.location
    }
}

extension MKPointOfInterestCategory {

    func toString() -> String {

        /// convert POI type into readable string
        var text = rawValue
        var counter = 13
        while counter > 0 { text = String(text.dropFirst()); counter -= 1 }

        /// insert space in POI type if necessary
        counter = 0
        var uppercaseIndex = 0
        for letter in text {if letter.isUppercase && counter != 0 { uppercaseIndex = counter }; counter += 1}
        if uppercaseIndex != 0 { text.insert(" ", at: text.index(text.startIndex, offsetBy: uppercaseIndex)) }

        return text
    }
}
