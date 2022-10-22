//
//  MapService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation

// This is what will be used for app map API calls going forward

protocol MapServiceProtocol {
    func fetchMaps() async throws -> [CustomMap]
    func fetchMapPosts() async throws -> [MapPost]
}

final class MapService: MapServiceProtocol {

    private let fireStore: Firestore

    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }

    // TODO: We will have to filter for location

    func fetchMaps()  async throws -> [CustomMap] {
        withUnsafeThrowingContinuation { [unowned self] _ in

            self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
                .whereField(FireBaseCollectionFields.communityMap.rawValue, isEqualTo: true)
                .getDocuments { (snap, _) in
                // handle error
                for doc in snap.documents {
                  do {
                      let mapIn = try doc.data(as: [CustomMap].self)
                      guard var mapInfo = mapIn else { continue }
                    } catch {
                        continue
                    }
                }
                }
        }
    }

    func fetchMapPosts() async throws -> [MapPost] {

    }
}
