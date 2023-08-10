//
//  SpotService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth
import Firebase
import GeoFire
import GeoFireUtils
import MapKit

protocol SpotServiceProtocol {
    func getSpot(spotID: String) async throws -> MapSpot?
    func getSpots(query: Query) async throws -> [MapSpot]?
    func runNearbySpotsFetch(radius: CLLocationDistance?) async throws -> [MapSpot]
    func fetchTopSpots(searchLimit: Int, returnLimit: Int) async throws -> [MapSpot]
    func uploadSpot(post: MapPost, spot: MapSpot)
    func setSeen(spot: MapSpot)
    func addUserToHereNow(spot: MapSpot)
    func removeUserFromHereNow(spot: MapSpot)

    func getNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping([MapSpot]) -> Void) async
    func checkForSpotRemove(spotID: String, mapID: String, completion: @escaping(_ remove: Bool) -> Void)
    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void)
    func getSpotsFrom(searchText: String, limit: Int) async throws -> [MapSpot]
    func getAllSpots() async throws -> [MapSpot]
}

final class SpotService: SpotServiceProtocol {
    
    private let fireStore: Firestore

    // note: these filters will omit POI's with nil as their category. This can occasionally exclude some desirable POI's but primarily excludes junk
    let searchFilters: [MKPointOfInterestCategory] = [
        .airport,
        .amusementPark,
        .aquarium,
        .bakery,
        .beach,
        .brewery,
        .cafe,
        .campground,
        .foodMarket,
        .library,
        .marina,
        .museum,
        .movieTheater,
        .nightlife,
        .nationalPark,
        .park,
        .restaurant,
        .store,
        .school,
        .stadium,
        .theater,
        .university,
        .winery,
        .zoo
    ]
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func getSpot(spotID: String) async throws -> MapSpot? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                .document(spotID)
                .getDocument { doc, error in
                    guard error == nil, let doc
                    else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    guard let spotInfo = try? doc.data(as: MapSpot.self) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    continuation.resume(returning: spotInfo)
                }
        }
    }
    
    func getSpots(query: Query) async throws -> [MapSpot]? {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snap, error in
                guard error == nil, let docs = snap?.documents, !docs.isEmpty
                else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: [])
                    }
                    return
                }
                
                var spots: [MapSpot] = []
                for doc in docs {
                    defer {
                        if doc == docs.last {
                            continuation.resume(returning: spots)
                        }
                    }
                    
                    guard let spotInfo = try? doc.data(as: MapSpot.self) else { continue }
                    if spotInfo.showSpotOnMap() {
                        spots.append(spotInfo)
                    }
                }
            }
        }
    }

    func getSpotsFromLocation(query: Query, location: CLLocation) async throws -> [MapSpot]? {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                let snap = try await query.getDocuments()
                var spots: [MapSpot] = []
                for doc in snap.documents {
                    guard var spotInfo = try? doc.data(as: MapSpot.self) else { continue }
                    if spotInfo.showSpotOnMap() {
                        spotInfo.distance = spotInfo.location.distance(from: location)
                        spots.append(spotInfo)
                    }
                }
                continuation.resume(returning: spots)
            }
        }
    }

    func runNearbySpotsFetch(radius: CLLocationDistance?) async throws -> [MapSpot] {
        try await withUnsafeThrowingContinuation { continuation in
            Task(priority: .high) {
                let userLocation = UserDataModel.shared.currentLocation.coordinate
                var radius = radius ?? 50

                // 1. await-style get nearbySpots fetch
                let nearbySpots = try? await fetchNearbySpots(center: userLocation, radius: radius, searchLimit: 100)

                // 2. await-style get getNearbyPOI fetches
                let searchRequest = MKLocalPointsOfInterestRequest(
                    center: userLocation,
                    radius: radius
                )

                let filters = MKPointOfInterestFilter(including: searchFilters)
                searchRequest.pointOfInterestFilter = filters
                let nearbyPOIs = try? await fetchNearbyPOIs(request: searchRequest)

                // 3. remove duplicates
                var allSpots = nearbySpots ?? []
                for poi in nearbyPOIs ?? [] {
                    if !(allSpots.contains(where: {
                        $0.spotName == poi.spotName ||
                        ($0.phone == poi.phone ?? "" && poi.phone ?? "" != "") })) {
                        allSpots.append(poi)
                    }
                }

                // 4. re-run fetches with wider radius if < 3, stop running at 3000m
                guard allSpots.count > 3 || radius > 3_000 else {
                    radius *= 2
                    _ = try await runNearbySpotsFetch(radius: radius)
                    return
                }

                // 5. rank spots (+ add distance, spotscore) and return
                allSpots.sort(by: { $0.spotScore > $1.spotScore })
                continuation.resume(returning: allSpots)
            }
        }
    }

    private func fetchNearbyPOIs(request: MKLocalPointsOfInterestRequest)  async throws -> [MapSpot]? {
        try await withUnsafeThrowingContinuation { continuation in
            let search = MKLocalSearch(request: request)
            search.start { response, _ in
                guard let response else {
                    continuation.resume(returning: [])
                    return
                }

                var spotObjects = [MapSpot]()
                for item in response.mapItems {
                    if item.pointOfInterestCategory != nil, let poiName = item.name {
                        let phone = item.phoneNumber ?? ""
                        let name = poiName.count > 60 ? String(poiName.prefix(60)) : poiName

                        var spotInfo = MapSpot(
                            id: UUID().uuidString,
                            founderID: "",
                            mapItem: item,
                            imageURL: "",
                            spotName: name,
                            privacyLevel: "public"
                        )
                        spotInfo.distance = spotInfo.location.distance(from: request.coordinate.location)
                        spotObjects.append(spotInfo)
                    }
                }
                continuation.resume(returning: spotObjects)
            }

        }
    }

    private func fetchNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int) async throws -> [MapSpot]? {
        try await withUnsafeThrowingContinuation { continuation in
            let queryBounds = GFUtils.queryBounds(
                forLocation: center,
                withRadius: radius)
            let queries = queryBounds.map { bound -> Query in
                return self.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .order(by: "g")
                    .start(at: [bound.startValue])
                    .end(at: [bound.endValue])
                    .limit(to: searchLimit)
            }

            Task {
                var allSpots: [MapSpot] = []
                for query in queries {
                    defer {
                        if query == queries.last {
                            continuation.resume(returning: allSpots)
                        }
                    }
                    do {
                        let spots = try await self.getSpotsFromLocation(query: query, location: center.location)
                        guard let spots else { continue }
                        allSpots.append(contentsOf: spots)
                    } catch {
                        continue
                    }
                }
            }
        }
    }

    func fetchTopSpots(searchLimit: Int, returnLimit: Int) async throws -> [MapSpot] {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                let city = await ServiceContainer.shared.locationService?.getCityFromLocation(location: UserDataModel.shared.currentLocation, zoomLevel: .cityAndState)
                guard let city, city != "" else {
                    continuation.resume(returning: [])
                    return
                }

                let query = fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .whereField(SpotCollectionFields.city.rawValue, isEqualTo: city)
                    .order(by: SpotCollectionFields.lastPostTimestamp.rawValue, descending: true)
                    .limit(to: searchLimit)
                

                var allSpots = [MapSpot]()
                let snap = try await query.getDocuments()
                for doc in snap.documents {
                    guard var spot = try? doc.data(as: MapSpot.self) else { continue }
                    if spot.showSpotOnMap() {
                        spot.setSpotRank()
                        allSpots.append(spot)
                    }
                }

                allSpots.sort(by: { $0.spotRank > $1.spotRank })
                let finalSpots = Array(allSpots.prefix(returnLimit))
                continuation.resume(returning: finalSpots)
            }
        }
    }

    func getNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping (_ spots: [MapSpot]) -> Void) async {
        Task {
            let queryBounds = GFUtils.queryBounds(
                forLocation: center,
                withRadius: radius)
            let queries = queryBounds.map { bound -> Query in
                return fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .order(by: "g")
                    .start(at: [bound.startValue])
                    .end(at: [bound.endValue])
                    .limit(to: searchLimit)
            }
            
            var allSpots: [MapSpot] = []
            for query in queries {
                defer {
                    if query == queries.last {
                        completion(allSpots)
                    }
                }
                do {
                    let spots = try await getSpots(query: query)
                    guard let spots else { continue }
                    allSpots.append(contentsOf: spots)
                } catch {
                    continue
                }
            }
        }
    }
    
    func uploadSpot(post: MapPost, spot: MapSpot) {
        guard let postID = post.id,
              let spotID = spot.id else {
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            if spot.createdFromPOI {
                // create new spot from poi
                Task {
                    var spot = spot
                    spot.setUploadValuesFor(post: post)
                    try? self.fireStore.collection("spots")
                        .document(spotID)
                        .setData(from: spot)
                }
            } else {
                /// run spot transactions
                var posters = post.taggedUserIDs ?? []
                posters.append(UserDataModel.shared.uid)
                
                let functions = Functions.functions()
                let parameters = [
                    "spotID": spotID,
                    "postID": postID,
                    "mapID": "",
                    "uid": UserDataModel.shared.uid,
                    "postPrivacy": post.privacyLevel ?? "public",
                    "posters": posters,

                    "caption": post.caption,
                    "imageURL": post.imageURLs.first ?? "",
                    "videoURL": post.videoURL ?? "",
                    "username": UserDataModel.shared.userInfo.username
                ] as [String: Any]
                
                Task {
                    try? await functions.httpsCallable("runSpotTransactions").call(parameters)
                }
            }
        }
    }

    func setSeen(spot: MapSpot) {
        guard let spotID = spot.id, spotID != "" else { return }
        var values: [String: Any] = [
            SpotCollectionFields.seenList.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid]),
        ]
        if spot.userInRange() {
            values[SpotCollectionFields.visitorList.rawValue] = FieldValue.arrayUnion([UserDataModel.shared.uid])
        }
        fireStore.collection(FirebaseCollectionNames.spots.rawValue).document(spotID).updateData(values)
    }

    func addUserToHereNow(spot: MapSpot) {
        if spot.userInRange(), let spotID = spot.id, spotID != "" {
            fireStore.collection(FirebaseCollectionNames.spots.rawValue).document(spotID).updateData([
                SpotCollectionFields.hereNow.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])
            ])
        }
    }

    func removeUserFromHereNow(spot: MapSpot) {
        if let spotID = spot.id, spotID != "" {
            fireStore.collection(FirebaseCollectionNames.spots.rawValue).document(spotID).updateData([
                SpotCollectionFields.hereNow.rawValue: FieldValue.arrayRemove([UserDataModel.shared.uid])
            ])
        }
    }

    func resetUserHereNow() {
        DispatchQueue.global(qos: .background).async {
            Task {
                let docs = try? await self.fireStore
                    .collection(FirebaseCollectionNames.spots.rawValue)
                    .whereField(SpotCollectionFields.hereNow.rawValue, arrayContains: UserDataModel.shared.uid)
                    .getDocuments()
                for doc in docs?.documents ?? [] {
                    self.removeUserFromHereNow(spotID: doc.documentID)
                }
            }
        }
    }

    func checkForSpotRemove(spotID: String, mapID: String, completion: @escaping(_ remove: Bool) -> Void) {
        guard !spotID.isEmpty, !mapID.isEmpty else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID)
                .whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID)
                .getDocuments { snap, _ in
                    completion(snap?.documents.count ?? 0 <= 1)
                }
        }
    }
    
    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void) {
        guard !spotID.isEmpty, !postID.isEmpty else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID)
                .getDocuments { snap, _ in
                    let spotDelete = snap?.documents.count ?? 0 == 1 && snap?.documents.first?.documentID ?? "" == postID
                    completion(spotDelete)
                }
        }
    }

    func getSpotsFrom(searchText: String, limit: Int) async throws -> [MapSpot] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                .whereField("searchKeywords", arrayContains: searchText.lowercased())
                .limit(to: limit)
                .getDocuments(completion: { snap, error in
                    guard let docs = snap?.documents, error == nil else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: [])
                        }
                        return
                    }

                    Task {
                        var spotList: [MapSpot] = []
                        for doc in docs {
                            guard let spotInfo = try? doc.data(as: MapSpot.self) else { continue }
                            if spotInfo.showSpotOnMap() {
                                spotList.append(spotInfo)
                            }
                        }
                        continuation.resume(returning: spotList)
                    }
                })
        }
    }

    func getAllSpots() async throws -> [MapSpot] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                .getDocuments(completion: { snap, error in
                    guard let docs = snap?.documents, error == nil else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: [])
                        }
                        return
                    }

                    Task {
                        var spotList: [MapSpot] = []
                        for doc in docs {
                            guard let spotInfo = try? doc.data(as: MapSpot.self) else { continue }
                            spotList.append(spotInfo)
                        }
                        continuation.resume(returning: spotList)
                    }
                })
        }
    }
}
