//
//  NearbyPostsViewModel.swift
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

final class NearbyPostsViewModel {
    typealias Section = NearbyPostsViewController.Section
    typealias Item = NearbyPostsViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let forced: PassthroughSubject<Bool, Never>
        let limit: PassthroughSubject<Int, Never>
    }
    
    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }
    
    private let cacheKey = "NearbyPosts"
    let mapService: MapServiceProtocol
    let postService: MapPostServiceProtocol
    let spotService: SpotServiceProtocol
    private let userService: UserServiceProtocol
    let imageVideoService: ImageVideoServiceProtocol
    private(set) var lastItem: DocumentSnapshot?
    
    private var presentedPosts: IdentifiedArrayOf<MapPost> = []
    private var cachedPostObjects: [MapPost] = []
    
    init(serviceContainer: ServiceContainer) {
        guard let mapService = try? serviceContainer.service(for: \.mapsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService),
              let imageVideoService = try? serviceContainer.service(for: \.imageVideoService)
        else {
            mapService = MapService(fireStore: Firestore.firestore())
            spotService = SpotService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            return
        }
        
        self.userService = userService
        self.spotService = spotService
        self.mapService = mapService
        self.postService = postService
        self.imageVideoService = imageVideoService
    }
    
    func bind(to input: Input) -> Output {
        let request = Publishers.CombineLatest3(
            input.refresh,
            input.forced,
            input.limit.removeDuplicates()
        )
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [unowned self] refresh, forced, limit in
                self.fetchPosts(refresh: refresh, forced: forced, limit: limit)
            }
            .switchToLatest()
            .map { $0 }

        let snapshot = request
            .removeDuplicates()
            .receive(on: DispatchQueue.global(qos: .background))
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
    
    private func fetchPosts(refresh: Bool, forced: Bool, limit: Int) -> AnyPublisher<[MapPost], Never> {
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

                if forced {
                    Task(priority: .high) {
                        // insert new posts at top of feed
                        let data = await self.postService.fetchNearbyPosts(limit: limit, lastItem: self.lastItem, cachedPosts: self.cachedPostObjects)
                        let sortedPosts = data.0.sorted { $0.postScore ?? 0 > $1.postScore ?? 0 }
                        let posts = (sortedPosts + self.presentedPosts.elements).removingDuplicates()

                        promise(.success(posts))
                        self.cachedPostObjects = data.2
                        if let lastItem = data.1 {
                            self.lastItem = lastItem
                        }

                        if !posts.isEmpty {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }
                    }

                } else {
                    Task(priority: .high) {
                        // append new posts to bottom of feed
                        let data = await self.postService.fetchNearbyPosts(limit: limit, lastItem: self.lastItem, cachedPosts: self.cachedPostObjects)
                        let sortedPosts = data.0.sorted { $0.postScore ?? 0 > $1.postScore ?? 0 }
                        let posts = (self.presentedPosts.elements + sortedPosts).removingDuplicates()

                        promise(.success(posts))

                        self.cachedPostObjects = data.2
                        if let lastItem = data.1 {
                            self.lastItem = lastItem
                        }

                        if !posts.isEmpty {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
