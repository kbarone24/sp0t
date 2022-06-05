//
//  PostInfoExtension.swift
//  Spot
//
//  Created by Kenny Barone on 5/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Geofirestore
import MapKit
import CoreLocation

extension PostInfoController {
    
    func runChooseSpotFetch() {
        /// called initially and also after an image is selected
        print("run fetch")
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
        
        if search != nil { search.cancel() }
        let searchRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong), radius: 200)
                
        /// these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
        let filters = MKPointOfInterestFilter(including: searchFilters)
        searchRequest.pointOfInterestFilter = filters
        
        runPOIFetch(request: searchRequest)
    }
    
    /// recursive func called with an increasing radius -> Ensure always fetching the closest POI's since max limit is 25
    func runPOIFetch(request: MKLocalPointsOfInterestRequest) {
        
        if search != nil { search.cancel() }
        search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { return }
            
            let newRequest = MKLocalPointsOfInterestRequest(center: CLLocationCoordinate2D(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong), radius: request.radius * 2)
            newRequest.pointOfInterestFilter = request.pointOfInterestFilter
            
            /// if the new radius won't be greater than about 1.5 miles then run poi fetch to get more nearby stuff
            guard let response = response else {
                /// error usually means no results found
                newRequest.radius < 3000 ? self.runPOIFetch(request: newRequest) : self.endQuery()
                return
            }
            
            /// > 10 poi's should be enough for the table, otherwise re-run fetch
            if response.mapItems.count < 10 && newRequest.radius < 3000 {   self.runPOIFetch(request: newRequest); return }
            
            var index = 0
            
            for item in response.mapItems {
                
                if item.pointOfInterestCategory != nil && item.name != nil {
                    
                    let phone = item.phoneNumber ?? ""
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                    
                    /// check for spot duplicate
                    if self.spotObjects.contains(where: {$0.spotName == name || ($0.phone ?? "" == phone && phone != "")}) { index += 1; if index == response.mapItems.count { self.endQuery() }; continue }
                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    spotInfo.phone = phone
                    spotInfo.poiCategory = item.pointOfInterestCategory?.toString() ?? ""
                    spotInfo.id = UUID().uuidString
                    
                    let spotLocation = CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong)
                    let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
                    
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
        
        let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
        
        if circleQuery == nil {
            /// radius between 0.5 and 100.0
            circleQuery = geoFirestore.query(withCenter: CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong), radius: 0.5)
            let _ = self.circleQuery?.observe(.documentEntered, with: self.loadSpotFromDB)
        
        } else {
            /// active listener will account for change
            circleQuery?.center = postLocation
            circleQuery?.radius = 0.5
            return
        }

        let _ = circleQuery?.observeReady { [weak self] in

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
        guard let coordinate = location?.coordinate else { accessEscape(); return }
                
        nearbyEnteredCount += 1

        let ref = db.collection("spots").document(spotKey)
        ref.getDocument { [weak self] (doc, err) in
            
            guard let self = self else { return }
            if self.cancelOnDismiss { return }
            
            do {
                
                let unwrappedInfo = try doc?.data(as: MapSpot.self)
                guard var spotInfo = unwrappedInfo else { self.noAccessCount += 1; self.accessEscape(); return }
                spotInfo.id = ref.documentID
                
                spotInfo.spotLat = coordinate.latitude
                spotInfo.spotLong = coordinate.longitude
                spotInfo.spotDescription = "" /// remove spotdescription, no use for it here, will either be replaced with POI description or username
                for visitor in spotInfo.visitorList {
                    if UserDataModel.shared.friendIDs.contains(visitor) { spotInfo.friendVisitors += 1 }
                }
                
                if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                    
                    let postLocation = CLLocation(latitude: UploadPostModel.shared.postObject.postLat, longitude: UploadPostModel.shared.postObject.postLong)
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
                    if let i = self.spotObjects.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
                        spotInfo.selected = self.spotObjects[i].selected
                        self.spotObjects[i] = spotInfo
                        self.spotObjects[i].poiCategory = nil
                        self.noAccessCount += 1; self.accessEscape(); return
                    }
                    
                    self.appendCount += 1
                    self.spotObjects.append(spotInfo)
                    self.accessEscape()
                    
                } else { self.noAccessCount += 1; self.accessEscape(); return }
            } catch { self.noAccessCount += 1; self.accessEscape(); return }
        }
    }
    
    
    func accessEscape() {
        if noAccessCount + appendCount == nearbyEnteredCount && queryReady { endQuery() }
    }
    
    func endQuery() {

        nearbyRefreshCount += 1
        if nearbyRefreshCount < 2 { return } /// avoid refresh on the initial POI fetch for smoother tableView loading
        spotObjects.sort(by: {!$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected!})
        
        circleQuery = nil
        search = nil
        spotSearching = false
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    // search funcs
    
    func runSpotSearch(searchText: String) {
        
        emptySpotQueries()
        spotSearching = true
        DispatchQueue.main.async { self.tableView.reloadData() }
                
        /// cancel search requests after user stops typing for 0.65/sec
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runSpotQuery), object: nil)
        self.perform(#selector(runSpotQuery), with: nil, afterDelay: 0.65)
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
        searchRefreshCount = 0
        querySpots.removeAll()
    }
    
    func runPOIQuery(searchText: String) {
    
        let search = MKLocalSearch.Request()
        search.naturalLanguageQuery = searchText
        search.resultTypes = .pointOfInterest
        search.region = MKCoordinateRegion(center: postLocation.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
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
                    if self.querySpots.contains(where: {$0.spotName == item.name || ($0.phone ?? "" == item.phoneNumber ?? "" && item.phoneNumber ?? "" != "")}) { index += 1; if index == response.mapItems.count { self.reloadResultsTable(searchText: searchText) }; continue }
                                        
                    let name = item.name!.count > 60 ? String(item.name!.prefix(60)) : item.name!
                                    
                    var spotInfo = MapSpot(spotDescription: item.pointOfInterestCategory?.toString() ?? "", spotName: name, spotLat: item.placemark.coordinate.latitude, spotLong: item.placemark.coordinate.longitude, founderID: "", privacyLevel: "public", imageURL: "")
                    
                    spotInfo.phone = item.phoneNumber ?? ""
                    spotInfo.id = UUID().uuidString
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
                
        spotsQuery.getDocuments { [weak self] (snap, err) in
                        
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { self.spotSearching = false; return }
            
            if docs.count == 0 { self.reloadResultsTable(searchText: searchText) }

            for doc in docs {

                do {
                    /// get all spots that match query and order by distance
                    let info = try doc.data(as: MapSpot.self)
                    guard var spotInfo = info else { return }
                    spotInfo.id = doc.documentID
                    
                    if self.hasPOILevelAccess(creatorID: spotInfo.founderID, privacyLevel: spotInfo.privacyLevel, inviteList: spotInfo.inviteList ?? []) {
                        
                        spotInfo.distance = self.postLocation.distance(from: CLLocation(latitude: spotInfo.spotLat, longitude: spotInfo.spotLong))

                        for visitor in spotInfo.visitorList {
                            if UserDataModel.shared.friendIDs.contains(visitor) { spotInfo.friendVisitors += 1 }
                        }


                        if spotInfo.privacyLevel != "public" {
                            spotInfo.spotDescription = spotInfo.posterUsername == "" ? "" : "By \(spotInfo.posterUsername ?? "")"
                            
                        } else {
                            spotInfo.spotDescription = spotInfo.poiCategory ?? ""
                        }
                        
                        /// replace duplicate POI with correct spotObject
                        if let i = self.querySpots.firstIndex(where: {$0.spotName == spotInfo.spotName || ($0.phone == spotInfo.phone ?? "" && spotInfo.phone ?? "" != "") }) {
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
        
        print(querySpots.map({$0.distance}))
        querySpots.sort(by: {$0.distance < $1.distance})

        spotSearching = false
        
        DispatchQueue.main.async { self.tableView.reloadData() }
    }
    
    func queryValid(searchText: String) -> Bool {
        /// check that search text didnt change and "spots" seg still selected
        return searchText == searchTextGlobal && searchText != "" && selectedSegmentIndex == 0
    }
    
    func runFriendSearch(searchText: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.queryFriends.removeAll()
            let usernameList = self.friendObjects.map({$0.username})
            let nameList = self.friendObjects.map({$0.name})
            
            let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
                // If dataItem matches the searchText, return true to include it
                return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
            })
            
            let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
                return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
            })
            
            for username in filteredUsernames {
                if let friend = self.friendObjects.first(where: {$0.username == username}) { self.queryFriends.append(friend) }
            }
            
            for name in filteredNames {
                if let friend = self.friendObjects.first(where: {$0.name == name}) {

                    if !self.queryFriends.contains(where: {$0.id == friend.id}) { self.queryFriends.append(friend) }
                }
            }

            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }
    
    func runTagSearch(searchText: String) {

        DispatchQueue.global().async {
            self.queryTags.removeAll()
            let tagNames = self.tagObjects.map({$0.name})
            
            let filteredNames = searchText.isEmpty ? tagNames : tagNames.filter({(dataString: String) -> Bool in
                // If dataItem matches the searchText, return true to include it
                return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
            })
            
            /// match tag object to tag name
            for name in filteredNames {
                if let tag = self.tagObjects.first(where: {$0.name == name}) {
                    self.queryTags.append(tag)
                }
            }
            
            DispatchQueue.main.async { self.tableView.reloadData() }
        }
    }

}
