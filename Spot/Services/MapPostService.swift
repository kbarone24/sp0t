//
//  MapPostService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import CoreLocation
import GeoFire
import GeoFireUtils

enum MapServiceCaller {
    case Profile
    case Spot
    case CustomMap
    case Feed
    case Explore
}

enum MapPostType: String {
    case recent = "RECENT"
    case top = "TOP"
    case user = "USER"
}

final class RequestBody {
    let query: Query
    let type: MapPostType
    
    init(query: Query, type: MapPostType) {
        self.query = query
        self.type = type
    }
}

protocol MapPostServiceProtocol {
    func fetchRecentPostsFor(spotID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?)
    func fetchCommentsFor(post: MapPost, limit: Int, endDocument: DocumentSnapshot?) async -> (comments: [MapPost], endDocument: DocumentSnapshot?)
    func fetchTopPostsFor(spotID: String, limit: Int, endDocument: DocumentSnapshot?, cachedPosts: [MapPost], presentedPostIDs: [String]) async -> ([MapPost], DocumentSnapshot?, [MapPost])
    func fetchRecentPostsFor(userID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?)

    func getPost(postID: String) async throws -> MapPost
    func getPostDocuments(query: Query) async throws -> [MapPost]?
    func uploadPost(post: MapPost, spot: MapSpot)
    func likePostDB(post: MapPost)
    func unlikePostDB(post: MapPost)
    func dislikePostDB(post: MapPost)
    func undislikePostDB(post: MapPost)
    func deletePost(post: MapPost)
    func hidePost(post: MapPost)
    func reportPost(post: MapPost, feedbackText: String)
    func incrementSpotScoreFor(userID: String, increment: Int)
}

final class MapPostService: MapPostServiceProtocol {
    enum MapPostServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    private let imageVideoService: ImageVideoServiceProtocol

    init(fireStore: Firestore, imageVideoService: ImageVideoServiceProtocol) {
        self.fireStore = fireStore
        self.imageVideoService = imageVideoService
    }

    func fetchRecentPostsFor(spotID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                var query = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                    .whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .recent)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    return await (self.fetchSpotPostDetails(snapshot: snapshot, parent: .SpotPage), snapshot?.documents.last)
                }

                let postsTuple = await fetchPosts
                let posts = postsTuple
                    .flatMap { $0.0 }
                    .compactMap { $0 }
                    .removingDuplicates()
                let endDocument = postsTuple
                    .compactMap({ $0.1 })
                    .compactMap({ $0 })
                    .first

                continuation.resume(
                    returning: (
                        posts,
                        endDocument
                    )
                )
              //  self.lastRecentDocument = nil
            }
        }
    }

    private func fetchSpotPostObjects(snapshot: QuerySnapshot?) async -> ([MapPost]) {
        guard let snapshot else {
            return []
        }

        var posts = [MapPost]()
        for document in snapshot.documents {
            guard var mapPost = try? document.data(as: MapPost.self),
                  showPostToUser(post: mapPost)
            else { continue }
            mapPost.postScore = mapPost.getSpotPostScore()
            posts.append(mapPost)
        }

        return posts
    }

    private func fetchSpotPostDetails(snapshot: QuerySnapshot?, parent: SpotPostParent) async -> [MapPost?] {
        guard let snapshot else {
            return []
        }
        
        return await snapshot.documents.throwingAsyncValues { document in
            if let mapPost = try? document.data(as: MapPost.self),
               self.showPostToUser(post: mapPost) {
                return await self.setPostDetails(post: mapPost, parent: parent)
            } else {
                return nil
            }
        }
    }

    func setPostDetails(post: MapPost, parent: SpotPostParent) async -> MapPost {
        return await withUnsafeContinuation { continuation in
            guard let postID = post.id, !postID.isEmpty else {
                continuation.resume(returning: post)
                return
            }

            Task(priority: .high) {
                guard let userService = try? ServiceContainer.shared.service(for: \.userService),
                      let user = try? await userService.getUserInfo(userID: post.posterID)
                else {
                    continuation.resume(returning: post)
                    return
                }

                var postInfo = post

                if parent == .SpotPage {
                    // don't fetch comments until prompted for profile
                    let commentData = await fetchCommentsFor(post: post, limit: 3, endDocument: nil)
                    postInfo.postChildren = commentData.comments
                    postInfo.lastCommentDocument = commentData.endDocument
                }

                postInfo.userInfo = user
                continuation.resume(returning: postInfo)
            }
        }
    }


    func fetchCommentsFor(post: MapPost, limit: Int, endDocument: DocumentSnapshot?) async -> (comments: [MapPost], endDocument: DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            guard let postID = post.id else {
                continuation.resume(returning: ([], endDocument))
                return
            }

            var query = Firestore.firestore()
                .collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .collection(FirebaseCollectionNames.comments.rawValue)
                .order(by: FirebaseCollectionFields.timestamp.rawValue)
                .limit(to: limit)

            if let endDocument {
                query = query.start(afterDocument: endDocument)
            }

            query.getDocuments { snap, error in
                guard error == nil, let docs = snap?.documents
                else {
                    continuation.resume(returning: ([], endDocument))
                    return
                    }
                Task {
                    var comments: [MapPost] = []
                    let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.last
                    for doc in docs {
                        guard var comment = try? doc.data(as: MapPost.self) else {  continue }
                        guard self.showPostToUser(post: comment) else { continue }
                        let userService = try ServiceContainer.shared.service(for: \.userService)
                        let user = try await userService.getUserInfo(userID: comment.posterID)
                        comment.userInfo = user
                        comment.parentPostID = post.id ?? ""
                        comment.parentPosterID = post.posterID
                        comments.append(comment)
                    }
                    continuation.resume(returning: (comments, endDocument))
                }
            }
        }
    }


    func fetchTopPostsFor(spotID: String, limit: Int, endDocument: DocumentSnapshot?, cachedPosts: [MapPost], presentedPostIDs: [String]) async -> ([MapPost], DocumentSnapshot?, [MapPost]) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {

                guard cachedPosts.isEmpty else {
                    var finalPosts = [MapPost]()
                    var postsToCache = [MapPost]()
                    for i in 0..<cachedPosts.count {
                        if i < 10 {
                            let post = await self.setPostDetails(post: cachedPosts[i], parent: .SpotPage)
                            finalPosts.append(post)
                        } else if i < cachedPosts.count {
                            postsToCache.append(cachedPosts[i])
                        }
                    }
                    continuation.resume(returning: (finalPosts, endDocument, postsToCache))
                    return
                }

                var query = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                    .whereField(PostCollectionFields.spotID.rawValue, isEqualTo: spotID)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .top)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    let newEndDocument = await snapshot?.documents.last
                    let postObjects = await self.fetchSpotPostObjects(snapshot: snapshot)
                    let sortedPosts = postObjects.sorted(by: { $0.postScore ?? 0 > $1.postScore ?? 0 })
                    var postsToCache = [MapPost]()
                    var finalPosts = [MapPost]()
                    // larger cache for initial fetches. Unlimited cache for geofetch since not sorted by timestamp
                    let maxCacheSize =
                    sortedPosts.count > 80 ? 50 :
                    sortedPosts.count > 40 ? 30 :
                    10
                    // append first 10 posts, cache the remaining posts for pagination
                    for i in 0..<sortedPosts.count {
                        let post = sortedPosts[i]
                        if i < 10 {
                            let post = await self.setPostDetails(post: post, parent: .SpotPage)
                            finalPosts.append(post)
                            // max cache size = 20, don't cache for pagination
                        } else if postsToCache.count < maxCacheSize {
                            postsToCache.append(post)
                        }
                    }
                    return (finalPosts, postsToCache, newEndDocument)
                }

                let postTuple = await fetchPosts
                let postsToDisplay = postTuple
                    .flatMap { $0.0 }
                    .compactMap { $0 }
                    .removingDuplicates()
                let postsToCache = postTuple
                    .flatMap { $0.1 }
                    .compactMap { $0 }
                    .removingDuplicates()
                let endDocument = postTuple
                    .compactMap({ $0.2 })
                    .compactMap({ $0 })
                    .first
                
                continuation.resume(
                    returning: (
                        postsToDisplay,
                        endDocument,
                        postsToCache
                    )
                )
             //   self.lastTopDocument = nil
            }
        }
    }

    func fetchRecentPostsFor(userID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                var query = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                    .whereField(FirebaseCollectionFields.posterID.rawValue, isEqualTo: userID)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .user)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    // disable pagination
                    let endDocument = await snapshot?.documents.count == limit ? snapshot?.documents.last : nil
                    return await (self.fetchSpotPostDetails(snapshot: snapshot, parent: .Profile), endDocument)
                }

                let postsTuple = await fetchPosts
                let posts = postsTuple
                    .flatMap { $0.0 }
                    .compactMap { $0 }
                    .removingDuplicates()
                let endDocument = postsTuple
                    .compactMap({ $0.1 })
                    .compactMap({ $0 })
                    .last

                continuation.resume(
                    returning: (
                        posts,
                        endDocument
                    )
                )
            }
        }
    }

    private func showPostToUser(post: MapPost) -> Bool {
        return !(post.flagged) &&
        !(post.userInfo?.id?.isBlocked() ?? false) &&
        !(post.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) &&
          !(UserDataModel.shared.deletedPostIDs.contains(post.id ?? "")) &&
        (post.privacyLevel != "invite" || (post.inviteList?.contains(UserDataModel.shared.uid) ?? false))
    }
    
    private func fetchSnapshot(request: RequestBody) async -> QuerySnapshot? {
        await withUnsafeContinuation { continuation in
            request.query.getDocuments { snapshot, error in
                guard let snapshot, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }
    

    func getPost(postID: String) async throws -> MapPost {
        try await withUnsafeThrowingContinuation { continuation in
            self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .getDocument { doc, _ in
                    Task(priority: .high) {
                        
                        var emptyPost = MapPost(
                            spotID: "",
                            spotName: "",
                            mapID: "",
                            mapName: ""
                        )
                        emptyPost.id = ""

                        guard let postInfo = try? doc?.data(as: MapPost.self) else {
                            continuation.resume(returning: emptyPost)
                            return
                        }
                        
                        let post = await self.setPostDetails(post: postInfo, parent: .Profile)
                        continuation.resume(returning: post)
                    }
                }
        }
    }

    // function does NOT fetch user info
    func getPostDocuments(query: Query) async throws -> [MapPost]? {
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
                        
                        guard let postInfo = try? doc.data(as: MapPost.self) else { continue }
                        posts.append(postInfo)
                    }
                }
            }
        }
    }

    func uploadPost(post: MapPost, spot: MapSpot) {
        /// send local notification first
        guard let postID = post.id else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let parentPostID = post.parentPostID {
                let postRef = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentPostID).collection(FirebaseCollectionNames.comments.rawValue).document(postID)
                try? postRef?.setData(from: post)

                if let replyToID = post.replyToID, let parentPosterID = post.parentPosterID {
                    let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
                    friendService?.incrementTopFriends(friendID: replyToID, increment: 1, completion: nil)
                    friendService?.incrementTopFriends(friendID: parentPosterID, increment: 1, completion: nil)
                }

            } else {
                let postRef = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(postID)
                try? postRef?.setData(from: post)
                self?.sendPostNotifications(post: post, map: nil, spot: spot)
            }
        }
    }

    func likePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in

            let values: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
            var notificationType: NotificationType = .like

            if let parentID = post.parentPostID, parentID != "" {
                // like comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
                notificationType = .commentLike
            } else {
                // like post
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            if post.posterID == UserDataModel.shared.uid { return }
            
            let likeNotiValues: [String: Any] = [
                NotificationCollectionFields.imageURL.rawValue: post.imageURLs.first ?? "",
                NotificationCollectionFields.originalPoster.rawValue: post.userInfo?.username ?? "",
                NotificationCollectionFields.postID.rawValue: post.id ?? "",
                NotificationCollectionFields.seen.rawValue: false,
                NotificationCollectionFields.senderID.rawValue: UserDataModel.shared.uid,
                NotificationCollectionFields.senderUsername.rawValue: UserDataModel.shared.userInfo.username,
                NotificationCollectionFields.spotID.rawValue: post.spotID ?? "",
                NotificationCollectionFields.timestamp.rawValue: Timestamp(date: Date()),
                NotificationCollectionFields.type.rawValue: notificationType.rawValue
            ] as [String: Any]
            
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(post.posterID).collection(FirebaseCollectionNames.notifications.rawValue).addDocument(data: likeNotiValues)

            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)

            self?.incrementSpotScoreFor(userID: post.posterID, increment: 1)
        }
    }

    func unlikePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayRemove([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            let functions = Functions.functions()
            functions.httpsCallable("unlikePost").call([
                "postID": post.id ?? "",
                "posterID": post.posterID,
                "likerID": UserDataModel.shared.uid
            ]) { result, error in
                print(result?.data as Any, error as Any)
            }
            
            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)

            self?.incrementSpotScoreFor(userID: post.posterID, increment: -1)
        }
    }

    func dislikePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [FirebaseCollectionFields.dislikers.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                // like comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                // like post
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            self?.incrementSpotScoreFor(userID: post.posterID, increment: -1)
        }
    }

    func undislikePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [FirebaseCollectionFields.dislikers.rawValue: FieldValue.arrayRemove([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            self?.incrementSpotScoreFor(userID: post.posterID, increment: 1)
        }
    }

    
    private func sendPostNotifications(post: MapPost, map: CustomMap?, spot: MapSpot?) {
        let functions = Functions.functions()
        let notiValues: [String: Any] = [
            FirebaseCollectionFields.communityMap.rawValue: map?.communityMap ?? false,
            FirebaseCollectionFields.friendIDs.rawValue: UserDataModel.shared.userInfo.friendIDs,
            FirebaseCollectionFields.imageURLs.rawValue: post.imageURLs,
            "videoURL": post.videoURL ?? "",
            FirebaseCollectionFields.mapID.rawValue: map?.id ?? "",
            FirebaseCollectionFields.mapMembers.rawValue: map?.likers ?? [],
            FirebaseCollectionFields.mapName.rawValue: map?.mapName ?? "",
            FirebaseCollectionFields.postID.rawValue: post.id ?? "",
            FirebaseCollectionFields.posterID.rawValue: UserDataModel.shared.uid,
            FirebaseCollectionFields.posterUsername.rawValue: UserDataModel.shared.userInfo.username,
            FirebaseCollectionFields.privacyLevel.rawValue: post.privacyLevel ?? "friends",
            FirebaseCollectionFields.spotID.rawValue: spot?.id ?? "",
            FirebaseCollectionFields.spotName.rawValue: spot?.spotName ?? "",
            FirebaseCollectionFields.spotVisitors.rawValue: spot?.visitorList ?? [],
            FirebaseCollectionFields.taggedUserIDs.rawValue: post.taggedUserIDs ?? []
        ]

        functions.httpsCallable(FuctionsHttpsCall.sendPostNotification.rawValue)
            .call(
                notiValues,
                completion: { _, _ in }
            )
    }

    func hidePost(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [PostCollectionFields.hiddenBy.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                // report comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                // report post
                collectionReference?.document(post.id ?? "").updateData(values)
            }
        }
    }
    
    func deletePost(post: MapPost) {
        if let parentID = post.parentPostID, parentID != "" {
            // delete comment
            fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").delete()

        } else {
            var posters = [UserDataModel.shared.uid]
            posters.append(contentsOf: post.taggedUserIDs ?? [])
            let functions = Functions.functions()
            functions.httpsCallable("postDelete").call([
                "postIDs": [post.id],
                "spotID": post.spotID ?? "",
                "mapID": post.mapID ?? "",
                "uid": UserDataModel.shared.uid,
                "posters": posters,
                "spotDelete": false,
                "mapDelete": false,
                "spotRemove": false,
                "hideFromFeed": post.hideFromFeed ?? false
            ] as [String : Any]) { result, error in
                print("result", result?.data as Any, error as Any)
            }
        }
    }

    func reportPost(post: MapPost, feedbackText: String) {
        guard let postID = post.id else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection("feedback")
                .addDocument(
                    data: [
                        "feedbackText": feedbackText,
                        "postID": postID,
                        "caption": post.caption,
                        "firstImageURL": post.imageURLs.first ?? "",
                        "videoURL": post.videoURL ?? "",
                        "posterID": post.posterID,
                        "posterUsername": post.posterUsername ?? "",
                        "type": "reportPost",
                        "reporterID": UserDataModel.shared.uid
                    ]
                )

            let values: [String: Any] = [PostCollectionFields.reportedBy.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                // report comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                // report post
                collectionReference?.document(post.id ?? "").updateData(values)
            }
        }
    }

    func incrementSpotScoreFor(userID: String, increment: Int) {
        DispatchQueue.global(qos: .utility).async {
            self.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(userID).updateData([UserCollectionFields.spotScore.rawValue: FieldValue.increment(Int64(increment))])
        }
    }
}
