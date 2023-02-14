//
//  TabBarLocationManager.swift
//  Spot
//
//  Created by Kenny Barone on 2/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import MapKit

extension SpotTabBarController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted {
            Mixpanel.mainInstance().track(event: "LocationServicesDenied")
        } else if status == .authorizedWhenInUse || status == .authorizedWhenInUse {
            Mixpanel.mainInstance().track(event: "LocationServicesAllowed")
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()
        }
        // ask for notifications access immediately after location access
        let pushManager = PushNotificationManager(userID: UserDataModel.shared.uid)
        pushManager.registerForPushNotifications()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        UserDataModel.shared.currentLocation = location
        setUserCityFor(location: location)
        if firstTimeGettingLocation {
            if manager.accuracyAuthorization == .reducedAccuracy { Mixpanel.mainInstance().track(event: "PreciseLocationOff") }
            /// set current location to show while feed loads
            firstTimeGettingLocation = false
            NotificationCenter.default.post(name: Notification.Name("UpdateLocation"), object: nil)
        }
    }

    func checkLocationAuth() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // prompt user to open their settings if they havent allowed location services

        case .restricted, .denied:
            presentLocationAlert()

        case .authorizedWhenInUse, .authorizedAlways:
            UploadPostModel.shared.locationAccess = true
            locationManager.startUpdatingLocation()

        @unknown default:
            return
        }
        locationManager.delegate = self
    }

    func presentLocationAlert() {
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

        self.present(alert, animated: true, completion: nil)
    }

    private func setUserCityFor(location: CLLocation) {
        location.reverseGeocode(zoomLevel: 0) { (city, err)  in
            if city == "" && err { return }
            UserDataModel.shared.userCity = city
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UserCitySet")))
        }
    }
}
