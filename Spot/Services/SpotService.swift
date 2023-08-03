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
    func getNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping([MapSpot]) -> Void) async
    func uploadSpot(post: MapPost, spot: MapSpot)
    func checkForSpotRemove(spotID: String, mapID: String, completion: @escaping(_ remove: Bool) -> Void)
    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void)
    func getSpotsFrom(searchText: String, limit: Int) async throws -> [MapSpot]
    func getAllSpots() async throws -> [MapSpot]
}

final class SpotService: SpotServiceProtocol {
    
    private let fireStore: Firestore
    
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
                    
                    guard var spotInfo = try? doc.data(as: MapSpot.self) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    for visitor in spotInfo.visitorList where UserDataModel.shared.userInfo.friendIDs.contains(visitor) {
                        spotInfo.friendVisitors += 1
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
                    spots.append(spotInfo)
                }
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
                    "mapID": post.mapID ?? "",
                    "uid": UserDataModel.shared.uid,
                    "postPrivacy": post.privacyLevel ?? "public",
                    "postTag": post.tag ?? "",
                    "posters": posters,

                    "caption": post.caption,
                    "imageURL": post.imageURLs.first ?? UIImage(),
                    "username": UserDataModel.shared.userInfo.username
                ] as [String: Any]
                
                Task {
                    try? await functions.httpsCallable("runSpotTransactions").call(parameters)
                }
            }
        }
    }

    private func getNewSpotDictionary(post: MapPost, postID: String, spot: MapSpot, spotID: String) -> [String: Any] {
        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))

        let lowercaseName = spot.spotName.lowercased()
        let keywords = lowercaseName.getKeywordArray()
        let geoHash = GFUtils.geoHash(forLocation: spot.location.coordinate)

        let tagDictionary: [String: Any] = [:]

        var spotVisitors = [UserDataModel.shared.uid]
        spotVisitors.append(contentsOf: post.taggedUserIDs ?? [])

        var posterDictionary: [String: Any] = [:]
        posterDictionary[postID] = spotVisitors

        /// too many extraneous variables for spots to set with codable
        var spotValues = [
            "city": post.city ?? "",
            "spotName": spot.spotName,
            "lowercaseName": lowercaseName,
            "description": post.caption,
            "createdBy": UserDataModel.shared.uid,
            "posterUsername": UserDataModel.shared.userInfo.username,
            "visitorList": spotVisitors,
            "inviteList": spot.inviteList ?? [],
            "privacyLevel": spot.privacyLevel,
            "taggedUsers": post.taggedUsers ?? [],
            "spotLat": spot.spotLat,
            "spotLong": spot.spotLong,
            "g": geoHash,
            "imageURL": post.imageURLs.first ?? "",
            "phone": spot.phone ?? "",
            "poiCategory": spot.poiCategory ?? "",
            "searchKeywords": keywords,
            "hereNow": []
        ] as [String: Any]

        let postValues = [
            "postIDs": [postID],
            "postMapIDs": [post.mapID ?? ""],
            "postTimestamps": [timestamp],
            "posterIDs": [UserDataModel.shared.uid],
            "postPrivacies": [post.privacyLevel ?? ""],
            "tagDictionary": tagDictionary,
            "posterDictionary": posterDictionary,

            "lastPostTimestamp": timestamp,
            "postCaptions": [post.caption],
            "postImageURLs": [post.imageURLs.first ?? ""],
            "postCommentCounts": [0],
            "postLikeCounts": [0],
            "postSeenCounts": [0],
            "postUsernames": [UserDataModel.shared.userInfo.username]
        ] as [String: Any]

        spotValues.merge(postValues) { (_, new) in new }
        return spotValues
    }
    
    private func addToCityList(city: String) {
        let query = fireStore.collection("cities").whereField("cityName", isEqualTo: city)
        
        query.getDocuments { [weak self] (cityDocs, _) in
            if cityDocs?.documents.count ?? 0 == 0 {
                city.getCoordinate { coordinate, error in
                    guard let coordinate = coordinate, error == nil else {
                        return
                    }
                    
                    let g = GFUtils.geoHash(forLocation: coordinate)
                    self?.fireStore.collection("cities")
                        .document(UUID().uuidString)
                        .setData(["cityName": city, "g": g])
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
                            spotList.append(spotInfo)
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
