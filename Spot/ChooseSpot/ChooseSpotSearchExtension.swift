//
//  ChooseSpotSearchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 12/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension ChooseSpotController {
    func runSpotSearch(searchText: String) {
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runSpotQuery), object: nil)
        self.perform(#selector(runSpotQuery), with: nil, afterDelay: 0.4)
    }

    @objc func runSpotQuery() {
        emptySpotQueries()
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() }

        DispatchQueue.global(qos: .userInitiated).async {
            self.runPOIQuery(searchText: self.searchTextGlobal)
            self.runNearbyQuery(searchText: self.searchTextGlobal)
        }
    }

    func emptySpotQueries() {
        spotSearching = false
        searchRefreshCount = 0
        querySpots.removeAll()
    }

    func runPOIQuery(searchText: String) {
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: postLocation.coordinate, latitudinalMeters: 5_000, longitudinalMeters: 5_000)
        search.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.atm, .carRental, .evCharger, .parking, .police])

        let searcher = MKLocalSearch(request: search)
        searcher.start { [weak self] response, error in

            guard let self = self else { return }
            if error != nil { self.reloadResultsTable(searchText: searchText) }
            if !self.queryValid(searchText: searchText) { self.spotSearching = false; return }
            guard let response = response else { self.reloadResultsTable(searchText: searchText); return }

            for item in response.mapItems {
                if let spotName = item.name {
                    /// spot was already appended for this POI
                    if self.querySpots.contains(where: {
                        $0.spotName == spotName ||
                        ($0.phone ?? "" == item.phoneNumber ?? ""
                         && item.phoneNumber ?? "" != "") }) {
                        continue
                    }

                    var spotInfo = MapSpot(
                        id: UUID().uuidString,
                        founderID: "",
                        mapItem: item,
                        imageURL: "",
                        videoURL: "",
                        spotName: spotName,
                        privacyLevel: "public"
                    )

                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))

                    self.querySpots.append(spotInfo)
                }
            }
            self.reloadResultsTable(searchText: searchText)
        }
    }

    func runNearbyQuery(searchText: String) {

        let spotsRef = db.collection("spots")
        let spotsQuery = spotsRef.whereField("searchKeywords", arrayContains: searchText.lowercased()).limit(to: 10)

        spotsQuery.getDocuments { [weak self] (snap, _) in

            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { self.spotSearching = false; return }

            if docs.isEmpty { self.reloadResultsTable(searchText: searchText) }
            
            for doc in docs {
                /// get all spots that match query and order by distance
                let info = try? doc.data(as: MapSpot.self)
                guard let spotInfo = info else { return }
                if spotInfo.showSpotOnMap() {
                    self.addSpot(spot: spotInfo, query: true)
                }
            }
            
            self.reloadResultsTable(searchText: searchText )
        }
    }

    func reloadResultsTable(searchText: String) {
        searchRefreshCount += 1
        if searchRefreshCount < 2 { return }

        querySpots.sort(by: { $0.distance < $1.distance })
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func queryValid(searchText: String) -> Bool {
        /// check that search text didnt change and "spots" seg still selected
        return searchText == searchTextGlobal && searchText != ""
    }
}
