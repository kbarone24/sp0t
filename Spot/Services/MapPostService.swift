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

    func fetchAllPostsForCurrentUser(limit: Int, lastFriendsItem: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?)
    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?, cachedPosts: [MapPost], presentedPostIDs: [String]) async -> ([MapPost], DocumentSnapshot?, [MapPost])
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?)
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?)
    func getPostsFrom(query: Query, caller: MapServiceCaller, limit: Int) async throws -> (posts: [MapPost]?, endDocument: DocumentSnapshot?)
    func getComments(postID: String) async throws -> [MapComment]
    func getPost(postID: String) async throws -> MapPost
    func setPostDetails(post: MapPost) async -> MapPost
    func uploadPost(post: MapPost, spot: MapSpot)
    func updateMapNameInPosts(mapID: String, newName: String)
    func likePostDB(post: MapPost)
    func unlikePostDB(post: MapPost)
    func dislikePostDB(post: MapPost)
    func undislikePostDB(post: MapPost)
    func deletePost(post: MapPost)
    func hidePost(post: MapPost)
    func setSeen(post: MapPost)
    func reportPost(post: MapPost, feedbackText: String)
    func incrementSpotScoreFor(userID: String, increment: Int)
}

final class MapPostService: MapPostServiceProtocol {
    enum MapPostServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    private let imageVideoService: ImageVideoServiceProtocol

    private var lastRecentDocument: DocumentSnapshot?
    private var lastTopDocument: DocumentSnapshot?

    private var lastGeographicFetchRadius: CLLocationDistance?
    private var presentedPostIDs = [String]()
    
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
                    return await self.fetchSpotPostDetails(snapshot: snapshot)
                }

                let posts = await fetchPosts
                    .flatMap { $0 }
                    .compactMap { $0 }
                    .removingDuplicates()

                continuation.resume(
                    returning: (
                        posts,
                        self.lastRecentDocument
                    )
                )
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

    private func fetchSpotPostDetails(snapshot: QuerySnapshot?) async -> [MapPost?] {
        guard let snapshot else {
            return []
        }
        
        return await snapshot.documents.throwingAsyncValues { document in
            if let mapPost = try? document.data(as: MapPost.self),
               self.showPostToUser(post: mapPost) {
                return await self.setPostDetails(post: mapPost)
            } else {
                return nil
            }
        }
    }

    func setPostDetails(post: MapPost) async -> MapPost {
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

                let commentData = await fetchCommentsFor(post: post, limit: 3, endDocument: nil)

                var postInfo = post
                postInfo.userInfo = user
                postInfo.postChildren = commentData.comments
                postInfo.lastCommentDocument = commentData.endDocument
                postInfo.generateSnapshot()
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
                .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
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
                        comment.parentPosterUsername = post.posterUsername ?? ""
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
                self.presentedPostIDs = presentedPostIDs

                guard cachedPosts.isEmpty else {
                    var finalPosts = [MapPost]()
                    var postsToCache = [MapPost]()
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
                    .whereField("spotID", isEqualTo: spotID)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                let request: [RequestBody] = [RequestBody(query: query, type: .top)]
                async let fetchPosts = request.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
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
                            let post = await self.setPostDetails(post: post)
                            finalPosts.append(post)
                            // max cache size = 20, don't cache for pagination
                        } else if postsToCache.count < maxCacheSize {
                            postsToCache.append(post)
                        }
                    }
                    return (finalPosts, postsToCache)
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
                
                continuation.resume(
                    returning: (
                        postsToDisplay,
                        self.lastTopDocument,
                        postsToCache
                    )
                )
            }
        }
    }

    private func showPostToUser(post: MapPost) -> Bool {
        print("show post to user", post.spotName, !(post.flagged),
              !(post.userInfo?.id?.isBlocked() ?? false),
              !(post.hiddenBy?.contains(UserDataModel.shared.uid) ?? false),
                !(UserDataModel.shared.deletedPostIDs.contains(post.id ?? "")),
              (post.privacyLevel != "invite" && !(post.inviteList?.contains(UserDataModel.shared.uid) ?? false)))
        return !(post.flagged) &&
        !(post.userInfo?.id?.isBlocked() ?? false) &&
        !(post.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) &&
          !(UserDataModel.shared.deletedPostIDs.contains(post.id ?? "")) &&
        (post.privacyLevel != "invite" || !(post.inviteList?.contains(UserDataModel.shared.uid) ?? false))
    }

    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?, cachedPosts: [MapPost], presentedPostIDs: [String]) async -> ([MapPost], DocumentSnapshot?, [MapPost]) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                guard let locationService = try? ServiceContainer.shared.service(for: \.locationService),
                      let currentLocation = locationService.currentLocation
                else {
                    continuation.resume(returning: ([], lastItem, []))
                    return
                }

                // return details for cached posts if they exist
                self.presentedPostIDs = presentedPostIDs
                guard cachedPosts.isEmpty else {
                    var finalPosts = [MapPost]()
                    var postsToCache = [MapPost]()
                    for i in 0..<cachedPosts.count {
                        if i < 10 {
                            let post = await self.setPostDetails(post: cachedPosts[i])
                            finalPosts.append(post)
                        } else if i < cachedPosts.count {
                            postsToCache.append(cachedPosts[i])
                        }
                    }
                    continuation.resume(returning: (finalPosts, lastItem, postsToCache))
                    return
                }

                async let city = locationService.getCityFromLocation(location: currentLocation, zoomLevel: .cityAndState)
                var request = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .whereField(FirebaseCollectionFields.city.rawValue, isEqualTo: await city)
               //     .whereField(FirebaseCollectionFields.privacyLevel.rawValue, isEqualTo: "public")
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                
                if let lastItem {
                    request = request.start(afterDocument: lastItem)
                }
                
                let requests: [RequestBody] = [RequestBody(query: request, type: .top)]

                // modified function to only fetch details for top 10 posts
                // should improve performance: increase initial query size, and decrease subsequent fetches
                // drop the bottom cached posts to get rid of low performers
                async let fetchPosts = requests.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    let postObjects = await self.fetchNearbyPostObjects(snapshot: snapshot)
                    let sortedPosts = postObjects.0.sorted(by: { $0?.postScore ?? 0 > $1?.postScore ?? 0 })
                    let geoFetch = postObjects.1
                    var postsToCache = [MapPost]()
                    var finalPosts = [MapPost]()
                    // larger cache for initial fetches. Unlimited cache for geofetch since not sorted by timestamp
                    let maxCacheSize = geoFetch ? sortedPosts.count :
                    sortedPosts.count > 200 ? 80 :
                    sortedPosts.count > 50 ? 30 :
                    10
                    // append first 10 posts, cache the remaining posts for pagination
                    for i in 0..<sortedPosts.count {
                        if i < 10, let post = sortedPosts[i] {
                            let post = await self.setPostDetails(post: post)
                            finalPosts.append(post)
                            // max cache size = 20, don't cache for pagination
                        } else if postsToCache.count < maxCacheSize, let post = sortedPosts[i] {
                            postsToCache.append(post)
                        }
                    }
                    return (finalPosts, postsToCache)
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

                continuation.resume(
                    returning: (
                        postsToDisplay,
                        self.lastTopDocument,
                        postsToCache
                    )
                )
            }
        }
    }
    
    func fetchAllPostsForCurrentUser(limit: Int, lastFriendsItem: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?) {
        await withUnsafeContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: ([], lastFriendsItem))
                return
            }
            
            Task(priority: .high) {
                let request = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                
                var friendsQuery = request.whereField(FirebaseCollectionFields.friendsList.rawValue, arrayContains: UserDataModel.shared.uid)
                
                if let lastFriendsItem {
                    friendsQuery = friendsQuery.start(afterDocument: lastFriendsItem)
                }

                let requests: [RequestBody] = [
                    RequestBody(query: friendsQuery, type: .recent)
                ]
                
                async let fetchPosts = requests.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    return await self.fetchAllPostDetails(snapshot: snapshot)
                }
                
                let posts = await fetchPosts
                    .flatMap { $0 }
                    .compactMap { $0 }
                    .removingDuplicates()
                
                continuation.resume(
                    returning: (
                        posts,
                        self.lastRecentDocument
                    )
                )
            }
        }
    }


    
    private func fetchSnapshot(request: RequestBody) async -> QuerySnapshot? {
        await withUnsafeContinuation { continuation in
            request.query.getDocuments { snapshot, error in
                guard let snapshot, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                if request.type == .recent {
                    self.lastRecentDocument = snapshot.documents.last
                } else if request.type == .top {
                    self.lastTopDocument = snapshot.documents.last
                }
                continuation.resume(returning: snapshot)
            }
        }
    }
    
    private func fetchAllPostDetails(snapshot: QuerySnapshot?) async -> [MapPost?] {
        guard let snapshot else {
            return []
        }
        
        return await snapshot.documents.throwingAsyncValues { document in
            if let mapPost = try? document.data(as: MapPost.self),
               !(mapPost.flagged),
               !(mapPost.userInfo?.id?.isBlocked() ?? false),
               !((mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) || UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? "")) {
                return await self.setPostDetails(post: mapPost)
            } else {
                return nil
            }
        }
    }

    private func fetchNearbyPostObjects(snapshot: QuerySnapshot?) async -> ([MapPost?], Bool) {
        guard let snapshot else {
            return ([], false)
        }

        var posts = [MapPost]()
        for document in snapshot.documents {
            guard var mapPost = try? document.data(as: MapPost.self),
                  !(mapPost.flagged),
                  !(mapPost.userInfo?.id?.isBlocked() ?? false),
                  !(mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false),
                  !(mapPost.privacyLevel == "invite"),
                  !(mapPost.hideFromFeed ?? false),
                  !UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? "")
            else { continue }
            mapPost.postScore = mapPost.getSpotPostScore()
            posts.append(mapPost)
        }

        // if snapshot is empty, fetch geographically (geoFetch: true)
        guard !posts.isEmpty else {
            return await (fetchPostsGeographically(), true)
        }
        // return snapshot for city posts (geoFetch: false)
        return (posts, false)
    }

    private func fetchPostsGeographically() async -> [MapPost?] {
        let maxFetchRadius: CLLocationDistance = 64000
        var radius = min((lastGeographicFetchRadius ?? 2000) * 2, maxFetchRadius)
        var posts = await fetchGeographicPostsWith(radius: radius, searchLimit: 150)
        // max radius = 64000 km = ~40mi
        while posts.isEmpty, radius <= maxFetchRadius {
            radius *= 2
            posts = await fetchGeographicPostsWith(radius: radius, searchLimit: 150)
        }

        lastGeographicFetchRadius = radius
        return posts
    }

    private func fetchGeographicPostsWith(radius: CLLocationDistance, searchLimit: Int) async -> [MapPost?] {
        let queryBounds = GFUtils.queryBounds(
            forLocation: UserDataModel.shared.currentLocation.coordinate,
            withRadius: radius)
        var queries = [Query]()
        for bound in queryBounds {
            queries.append(fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .order(by: "g")
                .start(at: [bound.startValue])
                .end(at: [bound.endValue])
                .limit(to: searchLimit))
        }

        var allPosts: [MapPost?] = []
        for query in queries {
            let posts = await getPostObjectsFromGeoQuery(query: query)
            allPosts.append(contentsOf: posts)
        }
        return allPosts
    }

    private func getPostObjectsFromGeoQuery(query: Query) async -> [MapPost?] {
        do {
            var posts = [MapPost]()
            let snapshot = try await query.getDocuments()
            for doc in snapshot.documents {
                guard var mapPost = try? doc.data(as: MapPost.self),
                      !(mapPost.flagged),
                      !(mapPost.userInfo?.id?.isBlocked() ?? false),
                      !(mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false),
                      !(mapPost.privacyLevel == "invite"),
                      !(mapPost.hideFromFeed ?? false),
                      !UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? ""),
                      !presentedPostIDs.contains(doc.documentID)
                else {
                    continue
                }
                mapPost.postScore = mapPost.getSpotPostScore()
                posts.append(mapPost)
            }
            return posts
        } catch {
            return []
        }
    }

    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            // order by timestamp in case function fails with a lot of documents
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID).order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    guard let snapshot, error == nil else {
                        completion?(error)
                        return
                    }
                    for doc in snapshot.documents {
                        doc.reference.updateData([FirebaseCollectionFields.inviteList.rawValue: FieldValue.arrayUnion(inviteList)])
                        doc.reference.updateData([FirebaseCollectionFields.friendsList.rawValue: FieldValue.arrayUnion(inviteList)])
                    }
                }
        }
    }
    
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?) {
        fireStore.collection(FirebaseCollectionNames.posts.rawValue)
            .whereField(FirebaseCollectionFields.posterID.rawValue, isEqualTo: friendID)
            .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
            .getDocuments { snapshot, _ in
                guard let snapshot else {
                    completion?(false)
                    return
                }
                
                for doc in snapshot.documents {
                    let hideFromFeed = doc.get(FirebaseCollectionFields.hideFromFeed.rawValue) as? Bool ?? false
                    let privacyLevel = doc.get(FirebaseCollectionFields.privacyLevel.rawValue) as? String ?? "friends"
                    if !hideFromFeed && privacyLevel != "invite" {
                        doc.reference.updateData(
                            [
                                FirebaseCollectionFields.friendsList.rawValue: FieldValue.arrayUnion([userID])
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
                .collection(FirebaseCollectionFields.comments.rawValue)
                .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                .getDocuments { snapshot, _ in
                    guard let snapshot,
                          !snapshot.documents.isEmpty
                    else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    Task(priority: .high) {
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
                        
                        let post = await self.setPostDetails(post: postInfo)
                        continuation.resume(returning: post)
                    }
                }
        }
    }
    /*
    private func fetchImagesFromPost(post: MapPost) {
        DispatchQueue.global(qos: .utility).async {
            let size = CGSize(
                width: UIScreen.main.bounds.width * 2,
                height: UIScreen.main.bounds.width * 2
            )
            
            self.imageVideoService.downloadGIFsFramesInBackground(
                urls: post.imageURLs,
                frameIndexes: post.frameIndexes,
                aspectRatios: post.aspectRatios,
                size: size
            )
        }
    }
    */

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

    // function will fetch user info
    func getPostsFrom(query: Query, caller: MapServiceCaller, limit: Int) async throws -> (posts: [MapPost]?, endDocument: DocumentSnapshot?) {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snap, error in
                guard error == nil, let docs = snap?.documents, !docs.isEmpty
                else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ([], nil))
                    }
                    return
                }

                Task {
                    var posts: [MapPost] = []
                    let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.last
                    for doc in docs {
                        defer {
                            if doc == docs.last {
                                continuation.resume(returning: (posts, endDocument))
                            }
                        }

                        guard var postInfo = try? doc.data(as: MapPost.self) else { continue }
                        if !self.hasPostAccess(postInfo: postInfo, caller: caller) { continue }

                        let userService = try ServiceContainer.shared.service(for: \.userService)
                        let user = try await userService.getUserInfo(userID: postInfo.posterID)
                        postInfo.userInfo = user

                        let comments = try await self.getComments(postID: postInfo.id ?? "")
                        postInfo.commentList = comments

                        postInfo.generateSnapshot()

                        posts.append(postInfo)
                    }
                }
            }
        }
    }

    private func hasPostAccess(postInfo: MapPost, caller: MapServiceCaller) -> Bool {
        if UserDataModel.shared.deletedPostIDs.contains(postInfo.id ?? "_") || postInfo.posterID.isBlocked() { return false }
        switch caller {
        case .Profile:
            if postInfo.privacyLevel == "invite" {
                return postInfo.inviteList?.contains(UserDataModel.shared.uid) ?? false
            }
            return true
        case .CustomMap, .Explore:
            return true
        case .Spot:
            if postInfo.privacyLevel == "invite" {
                if postInfo.hideFromFeed ?? false {
                    return (postInfo.inviteList?.contains(UserDataModel.shared.uid)) ?? false
                } else {
                    return UserDataModel.shared.userInfo.friendIDs.contains(postInfo.posterID) || UserDataModel.shared.uid == postInfo.posterID
                }
            }
            return true
        default:
            return false
        }
    }
    
    func uploadPost(post: MapPost, spot: MapSpot) {
        /// send local notification first
        guard let postID = post.id else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let parentPostID = post.parentPostID {
                let postRef = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(parentPostID).collection(FirebaseCollectionNames.comments.rawValue).document(postID)
                try? postRef?.setData(from: post)

                if let parentPosterID = post.parentPosterID {
                    let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
                    friendService?.incrementTopFriends(friendID: parentPosterID, increment: 3, completion: nil)
                }
            } else {
                let postRef = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(postID)
                try? postRef?.setData(from: post)
            }
        }
    }
    
    func updateMapNameInPosts(mapID: String, newName: String) {
        DispatchQueue.global().async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID)
                .getDocuments { snap, _ in
                    guard let snap = snap else { return }
                    for postDoc in snap.documents {
                        postDoc.reference.updateData([FirebaseCollectionFields.mapName.rawValue: newName])
                    }
                }
        }
    }
    
    func likePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in

            let values: [String: Any] = [FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])]
            let collectionReference = self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)

            if let parentID = post.parentPostID, parentID != "" {
                // like comment
                collectionReference?.document(parentID).collection(FirebaseCollectionNames.comments.rawValue).document(post.id ?? "").updateData(values)
            } else {
                // like post
                collectionReference?.document(post.id ?? "").updateData(values)
            }

            if post.posterID == UserDataModel.shared.uid { return }
            
            let likeNotiValues: [String: Any] = [
                "imageURL": post.imageURLs.first ?? "",
                "originalPoster": post.userInfo?.username ?? "",
                "postID": post.id ?? "",
                "seen": false,
                "senderID": UserDataModel.shared.uid,
                "senderUsername": UserDataModel.shared.userInfo.username,
                "spotID": post.spotID ?? "",
                "timestamp": Timestamp(date: Date()),
                "type": "like"
            ] as [String: Any]
            
            self?.fireStore.collection("users").document(post.posterID).collection("notifications").addDocument(data: likeNotiValues)

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
        fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(post.id ?? "").updateData([PostCollectionFields.hiddenBy.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])])
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
    
    func setSeen(post: MapPost) {
        guard let id = post.id,
              let uid = Auth.auth().currentUser?.uid,
              !(post.seenList?.contains(UserDataModel.shared.uid) ?? false)
        else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            if let parentPostID = post.parentPostID {
                self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                    .document(parentPostID)
                    .collection(FirebaseCollectionNames.comments.rawValue).document(id)
                    .updateData(
                        [
                            FirebaseCollectionFields.seenList.rawValue: FieldValue.arrayUnion([uid])
                        ]
                    )
            } else {
                self?.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .document(id)
                    .updateData(
                        [
                            FirebaseCollectionFields.seenList.rawValue: FieldValue.arrayUnion([uid])
                        ]
                    )
            }
            
            NotificationCenter.default.post(Notification(name: Notification.Name("PostOpen"), object: nil, userInfo: ["post": post as Any]))
            
            self?.updateNotifications(postID: id, uid: uid)
        }
    }

    private func updateNotifications(postID: String, uid: String) {
        fireStore
            .collection(FirebaseCollectionNames.users.rawValue)
            .document(uid)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .whereField("postID", isEqualTo: postID)
            .getDocuments { snap, _ in
                guard let snap = snap else { return }
                UserDataModel.shared.setSeenForDocumentIDs(docIDs: snap.documents.map({ $0.documentID }))
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
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(postID).updateData([
                PostCollectionFields.reportedBy.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid])
            ])
        }
    }

    func incrementSpotScoreFor(userID: String, increment: Int) {
        DispatchQueue.global(qos: .utility).async {
            self.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(userID).updateData(["spotScore": FieldValue.increment(Int64(increment))])
        }
    }

    private func incrementMapScoreFor(post: MapPost, increment: Int) {
        if let mapID = post.mapID, mapID != "" {
            DispatchQueue.global(qos: .background).async {
                self.fireStore.collection(FirebaseCollectionNames.maps.rawValue).document(mapID).updateData(["mapScore": FieldValue.increment(Int64(increment))])
            }
        }
    }
}
