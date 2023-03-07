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
import PINCache

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
    
    private let cacheKey = "AllPosts"
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
    
    // Maybe it's not possible to delete nearby post that you didn't post?
    // TODO: Write function to read and update from cache for the UI
    func deletePost(post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in

            // postService.deletePost()
        }
    }
    
    // TODO: Write function to read and update from cache for the UI
    func likePost(post: MapPost?) {
        guard let post else {
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService.likePostDB(post: post)
        }
    }
    
    // TODO: Write function to read and update from cache for the UI
    func unlikePost(post: MapPost?) {
        guard let post else {
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.postService.unlikePostDB(post: post)
        }
    }
    
    private func fetchPosts(forced: Bool, limit: Int, lastMapItem: DocumentSnapshot?, lastFriendsItem: DocumentSnapshot?) -> AnyPublisher<[MapPost], Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }
                
                guard forced else {
                    promise(.success([]))
                    return
                }
                
                Task(priority: .high) {
                    let data = await self.postService.fetchAllPostsForCurrentUser(limit: limit, lastMapItem: lastMapItem, lastFriendsItem: lastFriendsItem)
                    promise(.success(data.0))
                    self.lastMapItem = data.1
                    self.lastFriendsItem = data.2
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
