//
//  LocationService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import CoreLocation
import Mixpanel

protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get set }
    func getCityFromLocation(location: CLLocation, zoomLevel: Int) async -> String
    func locationAlert() -> UIAlertController
    func checkLocationAuth() -> UIAlertController?
}

final class LocationService: NSObject, LocationServiceProtocol {
    
    var currentLocation: CLLocation?
    var cachedCity: String = ""
    private let locationManager: CLLocationManager
    
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager
        super.init()
        self.currentLocation = locationManager.location
        self.locationManager.delegate = self
    }
    
    func getCityFromLocation(location: CLLocation, zoomLevel: Int) async -> String {
        await withUnsafeContinuation { continuation in
            self.cityFrom(location: location, zoomLevel: zoomLevel) { city in
                if city == "" {
                    // add cache to protect from geocoder throttling
                    continuation.resume(returning: self.cachedCity)
                    return
                }
                if location.coordinate == self.currentLocation?.coordinate {
                    NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UserCitySet")))
                }
                self.cachedCity = city
                continuation.resume(returning: city)
            }
        }
    }
    
    private func cityFrom(location: CLLocation, zoomLevel: Int, completion: @escaping ((String) -> Void)) {
        var addressString = ""
        let locale = Locale(identifier: "en")
        
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, error in
            guard let self, error == nil, let placemark = placemarks?.first else {
                completion("")
                return
            }
            
            DispatchQueue.global(qos: .utility).async {
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
                            completion(addressString)
                        } else {
                            completion(addressString)
                        }
                    } else {
                        if addressString != "" {
                            addressString += ", "
                        }
                        
                        addressString += country
                        completion(addressString)
                    }
                } else {
                    completion(addressString)
                }
            }
        }
    }
    
    // Returns an optional error alert view to be presented if location access is denied
    @discardableResult
    func checkLocationAuth() -> UIAlertController? {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // prompt user to open their settings if they havent allowed location services
            return nil
            
        case .restricted, .denied:
            return locationAlert()
            
        case .authorizedWhenInUse, .authorizedAlways:
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()
            return nil
            
        @unknown default:
            return nil
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            Mixpanel.mainInstance().track(event: "LocationServicesDenied")
        } else if status == .authorizedWhenInUse || status == .authorizedWhenInUse {
            Mixpanel.mainInstance().track(event: "LocationServicesAllowed")
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        self.currentLocation = location
        UserDataModel.shared.currentLocation = location
        
        if manager.accuracyAuthorization == .reducedAccuracy { Mixpanel.mainInstance().track(event: "PreciseLocationOff") }
        
        NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
    }
    
    func locationAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "Spot needs your location to find spots near you",
            message: nil,
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(title: "Settings", style: .default) { _ in
                Mixpanel.mainInstance().track(event: "LocationServicesSettingsOpen")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:])
                }
            }
        )
        
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel) { _ in
            }
        )
        
        return alert
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
