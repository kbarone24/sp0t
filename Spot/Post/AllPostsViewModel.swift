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
        let lastFriendsItem: PassthroughSubject<DocumentSnapshot?, Never>
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
    private(set) var lastFriendsItem: DocumentSnapshot?
    
    var presentedPosts: IdentifiedArrayOf<MapPost> = []

    var addedPostIDs: [String] = []
    var removedPostIDs: [String] = []
    var modifiedPostIDs: [String] = []

    let limit = 15
    var disablePagination = false

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
        let requestItems = Publishers.CombineLatest3(
            input.refresh,
            input.lastFriendsItem.removeDuplicates(),
            input.lastFriendsItemListener.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .background))
        )
            .receive(on: DispatchQueue.global(qos: .background))

        let request = requestItems
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [unowned self] requestItemsPublisher in
                self.fetchPosts(
                    refresh: requestItemsPublisher.0,
                    lastFriendsItem: requestItemsPublisher.1,
                    lastFriendsItemForced: requestItemsPublisher.2
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
        refresh: Bool,
        lastFriendsItem: DocumentSnapshot?,
        lastFriendsItemForced: Bool
    ) -> AnyPublisher<[MapPost], Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }

                guard refresh else {
                    promise(.success(self.presentedPosts.elements))
                    return
                }

                if lastFriendsItemForced {
                    Task {
                        let data = await self.fetchPostsWithListener(friends: lastFriendsItemForced)

                        var posts = self.presentedPosts.elements
                        for id in self.modifiedPostIDs {
                            if let i = posts.firstIndex(where: { $0.id == id }), let newPost = data.first(where: { $0.id == id }) {
                                posts[i].likers = newPost.likers
                                posts[i].commentCount = newPost.commentCount
                                posts[i].commentList = newPost.commentList
                            }
                        }

                        for id in self.removedPostIDs where !data.contains(where: { $0.id == id }) {
                            posts.removeAll(where: { $0.id == id })
                        }

                        for id in self.addedPostIDs {
                            if let newPost = data.first(where: { $0.id == id }), !newPost.seen {
                                posts.insert(newPost, at: 0)
                            }
                            self.disablePagination = false
                        }

                        posts = posts.removingDuplicates()
                        promise(.success(posts))

                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)

                        if !self.addedPostIDs.isEmpty, posts.contains(where: { !$0.seen }) {
                            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UnseenMyPosts")))
                        }

                    }
                    
                    return
                }

                Task(priority: .high) {
                    let data = await self.postService.fetchAllPostsForCurrentUser(limit: self.limit, lastFriendsItem: lastFriendsItem)
                    
                    let sortedPosts = data.0.sorted { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : !$0.seen && $1.seen }
                    if sortedPosts.isEmpty {
                        self.disablePagination = true
                    }

                    let posts = (self.presentedPosts.elements + sortedPosts).removingDuplicates()
                    promise(.success(posts))

                    if self.presentedPosts.isEmpty && data.0.contains(where: { !$0.seen }) {
                        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "UnseenMyPosts")))
                    }

                    if !posts.isEmpty {
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                    }

                    self.lastFriendsItem = data.1
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func fetchPostsWithListener(friends: Bool) async -> ([MapPost]) {
        var posts: [MapPost] = []
        let data = await self.postService.fetchAllPostsForCurrentUser(limit: max(presentedPosts.count, 15), lastFriendsItem: nil)
        posts.append(contentsOf: data.0)
        return posts
    }

    func joinMap(mapID: String) {
        // append dummy map so that map shows as joined when cell reloads -> will be replaced after map object is fetched
        var dummyMap = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: "",
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: [])
        dummyMap.id = mapID
        UserDataModel.shared.userInfo.mapsList.append(dummyMap)
        DispatchQueue.global(qos: .background).async {
            Task {
                let map = try await self.mapService.getMap(mapID: mapID)
                if let i = UserDataModel.shared.userInfo.mapsList.firstIndex(where: { $0.id == mapID }) {
                    UserDataModel.shared.userInfo.mapsList[i] = map
                }

                self.mapService.followMap(customMap: map) { _ in }
            }
        }
    }
}
