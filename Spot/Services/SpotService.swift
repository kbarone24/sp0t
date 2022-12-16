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
                    
                    do {
                        guard var spotInfo = try doc.data(as: MapSpot.self) else {
                            continuation.resume(returning: nil)
                            return
                        }
                        for visitor in spotInfo.visitorList where UserDataModel.shared.userInfo.friendIDs.contains(visitor) {
                            spotInfo.friendVisitors += 1
                        }
                        
                        continuation.resume(returning: spotInfo)
                        
                    } catch {
                        continuation.resume(throwing: error)
                    }
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

                    do {
                        guard let spotInfo = try doc.data(as: MapSpot.self) else { continue }
                        spots.append(spotInfo)
                    } catch {
                        continue
                    }
                }
            }
        }
    }

    func getNearbySpots(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping (_ spots: [MapSpot]) -> Void) async {
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

        Task {
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
}
