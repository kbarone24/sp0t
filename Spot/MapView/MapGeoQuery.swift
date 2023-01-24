//
//  MapGeoQuery.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit
import GeoFire

extension MapController {
    func getVisibleSpots(searchLimit: Int? = 50) {
        geoQueryLimit = searchLimit ?? 50
        mapView.enableGeoQuery = false

        let center = mapView.centerCoordinate.location.coordinate
        let maxRadius = min(CLLocationDistance(geoQueryLimit * 10_000), 3_500_000)
        let radius = min(mapView.currentRadius() / 2, maxRadius)
        print("radius", radius)
        Task {
            await spotService?.getNearbySpots(center: center, radius: radius, searchLimit: searchLimit ?? 50, completion: { [weak self] spots in
                guard let self else { return }
                let spotsAddedToMap = self.addSpotsToMap(nearbySpots: spots)
                self.mapView.enableGeoQuery = true

                if spotsAddedToMap < 5 &&
                    self.geoQueryLimit < 800 &&
                    radius < 400_000 &&
                    self.shouldRunGeoQuery() {
                    self.getVisibleSpots(searchLimit: self.geoQueryLimit * 2)

                } else {
                    // activity indicator will only be animating after explore maps join
                    DispatchQueue.main.async {
                        self.mapActivityIndicator.stopAnimating()
                    }
                }
            })
        }
    }

    // return # added
    func addSpotsToMap(nearbySpots: [MapSpot]) -> Int {
        var spotsAddedToMap = 0
        for spot in nearbySpots where spot.showSpotOnMap() {
            let groupInfo = self.updateFriendsPostGroup(post: nil, spot: spot)
            if groupInfo.newGroup && !(self.homeScreenDelegate?.drawerOpen() ?? false) {
                // add to map if friends map showing
                self.mapView.addPostAnnotation(group: groupInfo.group, newGroup: true, map: self.getFriendsMapObject())
                spotsAddedToMap += 1
            }
        }
        return spotsAddedToMap
    }

    func shouldRunGeoQuery() -> Bool {
        return mapView.enableGeoQuery && !(self.homeScreenDelegate?.drawerOpen() ?? false)
    }
}

extension MapController: ExploreMapDelegate {
    func finishPassing() {
        DispatchQueue.main.async {
            self.mapActivityIndicator.startAnimating(duration: 1.4)
            self.animateToCurrentLocation()
        }
    }
}
