//
//  CLLocationExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreLocation

extension CLLocation {
    func reverseGeocode(zoomLevel: Int, completion: @escaping (_ address: String, _ error: Bool) -> Void) {
        var addressString = ""
        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(self, preferredLocale: locale) { placemarks, err in
            if err != nil { completion("", true); return }
            guard let placemark = placemarks?.first else { completion("", false); return }
            switch zoomLevel {
            case 0:
                if let locality = placemark.locality {
                    addressString = locality
                }
            case 1:
                if placemark.country == "United States", let state = placemark.administrativeArea {
                    // full-name US state if zoomed out
                    addressString = self.getUSStateFrom(abbreviation: state)
                }
            default: addressString = ""
            }
            if let country = placemark.country {
                if country == "United States" && zoomLevel == 0 {
                    if let administrativeArea = placemark.administrativeArea {
                        if addressString != "" { addressString += ", "}
                        addressString += administrativeArea
                        completion(addressString, false)
                    } else {
                        completion(addressString, false)
                    }
                } else {
                    if addressString != "" { addressString += ", "}
                    addressString += country
                    completion(addressString, false)
                }
            } else {
                completion(addressString, false)
            }
        }
    }

    func getUSStateFrom(abbreviation: String) -> String {
        let states = [
            "AL": "Alabama",
            "AK": "Alaska",
            "AZ": "Arizona",
            "AR": "Arkansas",
            "CA": "California",
            "CO": "Colorado",
            "CT": "Connecticut",
            "DE": "Delaware",
            "DC": "Washington, DC",
            "FL": "Florida",
            "GA": "Georgia",
            "HI": "Hawaii",
            "ID": "Idaho",
            "IL": "Illinois",
            "IN": "Indiana",
            "IA": "Iowa",
            "KS": "Kansas",
            "KY": "Kentucky",
            "LA": "Louisiana",
            "ME": "Maine",
            "MD": "Maryland",
            "MA": "Massachusetts",
            "MI": "Michigan",
            "MN": "Minnesota",
            "MS": "Mississippi",
            "MO": "Missouri",
            "MT": "Montana",
            "NE": "Nebraska",
            "NV": "Nevada",
            "NH": "New Hampshire",
            "NJ": "New Jersey",
            "NM": "New Mexico",
            "NY": "New York",
            "NC": "North Carolina",
            "ND": "North Dakota",
            "OH": "Ohio",
            "OK": "Oklahoma",
            "OR": "Oregon",
            "PA": "Pennsylvania",
            "RI": "Rhode Island",
            "SC": "South Carolina",
            "SD": "South Dakota",
            "TN": "Tennessee",
            "TX": "Texas",
            "UT": "Utah",
            "VT": "Vermont",
            "VA": "Virginia",
            "WA": "Washington",
            "WV": "West Virginia",
            "WI": "Wisconsin",
            "WY": "Wyoming"
        ]
        return states[abbreviation] ?? ""
    }

    func userInChapelHill() -> Bool {
        let chapelHillLocation = CLLocation(latitude: 35.9132, longitude: -79.0558)
        let distance = distance(from: chapelHillLocation)
        return distance / 1_000 < 10
    }
}
