//
//  AllPostsViewModel.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Combine
import Firebase
import FirebaseFirestore
import FirebaseStorage
import IdentifiedCollections
import Mixpanel

final class AllPostsViewModel {
    
    typealias Section = AllPostsViewController.Section
    typealias Item = AllPostsViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let lastFriendsItemListener: PassthroughSubject<Bool, Never>
        let lastMapItemListener: PassthroughSubject<Bool, Never>
        let limit: PassthroughSubject<Int, Never>
        let lastFriendsItem: PassthroughSubject<DocumentSnapshot?, Never>
        let lastMapItem: PassthroughSubject<DocumentSnapshot?, Never>
        let changedDocumentIDs: PassthroughSubject<[String], Never>
    }
    
    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }
    
    private let cacheKey = "AllPosts"
    let mapService: MapServiceProtocol
    let postService: MapPostServiceProtocol
    let spotService: SpotServiceProtocol
    private let userService: UserServiceProtocol
    let imageVideoService: ImageVideoServiceProtocol
    private(set) var lastMapItem: DocumentSnapshot?
    private(set) var lastFriendsItem: DocumentSnapshot?
    
    var presentedPosts: IdentifiedArrayOf<MapPost> = []

    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService),
              let imageVideoService = try? serviceContainer.service(for: \.imageVideoService)
        else {
            mapService = MapService(fireStore: Firestore.firestore())
            imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            spotService = SpotService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            return
        }
        
        self.userService = userService
        self.spotService = spotService
        self.mapService = mapService
        self.postService = postService
        self.imageVideoService = imageVideoService
    }
    
    func bind(to input: Input) -> Output {
        let requestItems = Publishers.CombineLatest4(
            input.refresh,
            input.limit.removeDuplicates(),
            input.lastMapItem.removeDuplicates(),
            input.lastFriendsItem.removeDuplicates()
        )
            .receive(on: DispatchQueue.global(qos: .background))
        
        let requestFromListeners = Publishers.CombineLatest3(
            input.lastFriendsItemListener
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .background)),
            
            input.lastMapItemListener
                .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .background)),

            input.changedDocumentIDs
        )
            .receive(on: DispatchQueue.global(qos: .background))

        let request = Publishers.CombineLatest(requestItems, requestFromListeners)
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [unowned self] requestItemsPublisher, requestFromListenersPublisher in
                self.fetchPosts(
                    forced: requestItemsPublisher.0,
                    limit: requestItemsPublisher.1,
                    lastMapItem: requestItemsPublisher.2,
                    lastFriendsItem: requestItemsPublisher.3,
                    lastFriendsItemForced: requestFromListenersPublisher.0,
                    lastMapItemForced: requestFromListenersPublisher.1,
                    changedDocumentIDs: requestFromListenersPublisher.2
                )
            }
            .switchToLatest()
            .map { $0 }
        
        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { posts in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                _ = posts.map {
                    snapshot.appendItems([.item(post: $0)], toSection: .main)
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        
        return Output(snapshot: snapshot)
    }
    
    func updatePostIndex(post: MapPost) {
        postService.setSeen(post: post)
    }
    
    func updatePost(id: String?, update: MapPost) {
        guard let id, !id.isEmpty, self.presentedPosts[id: id] != nil else {
            return
        }

        self.presentedPosts[id: id] = update
    }
    
    func deletePost(id: String) {
        guard !id.isEmpty, let post = self.presentedPosts[id: id] else {
            return
        }
        
        presentedPosts.removeAll(where: { $0 == post })
    }
    
    func likePost(id: String) {
        guard !id.isEmpty, var post = self.presentedPosts[id: id] else {
            return
        }
        
        if post.likers.contains(UserDataModel.shared.uid) {
            unlikePost(id: id)
            
        } else {
            post.likers.append(UserDataModel.shared.uid)
            self.presentedPosts[id: id] = post
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.postService.likePostDB(post: post)
                Mixpanel.mainInstance().track(event: "PostPageLikePost")
            }
        }
    }
    
    func unlikePost(id: String) {
        guard !id.isEmpty, var post = self.presentedPosts[id: id] else {
            return
        }
        
        if !post.likers.contains(UserDataModel.shared.uid) {
            likePost(id: id)
        } else {
            post.likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            self.presentedPosts[id: id] = post
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.postService.unlikePostDB(post: post)
                Mixpanel.mainInstance().track(event: "PostPageUnlikePost")
            }
        }
    }
    
    func addNewPost(post: MapPost) {
        presentedPosts.insert(post, at: 0)
    }
    
    private func fetchPosts(
        forced: Bool,
        limit: Int,
        lastMapItem: DocumentSnapshot?,
        lastFriendsItem: DocumentSnapshot?,
        lastFriendsItemForced: Bool,
        lastMapItemForced: Bool,
        changedDocumentIDs: [String]
    ) -> AnyPublisher<[MapPost], Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }

                guard forced else {
                    promise(.success(self.presentedPosts.elements))
                    return
                }

                if lastFriendsItemForced || lastMapItemForced {
                    Task {
                        let data = await self.fetchPostsWithListeners(friends: lastFriendsItemForced, map: lastMapItemForced)

                        let sortedPosts = data.0.sorted { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen }
                        let posts = (sortedPosts + self.presentedPosts.elements).removingDuplicates()


                        /*
                        if changedDocumentIDs.isEmpty {
                            // only resort for new posts
                            let sortedPosts = data.0.sorted { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen }
                            posts = (sortedPosts + self.presentedPosts.elements).removingDuplicates()

                        } else {
                            // replace old posts with changes -> use seenPostsCache to preserve local seenList updates
                            posts = self.presentedPosts.elements
                            for changedDocumentID in changedDocumentIDs {
                                if let newPost = data.0.first(where: { $0.id == changedDocumentID }) {
                                    if let i = posts.firstIndex(where: { $0.id == changedDocumentID }) {
                                        // avoid unnecessary upates on seenList
                                        // update only values user will see -> unnecessary updates to seenList causing issues
                                        if newPost.likers.count != posts[i].likers.count || newPost.commentCount ?? 0 != posts[i].commentCount ?? 0 {
                                            posts[i].likers = newPost.likers
                                            posts[i].commentCount = newPost.commentCount
                                            posts[i].commentList = newPost.commentList
                                        }
                                    } else {
                                        posts.insert(newPost, at: 0)
                                    }
                                }
                            }
                        }
                        */

                        // patch to avoid feed unnecessarily refreshing when posts is set
                        promise(.success(posts))
                        if posts.contains(where: { !$0.seen }) {
                            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UnseenMyPosts")))
                        }

                        if !posts.isEmpty {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }
                    }
                    
                    return
                }

                Task(priority: .high) {
                    let data = await self.postService.fetchAllPostsForCurrentUser(limit: limit, lastMapItem: lastMapItem, lastFriendsItem: lastFriendsItem)
                    
                    let sortedPosts = data.0.sorted { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen }
                    let posts = (self.presentedPosts.elements + sortedPosts).removingDuplicates()
                    promise(.success(posts))

                    if self.presentedPosts.isEmpty && data.0.contains(where: { !$0.seen }) {
                        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UnseenMyPosts")))
                    }
                    
                    if !posts.isEmpty {
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                    }

                    self.lastMapItem = data.1
                    self.lastFriendsItem = data.2
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func fetchPostsWithListeners(friends: Bool, map: Bool) async -> ([MapPost], DocumentSnapshot?, DocumentSnapshot?) {
        var posts: [MapPost] = []
        var lastMapItem = self.lastMapItem
        var lastFriendsItem = self.lastFriendsItem

        if friends {
            let data = await self.postService.fetchAllPostsForCurrentUser(limit: 8, lastMapItem: lastMapItem, lastFriendsItem: nil)
            posts.append(contentsOf: data.0)
            lastMapItem = data.2
        }
        
        if map {
            let data = await self.postService.fetchAllPostsForCurrentUser(limit: 8, lastMapItem: nil, lastFriendsItem: lastFriendsItem)
            posts.append(contentsOf: data.0)
            lastFriendsItem = data.1
        }

        // return lastMapItem / lastFriendsItem to set on initial fetch
        return (posts, lastMapItem, lastFriendsItem)
    }
}
