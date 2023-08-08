//
//  ChooseSpotFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension ChooseSpotController {
    func runChooseSpotFetch() {
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() } /// shows loading indicator

        getNearbySpots()
        getNearbyPOIs()
    }

    func getNearbyPOIs() {
        search?.cancel()
        let searchRequest = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(
                latitude: UploadPostModel.shared.postObject?.postLat ?? 0,
                longitude: UploadPostModel.shared.postObject?.postLong ?? 0),
            radius: 200
        )
        /// these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
        let filters = MKPointOfInterestFilter(including: searchFilters)
        searchRequest.pointOfInterestFilter = filters

        runPOIFetch(request: searchRequest)
    }

    /// recursive func called with an increasing radius -> Ensure always fetching the closest POI's since max limit is 25
    func runPOIFetch(request: MKLocalPointsOfInterestRequest) {
        search?.cancel()
        search = MKLocalSearch(request: request)
        search?.start { [weak self] response, _ in
            guard let self = self else { return }
            if self.cancelOnDismiss { return }

            let newRequest = MKLocalPointsOfInterestRequest(
                center: CLLocationCoordinate2D(
                    latitude: UploadPostModel.shared.postObject?.postLat ?? 0,
                    longitude: UploadPostModel.shared.postObject?.postLong ?? 0),
                radius: request.radius * 2)
            newRequest.pointOfInterestFilter = request.pointOfInterestFilter

            /// if the new radius won't be greater than about 1.5 miles then run poi fetch to get more nearby stuff
            guard let response = response else {
                /// error usually means no results found
                if newRequest.radius < 3_000 {
                    self.runPOIFetch(request: newRequest)
                } else {
                    self.endQuery()
                }
                return
            }

            /// > 10 poi's should be enough for the table, otherwise re-run fetch
            if response.mapItems.count < 10 && newRequest.radius < 3_000 {   self.runPOIFetch(request: newRequest); return }

            let postLocation = CLLocation(
                latitude: UploadPostModel.shared.postObject?.postLat ?? 0,
                longitude: UploadPostModel.shared.postObject?.postLong ?? 0
            )
            for item in response.mapItems {
                if item.pointOfInterestCategory != nil, let poiName = item.name {
                    let phone = item.phoneNumber ?? ""
                    let name = poiName.count > 60 ? String(poiName.prefix(60)) : poiName

                    /// check for spot duplicate
                    if self.spotObjects.contains(where: { $0.spotName == name ||
                        ($0.phone ?? "" == phone && phone != "") }) {
                        continue
                    }

                    var spotInfo = MapSpot(
                        id: UUID().uuidString,
                        founderID: "",
                        mapItem: item,
                        imageURL: "",
                        spotName: name,
                        privacyLevel: "public"
                    )

                    spotInfo.distance = postLocation.distance(from: spotInfo.location)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)
                    self.spotObjects.append(spotInfo)
                }
            }
            self.endQuery()
        }
    }

    func getNearbySpots(radius: CLLocationDistance? = 500) {
        //  let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject?.postLat ?? 0, longitude: UploadPostModel.shared.postObject?.postLong ?? 0)
        let postLocation = UserDataModel.shared.currentLocation
        let searchLimit = 300
        let radius = radius ?? 500

        Task {
            await spotService?.getNearbySpots(center: postLocation.coordinate, radius: radius, searchLimit: searchLimit, completion: { [weak self] spots in
                guard let self = self else { return }
                let accessSpots = spots.filter({ $0.showSpotOnMap() })
                for spot in accessSpots {
                    self.addSpot(spot: spot, query: false)
                }

                // re-run fetch if nothing returned
                if accessSpots.count < 1 && radius < 2_000 {
                    self.getNearbySpots(radius: radius * 2)
                } else {
                    self.endQuery()
                }
            })
        }
    }

    func addSpot(spot: MapSpot, query: Bool) {
        var spot = spot
      //  let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject?.postLat ?? 0, longitude: UploadPostModel.shared.postObject?.postLong ?? 0)
        let postLocation = UserDataModel.shared.currentLocation

        spot.distance = spot.location.distance(from: postLocation)
        spot.spotScore = spot.getSpotRank(location: postLocation)

        if spot.privacyLevel != "public" && spot.poiCategory ?? "" == "" {
            spot.spotDescription = spot.posterUsername == "" ? "" : "By \(spot.posterUsername ?? "")"
        } else {
            spot.spotDescription = spot.poiCategory ?? ""
        }

        // replace POI with spot that's already been created (search)
        if query {
            if let i = self.querySpots.firstIndex(where: {
                $0.spotName == spot.spotName ||
                ($0.phone == spot.phone ?? "" && spot.phone ?? "" != "") }) {
                self.querySpots[i] = spot
                self.querySpots[i].poiCategory = nil
            } else {
                // append new spot
                querySpots.append(spot)
            }
        // replace POI with spot that's already been created (nearby fetch)
        } else {
            if let i = spotObjects.firstIndex(where: {
                $0.spotName == spot.spotName ||
                ($0.phone == spot.phone ?? "" && spot.phone ?? "" != "") }) {
                spot.selected = spotObjects[i].selected
                spotObjects[i] = spot
                spotObjects[i].poiCategory = nil
                return
            } else {
                spotObjects.append(spot)
            }
        }
    }

    func endQuery() {
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        spotObjects.sort(by: {
            !($0.selected ?? false) && !($1.selected ?? false) ? $0.spotScore > $1.spotScore : ($0.selected ?? false) && !($1.selected ?? false)
        })

        search = nil
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
}
