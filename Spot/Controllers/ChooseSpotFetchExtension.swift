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

extension ChooseSpotController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        searchTextGlobal = searchText
        emptySpotQueries()
        DispatchQueue.main.async { self.tableView.reloadData() }

        if queried {
            runSpotSearch(searchText: searchText)
        } else {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runSpotQuery), object: nil)
        }
    }
}

extension ChooseSpotController {
    func runChooseSpotFetch() {
        // called initially and also after an image is selected
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() } /// shows loading indicator

        queryReady = false
        nearbyEnteredCount = 0 /// total number of spots in the circle query
        noAccessCount = 0 /// no privacy access ct
        appendCount = 0 /// spots appended on this fetch
        nearbyRefreshCount = 0 /// incremented once with POI load, once with Spot load

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

            var index = 0

            for item in response.mapItems {

                if item.pointOfInterestCategory != nil, let poiName = item.name {
                    let phone = item.phoneNumber ?? ""
                    let name = poiName.count > 60 ? String(poiName.prefix(60)) : poiName

                    /// check for spot duplicate
                    if self.spotObjects.contains(where: { $0.spotName == name || ($0.phone ?? "" == phone && phone != "") }) {
                        index += 1
                        if index == response.mapItems.count {
                            self.endQuery()
                        }
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

                    let spotLocation = CLLocation(
                        latitude: spotInfo.spotLat,
                        longitude: spotInfo.spotLong
                    )
                    let postLocation = CLLocation(
                        latitude: UploadPostModel.shared.postObject?.postLat ?? 0,
                        longitude: UploadPostModel.shared.postObject?.postLong ?? 0
                    )
                    spotInfo.distance = postLocation.distance(from: spotLocation)
                    spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)

                    self.spotObjects.append(spotInfo)

                    index += 1; if index == response.mapItems.count { self.endQuery() }

                } else {
                    index += 1; if index == response.mapItems.count { self.endQuery() }
                }
            }
        }
    }

    func getNearbySpots() {
        let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject?.postLat ?? 0, longitude: UploadPostModel.shared.postObject?.postLong ?? 0)

        circleQuery = geoFirestore.query(withCenter: postLocation, radius: 0.5)
        _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)

        _ = circleQuery?.observeReady { [weak self] in
            guard let self = self else { return }
            if self.cancelOnDismiss { return }

            self.queryReady = true

            /// observe ready is sometimes called after all spots loaded, sometimes before due to async nature. Reload here if no spots entered or load is finished
            if self.nearbyEnteredCount == 0 {
                self.endQuery()

            } else if self.noAccessCount + self.appendCount == self.nearbyEnteredCount {
                self.endQuery()
            }
        }
    }

    func loadSpotFromDB(key: String?, location: CLLocation?) {
        guard let spotKey = key else { accessEscape(); return }
        nearbyEnteredCount += 1

        Task {
            guard var spotInfo = try? await spotService?.getSpot(spotID: spotKey) else {
                noAccessCount += 1
                accessEscape()
                return
            }

            if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject?.postLat ?? 0, longitude: UploadPostModel.shared.postObject?.postLong ?? 0)
                let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)

                spotInfo.distance = spotLocation.distance(from: postLocation)
                spotInfo.spotScore = spotInfo.getSpotRank(location: postLocation)

                if spotInfo.privacyLevel != "public" {
                    spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"

                } else {
                    spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                }

                /// replace POI with actual spot object if object already added
                /// Use phone number for second degree matching
                if let i = self.spotObjects.firstIndex(where: { $0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                    spotInfo.selected = self.spotObjects[i].selected
                    self.spotObjects[i] = spotInfo
                    self.spotObjects[i].poiCategory = nil
                    self.noAccessCount += 1; self.accessEscape(); return
                }

                self.appendCount += 1
                self.spotObjects.append(spotInfo)
                self.accessEscape()
                return

            } else {
                self.noAccessCount += 1
                self.accessEscape()
            }
        }
    }

    func accessEscape() {
        if noAccessCount + appendCount == nearbyEnteredCount && queryReady { endQuery() }
        return
    }

    func endQuery() {
        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        spotObjects.sort(by: { !($0.selected ?? false) && !($1.selected ?? false) ? $0.spotScore > $1.spotScore : ($0.selected ?? false) && !($1.selected ?? false) })

        circleQuery?.removeAllObservers()
        circleQuery = nil

        search = nil
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    // search funcs

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

            var index = 0

            for item in response.mapItems {

                if item.name != nil {

                    /// spot was already appended for this POI
                    if self.querySpots.contains(where: {
                        $0.spotName == item.name ||
                        ($0.phone ?? "" == item.phoneNumber ?? ""
                         && item.phoneNumber ?? "" != "") }) {
                        index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }

                    var spotInfo: MapSpot
                    let spotName: String

                    if let name = item.name {
                        spotName = String(name.prefix(60))
                    } else {
                        spotName = ""
                    }

                    spotInfo = MapSpot(
                        id: UUID().uuidString,
                        founderID: "",
                        mapItem: item,
                        imageURL: "",
                        spotName: spotName,
                        privacyLevel: "public"
                    )

                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))

                    self.querySpots.append(spotInfo)
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }

                } else {
                    index += 1
                    if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }
                }
            }
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

                do {
                    /// get all spots that match query and order by distance
                    let info = try doc.data(as: MapSpot.self)
                    guard var spotInfo = info else { return }
                    spotInfo.id = doc.documentID

                    if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {

                        spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))

                        for visitor in spotInfo.visitorList where UserDataModel.shared.userInfo.friendIDs.contains(visitor) {
                            spotInfo.friendVisitors += 1
                        }

                        if spotInfo.privacyLevel != "public" {
                            spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"

                        } else {
                            spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                        }

                        /// replace duplicate POI with correct spotObject
                        if let i = self.querySpots.firstIndex(where: { $0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                            self.querySpots[i] = spotInfo
                            self.querySpots[i].poiCategory = nil
                        } else {
                            self.querySpots.append(spotInfo)
                        }
                    }

                    if doc == docs.last {
                        self.reloadResultsTable(searchText: searchText)
                    }

                } catch { if doc == docs.last {
                    self.reloadResultsTable(searchText: searchText) }; return }
            }
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
