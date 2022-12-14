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
import Geofirestore
import GeoFire

extension MapController {
    func getVisibleSpots(searchLimit: Int? = 50) {
        geoQueryLimit = searchLimit ?? 50
        mapView.enableGeoQuery = false

        let center = mapView.centerCoordinate.location.coordinate
        let maxRadius = min(CLLocationDistance(geoQueryLimit * 10_000), 3_500_000)
        let queryRadius = min(mapView.currentRadius() / 2, maxRadius)
        let queryBounds = GFUtils.queryBounds(
            forLocation: center,
            withRadius: queryRadius)
        var spotsFetched: Int = 0
        var spotsAddedToMap: Int = 0

        let queries = queryBounds.map { bound -> Query in
            return db.collection("spots")
                .order(by: "g")
                .start(at: [bound.startValue])
                .end(at: [bound.endValue])
                .limit(to: searchLimit ?? 50)
        }

        let dispatchGroup = DispatchGroup()
        // Collect all the query results together into a single list
        func getDocumentsCompletion(snapshot: QuerySnapshot?, error: Error?) {
            guard let documents = snapshot?.documents else { dispatchGroup.leave(); return }
            for document in documents {
                spotsFetched += 1
                if self.postGroup.contains(where: { $0.id == document.documentID }) { continue }
                // unwrap spot
                do {
                    let unwrappedInfo = try document.data(as: MapSpot.self)
                    guard let spotInfo = unwrappedInfo else { continue }
                    // check for access
                    if self.showSpotOnMap(spot: spotInfo) {
                        let groupInfo = self.updateFriendsPostGroup(post: nil, spot: spotInfo)
                        if groupInfo.newGroup && self.selectedItemIndex == 0 && self.sheetView == nil {
                            // add to map if friends map showing
                            self.mapView.addPostAnnotation(group: groupInfo.group, newGroup: true, map: self.getFriendsMapObject())
                            spotsAddedToMap += 1
                        }
                    }
                } catch {
                    continue
                }
            }
            dispatchGroup.leave()
        }
        for query in queries {
            dispatchGroup.enter()
            DispatchQueue.global().async { query.getDocuments(completion: getDocumentsCompletion) }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.mapView.enableGeoQuery = true
            if spotsAddedToMap < 5 &&
                self.geoQueryLimit < 800 &&
                queryRadius < 400_000 &&
                self.shouldRunGeoQuery() {
                self.getVisibleSpots(searchLimit: self.geoQueryLimit * 2)
            }
        }
    }

    func shouldRunGeoQuery() -> Bool {
        return mapView.enableGeoQuery && selectedItemIndex == 0 && sheetView == nil
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
