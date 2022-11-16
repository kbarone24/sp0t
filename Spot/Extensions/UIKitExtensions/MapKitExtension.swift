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
        // convert POI type into readable string
        var text = rawValue
        var counter = 13
        while counter > 0 { text = String(text.dropFirst()); counter -= 1 }

        // insert space in POI type if necessary
        counter = 0
        var uppercaseIndex = 0
        for letter in text {if letter.isUppercase && counter != 0 { uppercaseIndex = counter }; counter += 1}
        if uppercaseIndex != 0 { text.insert(" ", at: text.index(text.startIndex, offsetBy: uppercaseIndex)) }

        return text
    }
}

extension CLPlacemark {
    func addressFormatter(number: Bool) -> String {
        var addressString = ""
        // add number if locationPicker
        if number, let subThoroughfare {
            addressString += subThoroughfare + " "
        }

        if let thoroughfare {
            addressString += thoroughfare
        }

        if let locality {
            if addressString != "" {
                addressString += ", "
            }
            addressString += locality
        }

        if let country {
            // add state name for US
            if country == "United States" {
                if administrativeArea != nil {

                    if addressString != "" { addressString = addressString + ", " }
                    addressString = addressString + administrativeArea!
                }
            }
            if addressString != "" { addressString = addressString + ", " }
            addressString += country
        }
        return addressString
    }
}

extension CLLocationDistance {
    func getLocationString() -> String {
        let feet = inFeet()
        if feet > 528 {
            let miles = inMiles()
            let milesString = String(format: "%.2f", miles)
            return milesString + " mi"
        } else {
            let feetString = String(Int(feet))
            return feetString + " ft"
        }
    }

    func inFeet() -> CLLocationDistance {
        return self * 3.280_84
    }

    func inMiles() -> CLLocationDistance {
        return self * 0.000_621_37
    }
}
// supplementary methods for offsetCenterCoordinate
extension CLLocationCoordinate2D {
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    private func radians(from degrees: CLLocationDegrees) -> Double {
        return degrees * .pi / 180.0
    }

    private func degrees(from radians: Double) -> CLLocationDegrees {
        return radians * 180.0 / .pi
    }

    func adjust(by distance: CLLocationDistance, at bearing: CLLocationDegrees) -> CLLocationCoordinate2D {

        let distanceRadians = distance / 6_371.0   // 6,371 = Earth's radius in km
        let bearingRadians = radians(from: bearing)
        let fromLatRadians = radians(from: latitude)
        let fromLonRadians = radians(from: longitude)

        let toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
                                 + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) )

        var toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
                                                  * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                                                  - sin(fromLatRadians) * sin(toLatRadians))

        // adjust toLonRadians to be in the range -180 to +180...
        toLonRadians = fmod((toLonRadians + 3.0 * .pi), (2.0 * .pi)) - .pi

        let result = CLLocationCoordinate2D(latitude: degrees(from: toLatRadians), longitude: degrees(from: toLonRadians))

        return result
    }

    func isEqualTo(coordinate: CLLocationCoordinate2D) -> Bool {
        return location.coordinate.latitude == coordinate.latitude && location.coordinate.longitude == coordinate.longitude
    }
}
///https://stackoverflow.com/questions/15421106/centering-mkmapview-on-spot-n-pixels-below-pin

// Supposed to exclude invalid geoQuery regions. Not sure how well it works
extension MKCoordinateRegion {
    var maxSpan: Double {
        get {
            return 200
        }
    }

    init(coordinates: [CLLocationCoordinate2D], overview: Bool) {
        self.init()

        guard let firstCoordinate = coordinates.first else {
            self.init(center: UserDataModel.shared.currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
            return
        }
        let minSpan = 0.001
      //  let minSpan = overview ? 0.001 : 0.0001
        var span = MKCoordinateSpan(latitudeDelta: 0.0, longitudeDelta: 0.0)
        var minLatitude: CLLocationDegrees = firstCoordinate.latitude
        var maxLatitude: CLLocationDegrees = firstCoordinate.latitude
        var minLongitude: CLLocationDegrees = firstCoordinate.longitude
        var maxLongitude: CLLocationDegrees = firstCoordinate.longitude

        for coordinate in coordinates {
            /// set local variables in case continue called before completion
            var minLat = minLatitude
            var maxLat = maxLatitude
            var minLong = minLongitude
            var maxLong = maxLongitude

            let lat = Double(coordinate.latitude)
            let long = Double(coordinate.longitude)
            if lat < minLatitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: maxLatitude - lat, longitudeDelta: span.longitudeDelta).getAdjustedSpan()) { continue }
                minLat = lat
            }
            if lat > maxLatitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: lat - minLatitude, longitudeDelta: span.longitudeDelta).getAdjustedSpan()) { continue }
                maxLat = lat
            }
            if long < minLongitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta, longitudeDelta: maxLongitude - long).getAdjustedSpan()) { continue }
                minLong = long
            }
            if long > maxLongitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta, longitudeDelta: long - minLongitude).getAdjustedSpan()) { continue }
                maxLong = long
            }

            minLatitude = minLat
            maxLatitude = maxLat
            minLongitude = minLong
            maxLongitude = maxLong
            span = MKCoordinateSpan(latitudeDelta: max(minSpan, maxLatitude - minLatitude), longitudeDelta: max(minSpan, maxLongitude - minLongitude)).getAdjustedSpan()
        }
        let center = CLLocationCoordinate2DMake((minLatitude + maxLatitude) / 2, (minLongitude + maxLongitude) / 2)
        self.init(center: center, span: span)
    }

    ///https://stackoverflow.com/questions/14374030/center-coordinate-of-a-set-of-cllocationscoordinate2d
    func spanOutOfRange(span: MKCoordinateSpan) -> Bool {
        let span = span.getAdjustedSpan()
        return span.latitudeDelta > maxSpan || span.longitudeDelta > maxSpan
    }
}

extension MKCoordinateSpan {
    func getAdjustedSpan() -> MKCoordinateSpan {
        return MKCoordinateSpan(latitudeDelta: latitudeDelta * 2.0, longitudeDelta: longitudeDelta * 2.0)
    }
}

extension MKMapView {
    // get radius
    func topCenterCoordinate() -> CLLocationCoordinate2D {
        return self.convert(CGPoint(x: self.frame.size.width / 2.0, y: 0), toCoordinateFrom: self)
    }

    func currentRadius() -> Double {
        let centerLocation = CLLocation(latitude: self.centerCoordinate.latitude, longitude: self.centerCoordinate.longitude)
        let topCenterCoordinate = self.topCenterCoordinate()
        let topCenterLocation = CLLocation(latitude: topCenterCoordinate.latitude, longitude: topCenterCoordinate.longitude)
        return centerLocation.distance(from: topCenterLocation)
    }
}
