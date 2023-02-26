//
//  LocationService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import CoreLocation

protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get set }
    func reverseGeocode(location: CLLocation, zoomLevel: Int) async throws -> String // Returns address
}

final class LocationService: NSObject, LocationServiceProtocol {
    
    var currentLocation: CLLocation?
    private let locationManager: CLLocationManager
    
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        self.currentLocation = locationManager.location
        self.locationManager.delegate = self
    }
    
    func reverseGeocode(location: CLLocation, zoomLevel: Int) async throws -> String {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: "")
                return
            }
            
            var addressString = ""
            let locale = Locale(identifier: "en")
            
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
                guard error == nil, let placemark = placemarks?.first else {
                    continuation.resume(returning: "")
                    return
                }
                
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
                    
                default:
                    addressString = ""
                }
                
                if let country = placemark.country {
                    if country == "United States" && zoomLevel == 0 {
                        if let administrativeArea = placemark.administrativeArea {
                            if addressString != "" { addressString += ", "}
                            addressString += administrativeArea
                            continuation.resume(returning: addressString)
                        } else {
                            continuation.resume(returning: addressString)
                        }
                    } else {
                        if addressString != "" {
                            addressString += ", "
                        }
                        
                        addressString += country
                        continuation.resume(returning: addressString)
                    }
                } else {
                    continuation.resume(returning: addressString)
                }
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        self.currentLocation = location
        Task {
            guard let city = try? await self.reverseGeocode(location: location, zoomLevel: 0) else {
                return
            }
            UserDataModel.shared.userCity = city
        }
    }
    
    private func getUSStateFrom(abbreviation: String) -> String {
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
}
