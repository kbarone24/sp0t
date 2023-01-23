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
    func leaveMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void))
    func getMap(mapID: String) async throws -> CustomMap
    func uploadMap(map: CustomMap, newMap: Bool, post: MapPost, spot: MapSpot?)
}

final class MapService: MapServiceProtocol {
    
    enum MapServiceError: Error {
        case decodingError
    }
    
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
                        if let map = try? document.data(as: CustomMap.self) {
                            maps.append(map)
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
                        if let post = try? document.data(as: MapPost.self) {
                            posts.append(post)
                        }
                    }
                    
                    continuation.resume(returning: posts)
                }
        }
    }
    
    func joinMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void)) {
        guard let mapID = customMap.id,
              case let userId = UserDataModel.shared.uid
        else {
            completion(nil)
            return
        }
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
        
        let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService)
        mapPostService?.updatePostInviteLists(mapID: mapID, inviteList: [UserDataModel.shared.uid], completion: nil)
    }
    
    func leaveMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void)) {
        guard let mapID = customMap.id,
              case let userId = UserDataModel.shared.uid
        else {
            completion(nil)
            return
        }
        
        self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
            .document(mapID)
            .updateData(
                [
                    FireBaseCollectionFields.likers.rawValue: FieldValue.arrayRemove([userId]),
                    FireBaseCollectionFields.memberIDs.rawValue: FieldValue.arrayRemove([userId])
                ]
            ) { error in
                completion(error)
            }
    }
    
    func getMap(mapID: String) async throws -> CustomMap {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
                .document(mapID)
                .getDocument { document, error in
                    guard error == nil, let document else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    guard let data = try? document.data(as: CustomMap.self) else {
                        continuation.resume(throwing: MapServiceError.decodingError)
                        return
                    }
                    
                    continuation.resume(returning: data)
                }
        }
    }
    
    func uploadMap(map: CustomMap, newMap: Bool, post: MapPost, spot: MapSpot?) {
        guard let mapId = map.id, let postId = post.id else {
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else {
                return
            }
            
            if newMap {
                let mapRef = self.fireStore
                    .collection(FirebaseCollectionNames.maps.rawValue)
                    .document(map.id!)
                try? mapRef.setData(from: map, merge: true)
                
            } else {
                /// update values with backend function
                let functions = Functions.functions()
                let postLocation = ["lat": post.postLat, "long": post.postLong]
                let spotLocation = ["lat": post.spotLat ?? 0.0, "long": post.spotLong ?? 0.0]
                var posters = [UserDataModel.shared.uid]
                
                if !(post.addedUsers?.isEmpty ?? true) {
                    posters.append(contentsOf: post.addedUsers ?? [])
                }
                
                functions.httpsCallable("runMapTransactions").call(
                    [
                        "mapID": mapId,
                        "uid": UserDataModel.shared.uid,
                        "poiCategory": spot?.poiCategory ?? "",
                        "postID": postId,
                        "postImageURL": post.imageURLs.first ?? "",
                        "postLocation": postLocation,
                        "posters": posters,
                        "posterUsername": UserDataModel.shared.userInfo.username,
                        "spotID": post.spotID ?? "",
                        "spotName": post.spotName ?? "",
                        "spotLocation": spotLocation
                    ]
                ) { _, _ in }
            }
            
            self.fireStore
                .collection(FirebaseCollectionNames.mapLocations.rawValue)
                .document(postId)
                .setData(
                    [
                        "mapID": mapId,
                        "postID": postId
                    ]
                )
        }
    }
}
