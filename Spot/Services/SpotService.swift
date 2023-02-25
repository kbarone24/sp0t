//
//  SpotService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import GeoFire

protocol SpotServiceProtocol {
    func getSpot(spotID: String) async throws -> MapSpot?
    func getNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping([MapSpot]) -> Void) async
    func uploadSpot(post: MapPost, spot: MapSpot, submitPublic: Bool)
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
                    print("error")
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
    
    func uploadSpot(post: MapPost, spot: MapSpot, submitPublic: Bool) {
        guard let postID = post.id,
              let spotID = spot.id,
              let uid: String = Auth.auth().currentUser?.uid else {
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            
            let interval = Date().timeIntervalSince1970
            let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))
            
            switch UploadPostModel.shared.postType {
            case .newSpot, .postToPOI:
                
                let lowercaseName = spot.spotName.lowercased()
                let keywords = lowercaseName.getKeywordArray()
                let geoHash = GFUtils.geoHash(forLocation: spot.location.coordinate)
                
                let tagDictionary: [String: Any] = [:]
                
                var spotVisitors = [uid]
                spotVisitors.append(contentsOf: post.addedUsers ?? [])
                
                var posterDictionary: [String: Any] = [:]
                posterDictionary[postID] = spotVisitors
                
                /// too many extreneous variables for spots to set with codable
                let spotValues = [
                    "city": post.city ?? "",
                    "spotName": spot.spotName,
                    "lowercaseName": lowercaseName,
                    "description": post.caption,
                    "createdBy": uid,
                    "posterUsername": UserDataModel.shared.userInfo.username,
                    "visitorList": spotVisitors,
                    "inviteList": spot.inviteList ?? [],
                    "privacyLevel": spot.privacyLevel,
                    "taggedUsers": post.taggedUsers ?? [],
                    "spotLat": spot.spotLat,
                    "spotLong": spot.spotLong,
                    "g": geoHash,
                    "imageURL": post.imageURLs.first ?? "",
                    "videoURL": post.videoURL ?? "",
                    "phone": spot.phone ?? "",
                    "poiCategory": spot.poiCategory ?? "",
                    "postIDs": [postID],
                    "postMapIDs": [post.mapID ?? ""],
                    "postTimestamps": [timestamp],
                    "posterIDs": [uid],
                    "postPrivacies": [post.privacyLevel ?? ""],
                    "searchKeywords": keywords,
                    "tagDictionary": tagDictionary,
                    "posterDictionary": posterDictionary
                ] as [String: Any]
                
                Task {
                    try? await self.fireStore.collection("spots")
                        .document(spotID)
                        .setData(spotValues, merge: true)
                    
                    if submitPublic {
                        try? await self.fireStore.collection("submissions")
                            .document(spot.id ?? "")
                            .setData(["spotID": spotID])
                    }
                    
                    var notiSpot = spot
                    notiSpot.checkInTime = Int64(interval)
                    NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot": notiSpot])
                    
                    /// add city to list of cities if this is the first post there
                    self.addToCityList(city: post.city ?? "")
                }
                
                /// increment users spot score by 6
            default:
                /// run spot transactions
                var posters = post.addedUsers ?? []
                posters.append(uid)
                
                let functions = Functions.functions()
                let parameters = [
                    "spotID": spotID,
                    "postID": postID,
                    "uid": uid,
                    "postPrivacy": post.privacyLevel ?? "friends",
                    "postTag": post.tag ?? "",
                    "posters": posters
                ] as [String: Any]
                
                Task {
                    try? await functions.httpsCallable("runSpotTransactions").call(parameters)
                }
            }
        }
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
}
