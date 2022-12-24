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
    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool) async
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
                                guard var commentInfo = try? doc.data(as: MapComment.self) else {
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
        
        let captionHeight = post.caption.getCaptionHeight(fontSize: 14.5, maxCaption: 52)
        
        Task {
            var postInfo = post
            postInfo.captionHeight = captionHeight
            
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
                            guard let postInfo = try? doc.data(as: MapPost.self) else { continue }
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
        
        Task {
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
    
    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool) async {
        /// send local notification first
        guard let postID = post.id else { return }
        
        Task {
            let caption = post.caption
            var notiPost = post
            notiPost.id = postID
            
            let commentObject = MapComment(
                id: UUID().uuidString,
                comment: caption,
                commenterID: post.posterID,
                taggedUsers: post.taggedUsers,
                timestamp: post.timestamp,
                userInfo: UserDataModel.shared.userInfo
            )
            
            notiPost.commentList = [commentObject]
            notiPost.captionHeight = caption.getCaptionHeight(fontSize: 14.5, maxCaption: 52)
            notiPost.userInfo = UserDataModel.shared.userInfo
            
            NotificationCenter.default.post(
                Notification(
                    name: Notification.Name("NewPost"),
                    object: nil,
                    userInfo: [
                        "post": notiPost as Any,
                        "map": map as Any,
                        "spot": spot as Any,
                        "newMap": newMap
                    ]
                )
            )
            
            let postRef = fireStore.collection("posts").document(postID)
            do {
                var post = post
                post.g = GFUtils.geoHash(forLocation: post.coordinate)
                try postRef.setData(from: post)
                if !newMap {
                    /// send new map notis for new map
                    self.sendPostNotifications(post: post, map: map, spot: spot)
                }
                
                let commentRef = postRef.collection("comments").document(commentObject.id ?? "")
                
                try commentRef.setData(from: commentObject)
                
            } catch {}
        }
    }
    
    private func sendPostNotifications(post: MapPost, map: CustomMap?, spot: MapSpot?) {
        let functions = Functions.functions()
        let notiValues: [String: Any] = [
            FireBaseCollectionFields.communityMap.rawValue: map?.communityMap ?? false,
            FireBaseCollectionFields.friendIDs.rawValue: UserDataModel.shared.userInfo.friendIDs,
            FireBaseCollectionFields.imageURLs.rawValue: post.imageURLs,
            FireBaseCollectionFields.mapID.rawValue: map?.id ?? "",
            FireBaseCollectionFields.mapMembers.rawValue: map?.memberIDs ?? [],
            FireBaseCollectionFields.mapName.rawValue: map?.mapName ?? "",
            FireBaseCollectionFields.postID.rawValue: post.id ?? "",
            FireBaseCollectionFields.posterID.rawValue: UserDataModel.shared.uid,
            FireBaseCollectionFields.posterUsername.rawValue: UserDataModel.shared.userInfo.username,
            FireBaseCollectionFields.privacyLevel.rawValue: post.privacyLevel ?? "friends",
            FireBaseCollectionFields.spotID.rawValue: spot?.id ?? "",
            FireBaseCollectionFields.spotName.rawValue: spot?.spotName ?? "",
            FireBaseCollectionFields.spotVisitors.rawValue: spot?.visitorList ?? [],
            FireBaseCollectionFields.taggedUserIDs.rawValue: post.taggedUserIDs ?? []
        ]
        
        functions.httpsCallable(FuctionsHttpsCall.sendPostNotification.rawValue)
            .call(
                notiValues,
                completion: { _, _ in }
            )
    }
}
