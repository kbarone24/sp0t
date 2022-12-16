//
//  MapPostService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import CoreLocation
import GeoFire

protocol MapPostServiceProtocol {
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?)
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?)
    func getComments(postID: String) async throws -> [MapComment]
    func getPost(postID: String) async throws -> MapPost
    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void)
    func getNearbyPosts(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping([MapPost]) -> Void) async
}

final class MapPostService: MapPostServiceProtocol {
    
    enum MapPostServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FireBaseCollectionFields.mapID.rawValue, isEqualTo: mapID).order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    guard let snapshot, error == nil else {
                        completion?(error)
                        return
                    }
                    for doc in snapshot.documents {
                        doc.reference.updateData([FireBaseCollectionFields.inviteList.rawValue: FieldValue.arrayUnion(inviteList)])
                    }
                }
        }
    }
    
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?) {
        fireStore.collection(FirebaseCollectionNames.posts.rawValue)
            .whereField(FireBaseCollectionFields.posterID.rawValue, isEqualTo: friendID)
            .order(by: FireBaseCollectionFields.timestamp.rawValue, descending: true)
            .getDocuments { snapshot, _ in
                guard let snapshot else {
                    completion?(false)
                    return
                }
                
                for doc in snapshot.documents {
                    let hideFromFeed = doc.get(FireBaseCollectionFields.hideFromFeed.rawValue) as? Bool ?? false
                    let privacyLevel = doc.get(FireBaseCollectionFields.privacyLevel.rawValue) as? String ?? "friends"
                    if !hideFromFeed && privacyLevel != "invite" {
                        doc.reference.updateData(
                            [
                                FireBaseCollectionFields.friendsList.rawValue: FieldValue.arrayUnion([userID])
                            ]
                        )
                    }
                }
                completion?(true)
            }
    }
    
    func getComments(postID: String) async throws -> [MapComment] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard !postID.isEmpty else {
                continuation.resume(returning: [])
                return
            }
            
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .collection(FireBaseCollectionFields.comments.rawValue)
                .order(by: FireBaseCollectionFields.timestamp.rawValue, descending: true)
                .getDocuments { snapshot, _ in
                    guard let snapshot,
                          !snapshot.documents.isEmpty
                    else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    Task {
                        var commentList: [MapComment] = []
                        
                        for doc in snapshot.documents {
                            
                            defer {
                                if doc == snapshot.documents.last {
                                    continuation.resume(returning: commentList)
                                }
                            }
                            
                            do {
                                let userService = try ServiceContainer.shared.service(for: \.userService)
                                guard var commentInfo = try doc.data(as: MapComment.self) else {
                                    continue
                                }
                                
                                if commentInfo.commenterID.isBlocked() {
                                    continue
                                }
                                
                                let userProfile = try await userService.getUserInfo(userID: commentInfo.commenterID)
                                commentInfo.userInfo = userProfile
                                if !commentList.contains(where: { $0.id == doc.documentID }) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: { $0.seconds < $1.seconds })
                                }
                                
                            } catch {
                                continue
                            }
                        }
                    }
                }
        }
    }
    
    func getPost(postID: String) async throws -> MapPost {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            var emptyPost = MapPost(
                spotID: "",
                spotName: "",
                mapID: "",
                mapName: ""
            )
            emptyPost.id = ""
            
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .getDocument { [weak self] doc, _ in
                    
                    do {
                        guard let postInfo = try doc?.data(as: MapPost.self) else {
                            continuation.resume(returning: emptyPost)
                            return
                        }
                        
                        self?.setPostDetails(post: postInfo) { post in
                            continuation.resume(returning: post)
                        }
                    } catch {
                        continuation.resume(returning: emptyPost)
                    }
                }
        }
    }
    
    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void) {
        guard let id = post.id, !id.isEmpty else {
            completion(post)
            return
        }
        
        Task {
            var postInfo = post
            
            let caption = postInfo.caption
            postInfo.captionHeight = caption.getCaptionHeight(fontSize: 14.5, maxCaption: 52)
            do {
                let userService = try ServiceContainer.shared.service(for: \.userService)
                let user = try await userService.getUserInfo(userID: post.posterID)
                postInfo.userInfo = user
                
                let comments = try await getComments(postID: id)
                postInfo.commentList = comments
                completion(postInfo)
                return
            } catch {
                completion(postInfo)
            }
        }
    }
    // function does NOT fetch user info
    func getPosts(query: Query) async throws -> [MapPost]? {
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
                    var posts: [MapPost] = []
                    for doc in docs {
                        defer {
                            if doc == docs.last {
                                continuation.resume(returning: posts)
                            }
                        }

                        do {
                            guard let postInfo = try doc.data(as: MapPost.self) else { continue }
                            posts.append(postInfo)
                        } catch {
                            continue
                        }
                    }
                }
            }
        }
    }

    func getNearbyPosts(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping(_ post: [MapPost]) -> Void) async {
        let queryBounds = GFUtils.queryBounds(
            forLocation: center,
            withRadius: radius)

        let queries = queryBounds.map { bound -> Query in
            return fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .order(by: "g")
                .start(at: [bound.startValue])
                .end(at: [bound.endValue])
                .limit(to: searchLimit)
        }

        Task {
            var allPosts: [MapPost] = []
            for query in queries {
                defer {
                    if query == queries.last {
                        completion(allPosts)
                    }
                }
                do {
                    let posts = try await getPosts(query: query)
                    guard let posts else { continue }
                    allPosts.append(contentsOf: posts)
                } catch {
                    continue
                }
            }
        }
    }
}
