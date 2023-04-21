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
    case nearby = "NEARBY"
    case friends = "FRIENDS"
    case maps = "MAPS"
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
    func fetchAllPostsForCurrentUser(limit: Int, lastFriendsItem: DocumentSnapshot?) async -> ([MapPost], DocumentSnapshot?)
    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?, cachedPosts: [MapPost]) async -> ([MapPost], DocumentSnapshot?, [MapPost])
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?)
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?)
    func getPostsFrom(query: Query, caller: MapServiceCaller, limit: Int) async throws -> (posts: [MapPost]?, endDocument: DocumentSnapshot?)
    func getComments(postID: String) async throws -> [MapComment]
    func getPost(postID: String) async throws -> MapPost
    func setPostDetails(post: MapPost) async -> MapPost
    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool)
    func updateMapNameInPosts(mapID: String, newName: String)
    func likePostDB(post: MapPost)
    func unlikePostDB(post: MapPost)
    func runDeletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool)
    func setSeen(post: MapPost)
    func reportPost(postID: String, feedbackText: String, userId: String)
    func incrementSpotScoreFor(post: MapPost, increment: Int)
}

final class MapPostService: MapPostServiceProtocol {
    enum MapPostServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    private let imageVideoService: ImageVideoServiceProtocol
    private var lastMapDocument: DocumentSnapshot?
    private var lastFriendsDocument: DocumentSnapshot?
    private var lastNearbysDocument: DocumentSnapshot?
    
    init(fireStore: Firestore, imageVideoService: ImageVideoServiceProtocol) {
        self.fireStore = fireStore
        self.imageVideoService = imageVideoService
    }
    
    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?, cachedPosts: [MapPost]) async -> ([MapPost], DocumentSnapshot?, [MapPost]) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                guard let locationService = try? ServiceContainer.shared.service(for: \.locationService),
                      let currentLocation = locationService.currentLocation
                else {
                    continuation.resume(returning: ([], lastItem, []))
                    return
                }

                // return details for cached posts if they exist
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
                
                async let city = locationService.getCityFromLocation(location: currentLocation, zoomLevel: 0)

                var request = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .whereField(FirebaseCollectionFields.city.rawValue, isEqualTo: await city)
                    .whereField(FirebaseCollectionFields.privacyLevel.rawValue, isEqualTo: "public")
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                
                if let lastItem {
                    request = request.start(afterDocument: lastItem)
                }
                
                let requests: [RequestBody] = [RequestBody(query: request, type: .nearby)]

                // modified function to only fetch details for top 10 posts
                // should improve performance: increase initial query size, and decrease subsequent fetches
                // drop the bottom 15 cached posts to get rid of low performers
                async let fetchPosts = requests.throwingAsyncValues { requestBody in
                    async let snapshot = self.fetchSnapshot(request: requestBody)
                    let sortedPosts = await self.fetchNearbyPostObjects(snapshot: snapshot).sorted(by: { $0?.postScore ?? 0 > $1?.postScore ?? 0 })
                    var postsToCache = [MapPost]()
                    var finalPosts = [MapPost]()
                    // append first 10 posts, cache the remaining posts for pagination
                    for i in 0..<sortedPosts.count {
                        if i < 10, let post = sortedPosts[i] {
                            let post = await self.setPostDetails(post: post)
                            finalPosts.append(post)
                        } else if i < sortedPosts.count - 15, let post = sortedPosts[i] {
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
                        self.lastNearbysDocument,
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
                    RequestBody(query: friendsQuery, type: .friends)
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
                        self.lastFriendsDocument
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
                
                switch request.type {
                case .nearby:
                    self.lastNearbysDocument = snapshot.documents.last
                case .friends:
                    self.lastFriendsDocument = snapshot.documents.last
                default:
                    return
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
               !(mapPost.flagged ?? false),
               !(mapPost.userInfo?.id?.isBlocked() ?? false),
               !((mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) || UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? "")) {
                return await self.setPostDetails(post: mapPost)
            } else {
                return nil
            }
        }
    }

    private func fetchNearbyPostObjects(snapshot: QuerySnapshot?) async -> [MapPost?] {
        guard let snapshot else {
            return []
        }
        return await snapshot.documents.throwingAsyncValues { document in
            guard var mapPost = try? document.data(as: MapPost.self),
                  !(mapPost.flagged ?? false),
                  !(mapPost.userInfo?.id?.isBlocked() ?? false),
                  !(mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false),
                  !UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? "")
            else {
                return nil
            }
            mapPost.postScore = mapPost.getNearbyPostScore()
            return mapPost
        }
    }

    /*
    private func fetchNearbyPostDetails(snapshot: QuerySnapshot?) async -> [MapPost?] {
        guard let snapshot else {
            return []
        }

        return await snapshot.documents.throwingAsyncValues { document in
            guard let mapPost = try? document.data(as: MapPost.self),
                  !(mapPost.userInfo?.id?.isBlocked() ?? false),
                  !(mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false),
                  !UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? "")
            else {
                return nil
            }
            
            return await self.setPostDetails(post: mapPost)
        }
    }
    */
    
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
    func setPostDetails(post: MapPost) async -> MapPost {
        return await withUnsafeContinuation { continuation in
            guard let id = post.id, !id.isEmpty else {
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
                postInfo.userInfo = user
                let comments = try? await getComments(postID: id)
                postInfo.commentList = comments ?? []
             //   postInfo.postScore = post.getNearbyPostScore()
                postInfo.generateSnapshot()
                continuation.resume(returning: postInfo)
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
    
    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool) {
        /// send local notification first
        guard let postID = post.id else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
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
            notiPost.userInfo = UserDataModel.shared.userInfo
            notiPost.generateSnapshot()

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
            
            let postRef = self?.fireStore.collection("posts").document(postID)
            var post = post
            post.g = GFUtils.geoHash(forLocation: post.coordinate)
            try? postRef?.setData(from: post)

            if !newMap {
                /// send new map notis for new map
                self?.sendPostNotifications(post: post, map: map, spot: spot)
            }
            
            let commentRef = postRef?.collection("comments").document(commentObject.id ?? "")
            try? commentRef?.setData(from: commentObject)
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
            
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(post.id ?? "").updateData([
                FirebaseCollectionFields.likers.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])
            ])
            
            if post.posterID == UserDataModel.shared.uid { return }
            
            var likeNotiValues: [String: Any] = [
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
            
            likeNotiValues["type"] = "likeOnAdd"
            for user in post.taggedUserIDs ?? [] {
                // don't send noti to current user
                if user == UserDataModel.shared.uid { continue }
                self?.fireStore.collection("users").document(user).collection("notifications").addDocument(data: likeNotiValues)
            }
            
            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)

            self?.incrementSpotScoreFor(post: post, increment: 3)
            self?.incrementMapScoreFor(post: post, increment: 5)
        }
        let infoPass = ["post": post, "like": true] as [String: Any]
        NotificationCenter.default.post(name: Notification.Name("PostChanged"), object: nil, userInfo: infoPass)
    }

    func unlikePostDB(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection("posts").document(post.id ?? "").updateData([
                "likers": FieldValue.arrayRemove([UserDataModel.shared.uid])
            ])
            
            let functions = Functions.functions()
            functions.httpsCallable("unlikePost").call(["postID": post.id ?? "", "posterID": post.posterID, "likerID": UserDataModel.shared.uid]) { result, error in
                print(result?.data as Any, error as Any)
            }
            
            let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
            friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)
        }

        let infoPass = ["post": post, "like": true] as [String: Any]
        NotificationCenter.default.post(name: Notification.Name("PostChanged"), object: nil, userInfo: infoPass)
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
    
    func runDeletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        fireStore.collection("mapLocations").document(post.id ?? "").delete()
        var posters = [UserDataModel.shared.uid]
        posters.append(contentsOf: post.addedUsers ?? [])
        let functions = Functions.functions()
        functions.httpsCallable("postDelete").call([
            "postIDs": [post.id],
            "spotID": post.spotID ?? "",
            "mapID": post.mapID ?? "",
            "uid": UserDataModel.shared.uid,
            "posters": posters,
            "spotDelete": spotDelete,
            "mapDelete": mapDelete,
            "spotRemove": spotRemove
        ] as [String : Any]) { result, error in
            print("result", result?.data as Any, error as Any)
        }
    }
    
    func setSeen(post: MapPost) {
        guard let id = post.id, let uid = Auth.auth().currentUser?.uid else { return }
        let newUser = !(post.seenList?.contains(UserDataModel.shared.uid) ?? false)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fireStore
                .collection(FirebaseCollectionNames.posts.rawValue)
                .document(id)
                .updateData(
                    [
                        FirebaseCollectionFields.seenList.rawValue: FieldValue.arrayUnion([uid])
                    ]
                )
            
            NotificationCenter.default.post(Notification(name: Notification.Name("PostOpen"), object: nil, userInfo: ["post": post as Any]))
            
            self?.updateNotifications(postID: id, uid: uid)

            if newUser {
                self?.incrementMapScoreFor(post: post, increment: 1)
            }
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
    
    func reportPost(postID: String, feedbackText: String, userId: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection("feedback")
                .addDocument(
                    data: [
                        "feedbackText": feedbackText,
                        "postID": postID,
                        "type": "reportPost",
                        "userID": userId
                    ]
                )
            self?.fireStore.collection("posts").document(postID).updateData(["flagged" : true])
        }
    }

    func incrementSpotScoreFor(post: MapPost, increment: Int) {
        DispatchQueue.global(qos: .utility).async {
            self.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(post.posterID).updateData(["spotScore": FieldValue.increment(Int64(increment))])
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
