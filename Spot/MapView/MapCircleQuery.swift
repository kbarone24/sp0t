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
    func getVisibleSpots() {
        mapView.shouldRunCircleQuery = false
        let center = mapView.centerCoordinate.location
        let radius = min(mapView.currentRadius() / 1_000, 100)
        circleQuery = geoFirestore.query(withCenter: center, radius: radius)
        circleQuery?.searchLimit = 100

        print("get visible spots")
        DispatchQueue.global(qos: .background).async {
            _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)

            _ = self.circleQuery?.observeReady { [weak self] in
                guard let self = self else { return }
                self.mapView.shouldRunCircleQuery = self.selectedItemIndex == 0
            }
        }
    }

    func removeCircleQuery() {
        circleQuery?.removeAllObservers()
    }

    func loadSpotFromDB(key: String?, location: CLLocation?) {
        Task {
            guard let key else { return }
            if self.postGroup.contains(where: { $0.id == key }) { return }
            guard let spotInfo = try? await self.spotService?.getSpot(spotID: key) else { return }
            if self.showSpotOnMap(spot: spotInfo) {
                let groupInfo = self.updateFriendsPostGroup(post: nil, spot: spotInfo)
                if groupInfo.newGroup && self.selectedItemIndex == 0 {
                    self.mapView.addPostAnnotation(group: groupInfo.group, newGroup: true, map: self.getFriendsMapObject())
                }
            }
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
