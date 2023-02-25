//
//  MapPostService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import CoreLocation
import GeoFire

enum MapServiceCaller {
    case Profile
    case Spot
    case CustomMap
    case Feed
}

protocol MapPostServiceProtocol {
    func fetchAllPostsForCurrentUser(limit: Int, lastMapItem: DocumentSnapshot?, lastFriendsItem: DocumentSnapshot?) async throws -> ([MapPost], DocumentSnapshot?, DocumentSnapshot?)
    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?) async throws ->  ([MapPost], DocumentSnapshot?)
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?)
    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?)
    func getComments(postID: String) async throws -> [MapComment]
    func getPost(postID: String) async throws -> MapPost
    func getPostDocuments(query: Query) async throws -> [MapPost]?
    func getPostsFrom(query: Query, caller: MapServiceCaller, limit: Int) async throws -> (posts: [MapPost]?, endDocument: DocumentSnapshot?)
    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void)
    func getNearbyPosts(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping([MapPost]) -> Void) async
    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool)
    func updateMapNameInPosts(mapID: String, newName: String)
    func likePostDB(post: MapPost)
    func unlikePostDB(post: MapPost)
    func runDeletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool)
    func setSeen(post: MapPost)
    func reportPost(postID: String, feedbackText: String, userId: String)
}

final class MapPostService: MapPostServiceProtocol {
    enum MapPostServiceError: Error {
        case decodingError
    }
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func fetchNearbyPosts(limit: Int, lastItem: DocumentSnapshot?) async throws -> ([MapPost], DocumentSnapshot?) {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self, !UserDataModel.shared.userCity.isEmpty else {
                continuation.resume(returning: ([], nil))
                return
            }
            
            var request = self.fireStore
                .collection(FirebaseCollectionNames.posts.rawValue)
                .limit(to: limit)
                .whereField(FirebaseCollectionFields.city.rawValue, isEqualTo: UserDataModel.shared.userCity)
                .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
            
            if let lastItem {
                request.start(afterDocument: lastItem)
            }
            
            request.getDocuments { snapshot, error in
                guard let snapshot, error == nil else {
                    continuation.resume(returning: ([], nil))
                    return
                }
                
                var posts: [MapPost] = []
                var lastDocument: DocumentSnapshot?
                
                snapshot.documents.forEach { document in
                    guard let mapPost = try? document.data(as: MapPost.self) else {
                        return
                    }
                    
                    guard mapPost.privacyLevel == "public",
                          !mapPost.friendsList.contains(UserDataModel.shared.uid),
                          !(mapPost.inviteList?.contains(UserDataModel.shared.uid) ?? false),
                          !(mapPost.userInfo?.id?.isBlocked() ?? false),
                          !((mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) || UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? ""))
                    else {
                        return
                    }
                    
                    self.setPostDetails(post: mapPost) { data in
                        defer {
                            if document == snapshot.documents.last {
                                lastDocument = document
                                continuation.resume(
                                    returning: (
                                        posts.sorted {
                                            $0.postScore ?? 0.0 > $1.postScore ?? 0.0
                                        },
                                        lastDocument
                                    )
                                )
                            }
                        }
                        
                        guard !(data.id?.isEmpty ?? false) else {
                            return
                        }
                        
                        var post = data
                        post.postScore = post.getNearbyPostScore()
                        posts.append(post)
                    }
                }
            }
        }
    }
    
    func fetchAllPostsForCurrentUser(limit: Int, lastMapItem: DocumentSnapshot?, lastFriendsItem: DocumentSnapshot?) async throws -> ([MapPost], DocumentSnapshot?, DocumentSnapshot?) {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(returning: ([], nil, nil))
                return
            }
            
            Task {
                var posts: [MapPost] = []
                let request = self.fireStore
                    .collection(FirebaseCollectionNames.posts.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)
                
                var friendsQuery = request.whereField(FirebaseCollectionFields.friendsList.rawValue, arrayContains: UserDataModel.shared.uid)
                
                if let lastFriendsItem {
                    friendsQuery.start(afterDocument: lastFriendsItem)
                }
                
                var mapsQuery = request.whereField(FirebaseCollectionFields.inviteList.rawValue, arrayContains: UserDataModel.shared.uid)
                
                
                if let lastMapItem {
                    mapsQuery.start(afterDocument: lastMapItem)
                }
                
                var lastMapDocument: DocumentSnapshot?
                var lastFriendsDocument: DocumentSnapshot?
                
                guard let friendsPosts = try? await self.fetchSnapshot(query: friendsQuery),
                      let mapsPosts = try? await self.fetchSnapshot(query: mapsQuery),
                      let postsFromFriends = try? await self.setPostDetails(snapshot: friendsPosts),
                      let postsFromMaps = try? await self.setPostDetails(snapshot: mapsPosts)
                else {
                    continuation.resume(returning: ([], nil, nil))
                    return
                }
                
                lastMapDocument = mapsPosts.documents.last
                lastFriendsDocument = friendsPosts.documents.last
                
                postsFromMaps.forEach {
                    posts.append($0)
                }
                
                postsFromFriends.forEach {
                    posts.append($0)
                }
                
                continuation.resume(
                    returning: (
                        posts.sorted {
                            $0.timestamp.seconds > $1.timestamp.seconds
                        },
                        lastMapDocument,
                        lastFriendsDocument
                    )
                )
            }
        }
    }
    
    private func fetchSnapshot(query: Query) async throws -> QuerySnapshot? {
        try await withUnsafeThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
                guard let snapshot, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: snapshot)
            }
        }
    }
    
    private func setPostDetails(snapshot: QuerySnapshot) async throws -> [MapPost] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            guard let self, !snapshot.documents.isEmpty else {
                continuation.resume(returning: [])
                return
            }
            
            var posts: [MapPost] = []
            snapshot.documents.forEach { document in
                guard let mapPost = try? document.data(as: MapPost.self),
                      !(mapPost.userInfo?.id?.isBlocked() ?? false),
                      !((mapPost.hiddenBy?.contains(UserDataModel.shared.uid) ?? false) || UserDataModel.shared.deletedPostIDs.contains(mapPost.id ?? ""))
                else {
                    return
                }
                
                self.setPostDetails(post: mapPost) { data in
                    defer {
                        if document == snapshot.documents.last {
                            continuation.resume(returning: posts)
                        }
                    }
                    
                    guard !(data.id?.isEmpty ?? false) else {
                        return
                    }
                    
                    var post = data
                    post.postScore = post.getNearbyPostScore()
                    posts.append(post)
                }
            }
        }
    }
    
    func updatePostInviteLists(mapID: String, inviteList: [String], completion: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID).order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    guard let snapshot, error == nil else {
                        completion?(error)
                        return
                    }
                    for doc in snapshot.documents {
                        doc.reference.updateData([FirebaseCollectionFields.inviteList.rawValue: FieldValue.arrayUnion(inviteList)])
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
        
        Task {
            var postInfo = post
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
                return
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
        case .CustomMap:
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

    func getNearbyPosts(center: CLLocationCoordinate2D, radius: CLLocationDistance, searchLimit: Int, completion: @escaping(_ post: [MapPost]) -> Void) async {
        
        Task {
            let queryBounds = GFUtils.queryBounds(
                forLocation: center,
                withRadius: radius)
            
            let seconds = Date().timeIntervalSince1970 - 86_400 * 7
            let timestamp = Timestamp(seconds: Int64(seconds), nanoseconds: 0)
            let queries = queryBounds.map { bound -> Query in
                return fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                    .order(by: "g")
                    .start(at: [bound.startValue])
                    .end(at: [bound.endValue])
                    .limit(to: searchLimit)
                    .whereField("timestamp", isGreaterThanOrEqualTo: timestamp)
            }
            
            var allPosts: [MapPost] = []
            for query in queries {
                defer {
                    if query == queries.last {
                        completion(allPosts)
                    }
                }
                
                let posts = try? await getPostDocuments(query: query)
                guard let posts else { continue }
                allPosts.append(contentsOf: posts)
            }
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
        fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(post.id ?? "").updateData([
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
        fireStore.collection("users").document(post.posterID).collection("notifications").addDocument(data: likeNotiValues)
        
        likeNotiValues["type"] = "likeOnAdd"
        for user in post.taggedUserIDs ?? [] {
            // don't send noti to current user
            if user == UserDataModel.shared.uid { continue }
            fireStore.collection("users").document(user).collection("notifications").addDocument(data: likeNotiValues)
        }
        
        let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
        friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)
    }
    
    func unlikePostDB(post: MapPost) {
        fireStore.collection("posts").document(post.id ?? "").updateData([
            "likers": FieldValue.arrayRemove([UserDataModel.shared.uid])
        ])
        
        let functions = Functions.functions()
        functions.httpsCallable("unlikePost").call(["postID": post.id ?? "", "posterID": post.posterID, "likerID": UserDataModel.shared.uid]) { result, error in
            print(result?.data as Any, error as Any)
        }
        
        let friendService = try? ServiceContainer.shared.service(for: \.friendsService)
        friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)
    }
    
    private func sendPostNotifications(post: MapPost, map: CustomMap?, spot: MapSpot?) {
        let functions = Functions.functions()
        let notiValues: [String: Any] = [
            FirebaseCollectionFields.communityMap.rawValue: map?.communityMap ?? false,
            FirebaseCollectionFields.friendIDs.rawValue: UserDataModel.shared.userInfo.friendIDs,
            FirebaseCollectionFields.imageURLs.rawValue: post.imageURLs,
            "videoURL": post.videoURL ?? "",
            FirebaseCollectionFields.mapID.rawValue: map?.id ?? "",
            FirebaseCollectionFields.mapMembers.rawValue: map?.memberIDs ?? [],
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
        ]) { result, error in
            print("result", result?.data as Any, error as Any)
        }
    }
    
    func setSeen(post: MapPost) {
        guard let id = post.id, let uid = Auth.auth().currentUser?.uid else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
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
        }
    }
}
