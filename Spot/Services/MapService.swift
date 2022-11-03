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
    func fetchMapPosts(id: String, limit: Int) async throws -> [MapPost]
    func joinMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void))
}

final class MapService: MapServiceProtocol {
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func fetchMaps()  async throws -> [CustomMap] {
        try await withUnsafeThrowingContinuation { [unowned self] continuation in
            
            self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
                .whereField(FireBaseCollectionFields.communityMap.rawValue, isEqualTo: true)
                .getDocuments { snapshot, error in
                    
                    guard error == nil,
                          let snapshot = snapshot,
                          !snapshot.documents.isEmpty else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    var maps: [CustomMap] = []
                    
                    snapshot.documents.forEach { document in
                        do {
                            if let map = try document.data(as: CustomMap.self) {
                                maps.append(map)
                            }
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                    }
                    
                    continuation.resume(returning: maps)
                }
        }
    }
    
    func fetchMapPosts(id: String, limit: Int) async throws -> [MapPost] {
        try await withUnsafeThrowingContinuation { [unowned self] continuation in
            
            self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FireBaseCollectionFields.mapID.rawValue, isEqualTo: id)
                .order(by: FireBaseCollectionFields.timestamp.rawValue, descending: true)
                .limit(to: limit)
                .getDocuments { snapshot, error in
                    
                    guard error == nil,
                          let snapshot = snapshot,
                          !snapshot.documents.isEmpty else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    var posts: [MapPost] = []
                    
                    snapshot.documents.forEach { document in
                        do {
                            if let post = try document.data(as: MapPost.self) {
                                posts.append(post)
                            }
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                    }
                    
                    continuation.resume(returning: posts)
                }
        }
    }
    
    func joinMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void)) {
        guard let mapID = customMap.id,
              case let userId = UserDataModel.shared.uid
        else { return }
        
        self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
            .document(mapID)
            .updateData(
                [
                    FireBaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([userId]),
                    FireBaseCollectionFields.memberIDs.rawValue: FieldValue.arrayUnion([userId])
                ]
            ) { error in
                completion(error)
            }
    }
}
