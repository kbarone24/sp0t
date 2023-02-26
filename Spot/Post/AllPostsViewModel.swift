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

final class AllPostsViewModel {
    
    typealias Section = AllPostsViewController.Section
    typealias Item = AllPostsViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let limit: PassthroughSubject<Int, Never>
        let lastFriendsItem: PassthroughSubject<DocumentSnapshot?, Never>
        let lastMapItem: PassthroughSubject<DocumentSnapshot?, Never>
    }
    
    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }
    
    private var cache = CacheService<String, MapPost>()
    let mapService: MapServiceProtocol
    let postService: MapPostServiceProtocol
    let spotService: SpotServiceProtocol
    private let userService: UserServiceProtocol
    let imageVideoService: ImageVideoServiceProtocol
    private(set) var lastMapItem: DocumentSnapshot?
    private(set) var lastFriendsItem: DocumentSnapshot?
    
    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService),
              let imageVideoService = try? serviceContainer.service(for: \.imageVideoService)
        else {
            mapService = MapService(fireStore: Firestore.firestore())
            postService = MapPostService(fireStore: Firestore.firestore())
            spotService = SpotService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            return
        }
        
        self.userService = userService
        self.spotService = spotService
        self.mapService = mapService
        self.postService = postService
        self.imageVideoService = imageVideoService
    }
    
    func bind(to input: Input) -> Output {
        let request = Publishers.CombineLatest4(
            input.refresh,
            input.limit,
            input.lastMapItem.removeDuplicates(),
            input.lastFriendsItem.removeDuplicates()
        )
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .background))
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [unowned self] forced, limit, lastMapItem, lastFriendsItem in
                self.fetchPosts(forced: forced, limit: limit, lastMapItem: lastMapItem, lastFriendsItem: lastFriendsItem)
            }
            .switchToLatest()
            .map { $0 }
        
        let snapshot = request
            .receive(on: DispatchQueue.global(qos: .background))
            .map { posts in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                posts.forEach {
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
    
    func deletePost(post: MapPost) {
        let items = cache.allCachedValues()
        if let cachedPost = items.first(where: { $0.id == post.id }), let id = cachedPost.id {
            cache.removeValue(forKey: id)
        }
    }
    
    func likePost(post: MapPost?) {
        guard let post else {
            return
        }
        let items = cache.allCachedValues()
        if var cachedPost = items.first(where: { $0.id == post.id }), let id = cachedPost.id {
            cachedPost.likers.append(UserDataModel.shared.uid)
            cache.removeValue(forKey: id)
            cache.insert(CacheService.Entry(key: id, value: cachedPost))
        }
        
        postService.likePostDB(post: post)
    }
    
    func unlikePost(post: MapPost?) {
        guard let post else {
            return
        }
        
        let items = cache.allCachedValues()
        if var cachedPost = items.first(where: { $0.id == post.id }), let id = cachedPost.id {
            cachedPost.likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            cache.removeValue(forKey: id)
            cache.insert(CacheService.Entry(key: id, value: cachedPost))
        }
        postService.unlikePostDB(post: post)
    }
    
    private func fetchPosts(forced: Bool, limit: Int, lastMapItem: DocumentSnapshot?, lastFriendsItem: DocumentSnapshot?) -> AnyPublisher<[MapPost], Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }
                
                guard forced else {
                    promise(.success(self.cache.allCachedValues()))
                    return
                }
                
                Task {
                    guard let data = try? await self.postService.fetchAllPostsForCurrentUser(limit: limit, lastMapItem: lastMapItem, lastFriendsItem: lastFriendsItem) else {
                        promise(.success(self.cache.allCachedValues()))
                        return
                    }
                    
                    self.lastMapItem = data.1
                    self.lastFriendsItem = data.2
                    
                    let previousCache = self.cache.allCachedValues()
                    for item in data.0 where previousCache.contains(item) {
                        self.cache.removeValue(forKey: item.id ?? "")
                        self.cache.insert(CacheService.Entry(key: item.id ?? UUID().uuidString, value: item))
                    }
                    
                    for item in data.0 where !previousCache.contains(item) {
                        self.cache.insert(CacheService.Entry(key: item.id ?? UUID().uuidString, value: item))
                    }
    
                    let posts = self.cache.allCachedValues()
                        .sorted {
                            $0.timestamp.seconds > $1.timestamp.seconds
                        }
                    
                    promise(.success(posts))
                    await self.preFetchImages(posts: posts)
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func preFetchImages(posts: [MapPost]) async {
        let size = await CGSize(
            width: UIScreen.main.bounds.width * 2,
            height: UIScreen.main.bounds.width * 2
        )
        
        for post in posts {
            _ = try? await self.imageVideoService.downloadImages(
                urls: post.imageURLs,
                frameIndexes: post.frameIndexes,
                aspectRatios: post.aspectRatios,
                size: size
            )
        }
    }
}
