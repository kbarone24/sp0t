//
//  MapCircleQuery.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit
import Geofirestore

extension MapController {
    func getVisibleSpots(searchLimit: Int? = 50) {
        circleQueryEnteredCount = 0 // total spots entered the query
        circleQueryAccessCount = 0 // spots shown on users map from this search
        circleQueryNoAccessCount = 0 // spots not shown on users map from this search
        circleQueryLimit = searchLimit ?? 50
        // cancel previous queries if location updates
        circleQuery?.removeAllObservers()
        mapView.enableCircleQuery = false

        let center = mapView.centerCoordinate.location
        let radius = min(mapView.currentRadius() / 2_000, 2_500)
        circleQuery = geoFirestore.query(withCenter: center, radius: radius)
        circleQuery?.searchLimit = searchLimit

        _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)
        _ = self.circleQuery?.observeReady { [weak self] in
            guard let self = self else { return }
            self.mapView.enableCircleQuery = true
            self.circleQueryEscape()
        }
    }

    func removeCircleQuery() {
        circleQuery?.removeAllObservers()
    }

    func circleQueryEscape() {
        // re-run query if < 5 spots and limit is below max
        if circleQueryEnteredCount == circleQueryAccessCount + circleQueryNoAccessCount {
            if circleQueryAccessCount < 5 &&
                circleQueryEnteredCount >= circleQueryLimit &&
                circleQueryLimit < 800 &&
                shouldRunCircleQuery() {
                DispatchQueue.global(qos: .background).async { self.getVisibleSpots(searchLimit: self.circleQueryLimit * 2) }
            } else {
                self.mapView.enableCircleQuery = true
            }
        }
    }

    func shouldRunCircleQuery() -> Bool {
        return mapView.enableCircleQuery && selectedItemIndex == 0 && sheetView == nil
    }

    func loadSpotFromDB(key: String?, location: CLLocation?) {
        Task {
            guard let key else { return }
            self.circleQueryEnteredCount += 1
            if self.postGroup.contains(where: { $0.id == key }) { self.circleQueryAccessCount += 1; return }
            guard let spotInfo = try? await self.spotService?.getSpot(spotID: key) else { self.circleQueryNoAccessCount += 1; return }
            if self.showSpotOnMap(spot: spotInfo) {
                self.circleQueryAccessCount += 1
                let groupInfo = self.updateFriendsPostGroup(post: nil, spot: spotInfo)
                if groupInfo.newGroup && self.selectedItemIndex == 0 {
                    self.mapView.addPostAnnotation(group: groupInfo.group, newGroup: true, map: self.getFriendsMapObject())
                }
            } else {
                self.circleQueryNoAccessCount += 1
            }
            self.circleQueryEscape()
        }
    }

    func showSpotOnMap(spot: MapSpot) -> Bool {
        // if theres a friends post to this spot (not to secret map), return true
        for i in 0..<spot.postIDs.count {
            if spot.postPrivacies[safe: i] != "invite" &&
                (UserDataModel.shared.userInfo.friendIDs.contains(spot.posterIDs[safe: i] ?? "") || spot.posterIDs[safe: i] == uid) {
                return true
            }
        }
        return false
    }
}
