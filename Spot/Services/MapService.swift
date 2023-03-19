//
//  MapService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseFunctions

// This is what will be used for app map API calls going forward

protocol MapServiceProtocol {
    func fetchTopMaps(limit: Int) async throws -> [CustomMap]
    func fetchMapPosts(id: String, limit: Int) async throws -> [MapPost]
    func followMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void))
    func leaveMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void))
    func addNewUsersToMap(customMap: CustomMap, addedUsers: [String])
    func getMap(mapID: String) async throws -> CustomMap
    func uploadMap(map: CustomMap, newMap: Bool, post: MapPost, spot: MapSpot?)
    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void)
    func reportMap(mapID: String, feedbackText: String, userID: String)
    func getMapsFrom(query: Query) async throws -> [CustomMap]
}

final class MapService: MapServiceProtocol {
    
    enum MapServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    let emptyMap = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func fetchTopMaps(limit: Int)  async throws -> [CustomMap] {
        try await withUnsafeThrowingContinuation { [unowned self] continuation in
            
            self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
                .order(by: "lastPostTimestamp", descending: true)
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
                    
                    var maps: [CustomMap] = []
                    
                    snapshot.documents.forEach { document in
                        if var map = try? document.data(as: CustomMap.self) {
                            if !map.secret {
                                map.setAdjustedMapScore()
                                maps.append(map)
                            }
                        }
                    }
                    
                    continuation.resume(returning: maps)
                }
        }
    }
    
    func fetchMapPosts(id: String, limit: Int) async throws -> [MapPost] {
        try await withUnsafeThrowingContinuation { [unowned self] continuation in
            
            self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: id)
                .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
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
    
    func followMap(customMap: CustomMap, completion: @escaping ((Error?) -> Void)) {
        guard let mapID = customMap.id,
              case let userId = UserDataModel.shared.uid
        else {
            completion(nil)
            return
        }
        var dataUpdate: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([userId])]
        if customMap.communityMap ?? false {
            dataUpdate[FirebaseCollectionFields.memberIDs.rawValue] = FieldValue.arrayUnion([userId])
        }
        self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
            .document(mapID)
            .updateData(
                dataUpdate
            ) { error in
                completion(error)
            }
        
        let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService)
        mapPostService?.updatePostInviteLists(mapID: mapID, inviteList: [UserDataModel.shared.uid], completion: nil)

        incrementMapScore(mapID: mapID, increment: 10)
        sendMapJoinNotifications(map: customMap)
    }

    func addNewUsersToMap(customMap: CustomMap, addedUsers: [String]) {
        guard let mapID = customMap.id else { return }
        self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
            .document(mapID)
            .updateData(
                [
                    FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion(addedUsers),
                    FirebaseCollectionFields.memberIDs.rawValue: FieldValue.arrayUnion(addedUsers)
                ]
            )
        let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService)
        mapPostService?.updatePostInviteLists(mapID: mapID, inviteList: addedUsers, completion: nil)

        let functions = Functions.functions()
        functions.httpsCallable("sendMapInviteNotifications").call([
            "imageURL": customMap.imageURL,
            "mapID": customMap.id ?? "",
            "mapName": customMap.mapName,
            "postID": customMap.postIDs.first ?? "",
            "receiverIDs": addedUsers,
            "senderID": UserDataModel.shared.uid,
            "senderUsername": UserDataModel.shared.userInfo.username]) { result, error in
            print(result?.data as Any, error as Any)
        }
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
                    FirebaseCollectionFields.likers.rawValue: FieldValue.arrayRemove([userId]),
                    FirebaseCollectionFields.memberIDs.rawValue: FieldValue.arrayRemove([userId])
                ]
            ) { error in
                completion(error)
            }
        incrementMapScore(mapID: mapID, increment: -10)
    }
    
    func getMap(mapID: String) async throws -> CustomMap {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard mapID != "" else {
                continuation.resume(returning: emptyMap)
                return
            }
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
                    .document(mapId)
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
                        "videoURL": post.videoURL ?? "",
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
    
    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        guard !mapID.isEmpty else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID)
                .getDocuments { snap, _ in
                    var postCount = 0
                    var mapDelete = false
                    for doc in snap?.documents ?? [] {
                        if !UserDataModel.shared.deletedPostIDs.contains(where: { $0 == doc.documentID }) {
                            postCount += 1
                        }
                        
                        if doc == snap?.documents.last {
                            mapDelete = postCount == 1
                        }
                    }
                    
                    if mapDelete { UserDataModel.shared.deletedMapIDs.append(mapID) }
                    completion(mapDelete)
                }
        }
    }

    func reportMap(mapID: String, feedbackText: String, userID: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection("feedback")
                .addDocument(
                    data: [
                        "feedbackText": feedbackText,
                        "mapID": mapID,
                        "type": "reportMap",
                        "userID": userID
                    ]
                )
        }
    }

    func getMapsFrom(query: Query) async throws -> [CustomMap] {
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
                Task {
                    var maps = [CustomMap]()
                    for doc in docs {
                        do {
                            let map = try doc.data(as: CustomMap.self) as CustomMap
                            maps.append(map)
                        } catch {
                            continue
                        }
                    }
                    continuation.resume(returning: maps)
                }
            }
        }
    }

    private func incrementMapScore(mapID: String, increment: Int) {
        DispatchQueue.global(qos: .background).async {
            self.fireStore.collection(FirebaseCollectionNames.maps.rawValue).document(mapID).updateData(["mapScore": FieldValue.increment(Int64(increment))])
        }
    }

    private func sendMapJoinNotifications(map: CustomMap) {
        guard let mapID = map.id,
              let postID = map.postIDs[safe: 0] else { return }
        let type = map.communityMap ?? false ? "mapJoin" : "mapFollow"

        let data: [String: Any] = [
            "imageURL": map.imageURL,
            "postID": postID,
            "seen": false,
            "mapID": mapID,
            "mapName": map.mapName,
            "senderID": UserDataModel.shared.uid,
            "senderUsername": UserDataModel.shared.userInfo.username,
            "timestamp": Timestamp(),
            "type": type,
        ]

        fireStore.collection(FirebaseCollectionNames.users.rawValue).document(map.founderID).collection(FirebaseCollectionNames.notifications.rawValue).addDocument(data: data)
    }
}
