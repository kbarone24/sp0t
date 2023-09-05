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
    case hot = "HOT"
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
    func fetchRecentPostsFor(spotID: String?, popID: String?, limit: Int, endDocument: DocumentSnapshot?) async -> ([Post], DocumentSnapshot?)
    func fetchCommentsFor(post: Post, limit: Int, endDocument: DocumentSnapshot?) async -> (comments: [Post], endDocument: DocumentSnapshot?)
    func fetchTopPostsFor(spotID: String?, popID: String?, limit: Int, endDocument: DocumentSnapshot?, cachedPosts: [Post], presentedPostIDs: [String]) async -> ([Post], DocumentSnapshot?, [Post])
    func fetchRecentPostsFor(userID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([Post], DocumentSnapshot?)
    func configurePostsForPassthrough(rawPosts: [Post], passedPostID: String, passedCommentID: String?) async throws -> [Post]

    func getPost(postID: String) async throws -> Post
    func getComment(postID: String, commentID: String) async throws -> Post
    func getPostDocuments(query: Query) async throws -> [Post]?
    func uploadPost(post: Post, spot: Spot)
    func likePostDB(post: Post)
    func unlikePostDB(post: Post)
    func dislikePostDB(post: Post)
    func undislikePostDB(post: Post)
    func deletePost(post: Post)
    func hidePost(post: Post)
    func reportPost(post: Post, feedbackText: String)
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

    func fetchRecentPostsFor(spotID: String?, popID: String?, limit: Int, endDocument: DocumentSnapshot?) async -> ([Post], DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                var query = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: PostCollectionFields.timestamp.rawValue, descending: true)

                if let spotID {
                    // query for spot
                    query = query.whereField(PostCollectionFields.spotID.rawValue, isEqualTo: spotID)
                } else if let popID {
                    // query for pop
                    query = query.whereField(PostCollectionFields.popID.rawValue, isEqualTo: popID)
                }

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .recent)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    return await (self.fetchSpotPostDetails(snapshot: snapshot), snapshot?.documents.last)
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

    private func fetchSpotPostObjects(snapshot: QuerySnapshot?) async -> ([Post]) {
        guard let snapshot else {
            return []
        }

        var posts = [Post]()
        for document in snapshot.documents {
            guard var mapPost = try? document.data(as: Post.self),
                  showPostToUser(post: mapPost)
            else { continue }
            mapPost.postScore = mapPost.getSpotPostScore()
            posts.append(mapPost)
        }

        return posts
    }

    private func fetchSpotPostDetails(snapshot: QuerySnapshot?) async -> [Post?] {
        guard let snapshot else {
            return []
        }
        
        return await snapshot.documents.throwingAsyncValues { document in
            if let mapPost = try? document.data(as: Post.self),
               self.showPostToUser(post: mapPost) {
                return await self.setPostDetails(post: mapPost)
            } else {
                return nil
            }
        }
    }

    func setPostDetails(post: Post) async -> Post {
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

                // no longer fetching comments
                postInfo.userInfo = user
                continuation.resume(returning: postInfo)
            }
        }
    }


    func fetchCommentsFor(post: Post, limit: Int, endDocument: DocumentSnapshot?) async -> (comments: [Post], endDocument: DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            guard let postID = post.id, limit > 0 else {
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
                    var comments: [Post] = []
                    let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.last
                    for doc in docs {
                        guard var comment = try? doc.data(as: Post.self) else {  continue }
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


    func fetchTopPostsFor(spotID: String?, popID: String?, limit: Int, endDocument: DocumentSnapshot?, cachedPosts: [Post], presentedPostIDs: [String]) async -> ([Post], DocumentSnapshot?, [Post]) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {

                guard cachedPosts.isEmpty else {
                    var finalPosts = [Post]()
                    var postsToCache = [Post]()
                    for i in 0..<cachedPosts.count {
                        if i < 10 {
                            let post = await self.setPostDetails(post: cachedPosts[i])
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

                if let spotID {
                    // query for spot
                    query = query.whereField(PostCollectionFields.spotID.rawValue, isEqualTo: spotID)
                } else if let popID {
                    // query for pop
                    query = query.whereField(PostCollectionFields.popID.rawValue, isEqualTo: popID)
                }

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .hot)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    let newEndDocument = await snapshot?.documents.last
                    let postObjects = await self.fetchSpotPostObjects(snapshot: snapshot)
                    let sortedPosts = postObjects.sorted(by: { $0.postScore ?? 0 > $1.postScore ?? 0 })
                    var postsToCache = [Post]()
                    var finalPosts = [Post]()
                    // larger cache for initial fetches. Unlimited cache for geofetch since not sorted by timestamp
                    let maxCacheSize =
                    sortedPosts.count * 2 / 3
                    // append first 10 posts, cache the remaining posts for pagination
                    for i in 0..<sortedPosts.count {
                        let post = sortedPosts[i]
                        if i < 10 {
                            let post = await self.setPostDetails(post: post)
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

    func fetchRecentPostsFor(userID: String, limit: Int, endDocument: DocumentSnapshot?) async -> ([Post], DocumentSnapshot?) {
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
                    return await (self.fetchSpotPostDetails(snapshot: snapshot), endDocument)
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

    private func showPostToUser(post: Post) -> Bool {
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

    func configurePostsForPassthrough(rawPosts: [Post], passedPostID: String, passedCommentID: String?) async throws -> [Post] {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                var rawPosts = rawPosts
                if let i = rawPosts.firstIndex(where: { $0.id == passedPostID }) {
                    var post = rawPosts.remove(at: i)
                    if let commentID = passedCommentID, commentID != "" {
                        if let j = post.postChildren?.firstIndex(where: { $0.id == commentID }) {
                            if var comment = post.postChildren?.remove(at: j) {
                                comment.highlightCell = true
                                post.postChildren?.insert(comment, at: 0)
                            }
                        } else {
                            if var comment = try? await self.getComment(postID: passedPostID, commentID: commentID) {
                                comment.highlightCell = true
                                post.postChildren?.insert(comment, at: 0)
                            }
                        }
                    } else {
                        post.highlightCell = true
                    }
                    rawPosts.insert(post, at: 0)

                } else {
                    let post = try? await self.getPost(postID: passedPostID)
                    if var post {
                        if let commentID = passedCommentID, commentID != "" {
                            if let j = post.postChildren?.firstIndex(where: { $0.id == commentID }) {
                                if var comment = post.postChildren?.remove(at: j) {
                                    comment.highlightCell = true
                                    post.postChildren?.insert(comment, at: 0)
                                }
                            } else {
                                if var comment = try? await self.getComment(postID: passedPostID, commentID: commentID) {
                                    comment.highlightCell = true
                                    post.postChildren?.insert(comment, at: 0)
                                }
                            }
                        } else {
                            post.highlightCell = true
                        }
                        rawPosts.insert(post, at: 0)
                    }
                }
                print("continuation resume")
                continuation.resume(returning: rawPosts)
            }
        }
    }

    func getPost(postID: String) async throws -> Post {
        try await withUnsafeThrowingContinuation { continuation in
            self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .getDocument { doc, _ in
                    Task(priority: .high) {
                        
                        var emptyPost = Post(
                            spotID: "",
                            spotName: "",
                            mapID: "",
                            mapName: ""
                        )
                        emptyPost.id = ""

                        guard let postInfo = try? doc?.data(as: Post.self) else {
                            continuation.resume(returning: emptyPost)
                            return
                        }
                        
                        let post = await self.setPostDetails(post: postInfo)
                        continuation.resume(returning: post)
                    }
                }
        }
    }

    func getComment(postID: String, commentID: String) async throws -> Post {
        try await withUnsafeThrowingContinuation { continuation in
            self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .document(postID)
                .collection(FirebaseCollectionNames.comments.rawValue)
                .document(commentID)
                .getDocument { doc, _ in
                    Task(priority: .high) {

                        var emptyPost = Post(
                            spotID: "",
                            spotName: "",
                            mapID: "",
                            mapName: ""
                        )
                        emptyPost.id = ""

                        guard let postInfo = try? doc?.data(as: Post.self) else {
                            continuation.resume(returning: emptyPost)
                            return
                        }

                        let post = await self.setPostDetails(post: postInfo)
                        continuation.resume(returning: post)
                    }
                }
        }
    }

    // function does NOT fetch user info
    func getPostDocuments(query: Query) async throws -> [Post]? {
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
                    var posts: [Post] = []
                    for doc in docs {
                        defer {
                            if doc == docs.last {
                                continuation.resume(returning: posts)
                            }
                        }
                        
                        guard let postInfo = try? doc.data(as: Post.self) else { continue }
                        posts.append(postInfo)
                    }
                }
            }
        }
    }

    func uploadPost(post: Post, spot: Spot) {
        /// send local notification first
        guard let postID = post.id else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let parentPostID = post.parentPostID {
                let postRef = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentPostID).collection(FirebaseCollectionNames.comments.rawValue).document(postID)
                try? postRef?.setData(from: post)
                // increment comment count immediately so that spot page listener has updated values
                self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentPostID).updateData([
                    PostCollectionFields.commentCount.rawValue: FieldValue.increment(Int64(1))
                ])

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

    func likePostDB(post: Post) {
        DispatchQueue.global(qos: .background).async { [weak self] in

            let values: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            var likeNotiValues: [String: Any] = [
                NotificationCollectionFields.imageURL.rawValue: post.imageURLs.first ?? "",
                NotificationCollectionFields.originalPoster.rawValue: post.userInfo?.username ?? "",
                NotificationCollectionFields.seen.rawValue: false,
                NotificationCollectionFields.senderID.rawValue: UserDataModel.shared.uid,
                NotificationCollectionFields.senderUsername.rawValue: UserDataModel.shared.userInfo.username,
                NotificationCollectionFields.spotID.rawValue: post.spotID ?? "",
                PostCollectionFields.popID.rawValue: post.popID ?? "",
                NotificationCollectionFields.timestamp.rawValue: Timestamp(date: Date()),
            ] as [String: Any]

            if let parentID = post.parentPostID, parentID != "" {
                // like comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
                // comment noti
                likeNotiValues[NotificationCollectionFields.postID.rawValue] = parentID
                likeNotiValues[NotificationCollectionFields.commentID.rawValue] = post.id ?? ""
                likeNotiValues[NotificationCollectionFields.type.rawValue] = NotificationType.commentLike.rawValue
            } else {
                // like post
                collectionReference?.document(post.id ?? "").updateData(values)
                // post noti
                likeNotiValues[NotificationCollectionFields.postID.rawValue] = post.id ?? ""
                likeNotiValues[NotificationCollectionFields.type.rawValue] = NotificationType.like.rawValue
            }

            if post.posterID == UserDataModel.shared.uid { return }

            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(post.posterID).collection(FirebaseCollectionNames.notifications.rawValue).addDocument(data: likeNotiValues)

            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)

            self?.incrementSpotScoreFor(userID: post.posterID, increment: 1)

            let userService = try? ServiceContainer.shared.service(for: \.userService)
            userService?.updateUserLastSeen(spotID: post.spotID ?? "")
        }
    }

    func unlikePostDB(post: Post) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayRemove([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
                let functions = Functions.functions()
                functions.httpsCallable("unlikeComment").call([
                    "postID": post.parentPostID,
                    "commentID": post.id ?? "",
                    "commenterID": post.posterID,
                    "likerID": UserDataModel.shared.uid
                ]) { result, error in
                    print(result?.data as Any, error as Any)
                }

            } else {
                collectionReference?.document(post.id ?? "").updateData(values)
                let functions = Functions.functions()
                functions.httpsCallable("unlikePost").call([
                    "postID": post.id ?? "",
                    "posterID": post.posterID,
                    "likerID": UserDataModel.shared.uid
                ]) { result, error in
                    print(result?.data as Any, error as Any)
                }
            }

            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)

            self?.incrementSpotScoreFor(userID: post.posterID, increment: -1)

            let userService = try? ServiceContainer.shared.service(for: \.userService)
            userService?.updateUserLastSeen(spotID: post.spotID ?? "")
        }
    }

    func dislikePostDB(post: Post) {
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

            let userService = try? ServiceContainer.shared.service(for: \.userService)
            userService?.updateUserLastSeen(spotID: post.spotID ?? "")
        }
    }

    func undislikePostDB(post: Post) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let values: [String: Any] = [FirebaseCollectionFields.dislikers.rawValue: FieldValue.arrayRemove([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            self?.incrementSpotScoreFor(userID: post.posterID, increment: 1)

            let userService = try? ServiceContainer.shared.service(for: \.userService)
            userService?.updateUserLastSeen(spotID: post.spotID ?? "")
        }
    }

    
    private func sendPostNotifications(post: Post, map: CustomMap?, spot: Spot?) {
        guard !(spot?.isPop ?? false) else { return }
        let functions = Functions.functions()
        let notiValues: [String: Any] = [
            FirebaseCollectionFields.imageURLs.rawValue: post.imageURLs,
            PostCollectionFields.videoURL.rawValue: post.videoURL ?? "",
            FirebaseCollectionFields.postID.rawValue: post.id ?? "",
            FirebaseCollectionFields.posterID.rawValue: UserDataModel.shared.uid,
            FirebaseCollectionFields.posterUsername.rawValue: UserDataModel.shared.userInfo.username,
            FirebaseCollectionFields.spotID.rawValue: spot?.id ?? "",
            SpotCollectionFields.spotName.rawValue: spot?.spotName ?? "",
            FirebaseCollectionFields.taggedUserIDs.rawValue: post.taggedUserIDs ?? [],
            SpotCollectionFields.visitorList.rawValue: spot?.visitorList ?? [],
        ]

        functions.httpsCallable(FuctionsHttpsCall.sendPostNotification.rawValue)
            .call(
                notiValues,
                completion: { _, _ in }
            )
    }

    func hidePost(post: Post) {
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
    
    func deletePost(post: Post) {
        if let parentID = post.parentPostID, parentID != "" {
            // delete comment
            fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").delete()
            fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentID).updateData([
                PostCollectionFields.commentCount.rawValue: FieldValue.increment(Int64(-1))
            ])

        } else if let postID = post.id {
            // run backend function to delete post
            var posters = [UserDataModel.shared.uid]
            posters.append(contentsOf: post.taggedUserIDs ?? [])
            let functions = Functions.functions()
            functions.httpsCallable("postDelete").call([
                "postID": postID,
                "spotID": post.spotID ?? "",
                "popID": post.popID ?? "",
                "posterID": post.posterID,
            ] as [String : Any]) { result, error in
                print("result", result?.data as Any, error as Any)
            }

            NotificationCenter.default.post(Notification(name: Notification.Name("PostDelete"), object: nil, userInfo: [
                "postID": postID,
                "parentPostID": post.parentPostID ?? ""
            ]))
        }

        // note: spotscore increments are run on the backend for deletes
    }

    func reportPost(post: Post, feedbackText: String) {
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
                        "reporterID": UserDataModel.shared.uid,
                        "reporterUsername": UserDataModel.shared.userInfo.username,
                        "timestamp": Timestamp()
                    ]
                )

            let values: [String: Any] = [PostCollectionFields.reportedBy.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            // update user's reported by
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(post.posterID).updateData([
                UserCollectionFields.reportedBy.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid])
            ])

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
