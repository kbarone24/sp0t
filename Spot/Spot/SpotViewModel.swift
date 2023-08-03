//
//  Spotswift
//  SpotViewModel
//
//  Created by Kenny Barone on 7/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseStorage
import IdentifiedCollections
import Combine
import CoreLocation

final class SpotViewModel {
    typealias Section = SpotController.Section
    typealias Item = SpotController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    enum SortMethod: String {
        case New
        case Top
    }

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
   //     let spotListenerForced: PassthroughSubject<Bool, Never>
        let postListenerForced: PassthroughSubject<(Bool, (MapPost?, DocumentSnapshot?)), Never>
        let sort: PassthroughSubject<SortMethod, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    private let postService: MapPostServiceProtocol
    private let spotService: SpotServiceProtocol
    private let userService: UserServiceProtocol
    private let imageVideoService: ImageVideoServiceProtocol
    private let locationService: LocationServiceProtocol

    private let initialRecentFetchLimit = 15
    private let paginatingRecentFetchLimit = 10
    private let initialTopFetchLimit = 50
    private let paginatingTopFetchLimit = 25

    var activeSortMethod: SortMethod = .New
    var cachedSpot: MapSpot = MapSpot(id: "", spotName: "")
    var presentedPosts: IdentifiedArrayOf<MapPost> = [] {
        didSet {
            print("set")
            switch activeSortMethod {
            case .New:
                recentPosts = presentedPosts
            case .Top:
                topPosts = presentedPosts
            }
        }
    }
    var disableRecentPagination = false
    var disableTopPagination = false

    var recentPosts: IdentifiedArrayOf<MapPost> = []
    var lastRecentDocument: DocumentSnapshot?
    var topPosts: IdentifiedArrayOf<MapPost> = []
    var cachedTopPostObjects = [MapPost]()
    var lastTopDocument: DocumentSnapshot?

    var addedPostIDs = [String]()
    var removedPostIDs = [String]()
    var modifiedPostIDs = [String]()

    init(serviceContainer: ServiceContainer, spot: MapSpot) {
        guard let postService = try? serviceContainer.service(for: \.mapPostService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let userService = try? serviceContainer.service(for: \.userService),
              let imageVideoService = try? serviceContainer.service(for: \.imageVideoService),
              let locationService = try? serviceContainer.service(for: \.locationService)
        else {
            imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            spotService = SpotService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            locationService = LocationService(locationManager: CLLocationManager())
            return
        }
        self.userService = userService
        self.spotService = spotService
        self.postService = postService
        self.imageVideoService = imageVideoService
        self.locationService = locationService
        self.cachedSpot = spot
    }

    func bind(to input: Input) -> Output {
        let requestItems = Publishers.CombineLatest3(
            input.refresh,
         //   input.spotListenerForced,
            input.postListenerForced.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global(qos: .background)),
            input.sort
        )
            .receive(on: DispatchQueue.global(qos: .background))



        let request = requestItems
            .receive(on: DispatchQueue.global(qos: .background))
            .map { [unowned self] requestItemsPublisher in
                self.fetchPosts(
                    refresh: requestItemsPublisher.0,
             //       spotListenerForced: requestItemsPublisher.1,
                    postListenerForced: requestItemsPublisher.1,
                    sort: requestItemsPublisher.2)
            }
            .switchToLatest()
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { spot, posts in
                var snapshot = Snapshot()
                snapshot.appendSections([.main(spot: spot, sortMethod: self.activeSortMethod)])
                _ = posts.map {
                    snapshot.appendItems([.item(post: $0)], toSection: .main(spot: spot, sortMethod: self.activeSortMethod))
                }
                return snapshot
            }
            .eraseToAnyPublisher()

        return Output(snapshot: snapshot)
    }

    private func fetchPosts(
        refresh: Bool,
    //    spotListenerForced: Bool,
        postListenerForced: (Bool, (MapPost?, DocumentSnapshot?)),
        sort: SortMethod
    ) -> AnyPublisher<(MapSpot, [MapPost]), Never> {
        Deferred {
            Future { [weak self] promise in
                print("fetch posts")
                guard let self else {
                    promise(.success((MapSpot(id: "", spotName: ""), [])))
                    return
                }

                //MARK: local update -> return cache
                guard refresh else {
                    print("return cached posts")
                    switch self.activeSortMethod {
                    case .New:
                        let posts = self.getAllPosts(posts: self.recentPosts.elements).removingDuplicates()
                        promise(.success((self.cachedSpot, posts)))
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        
                    case .Top:
                        let posts = self.getAllPosts(posts: self.topPosts.elements).removingDuplicates()
                        promise(.success((self.cachedSpot, posts)))
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                    }
                    return
                }

                // fetching something from database
                Task {
                    let spot = try? await self.spotService.getSpot(spotID: self.cachedSpot.id ?? "")
                    guard let spotID = spot?.id else {
                        promise(.success((self.cachedSpot, self.presentedPosts.elements)))
                        return
                    }

                    guard !postListenerForced.0 else {
                        if let post = postListenerForced.1.0, let postID = post.id {
                            print("got post")
                            //MARK: Specific post sent through for comment updates
                            if let endDoc = postListenerForced.1.1 {
                                print("end doc")
                                //MARK: End document sent through (user tapped to load more comments)
                                let moreComments = await self.postService.fetchCommentsFor(post: post, limit: 3, endDocument: endDoc)

                                var posts = self.presentedPosts.elements
                                if let i = posts.firstIndex(where: { $0.id == postID }) {
                                    posts[i].postChildren?.append(contentsOf: moreComments.comments)
                                    posts[i].lastCommentDocument = moreComments.endDocument
                                }

                                posts = self.getAllPosts(posts: posts).removingDuplicates()
                                promise(.success((spot ?? self.cachedSpot, posts)))
                                self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)

                            } else {
                                //MARK: refresh comments based off of listener change
                                let limit = max(post.postChildren?.count ?? 0, 3)
                                let comments = await self.postService.fetchCommentsFor(post: post, limit: limit, endDocument: nil)
                                print("fetch new comments", comments.0.count)

                                var posts = self.presentedPosts.elements
                                if let i = posts.firstIndex(where: { $0.id == postID }) {
                                    posts[i].postChildren = comments.comments
                                }
                                
                                posts = self.getAllPosts(posts: posts).removingDuplicates()
                                promise(.success((spot ?? self.cachedSpot, posts)))
                                self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                            }

                        } else {
                            //MARK: fetch most recent posts -> limit = original fetch #
                            // called for post like or new/deleted post
                            let data = await self.postService.fetchRecentPostsFor(spotID: spotID, limit: self.initialRecentFetchLimit, endDocument: nil)
                            print("fetch recent posts")
                            var posts = self.presentedPosts.elements
                            for id in self.modifiedPostIDs {
                                if let i = posts.firstIndex(where: { $0.id == id }), let newPost = data.0.first(where: { $0.id == id }) {
                                    posts[i].likers = newPost.likers
                                    posts[i].dislikers = newPost.dislikers
                                }
                            }

                            for id in self.removedPostIDs where !data.0.contains(where: { $0.id == id }) {
                                posts.removeAll(where: { $0.id == id })
                            }

                            for id in self.addedPostIDs {
                                if let newPost = data.0.first(where: { $0.id == id }), !newPost.seen {
                                    posts.insert(newPost, at: 0)
                                }
                            }

                            posts = self.getAllPosts(posts: posts).removingDuplicates()
                            promise(.success((spot ?? self.cachedSpot, posts)))
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }
                        return
                    }

                    switch sort {
                    case .New:
                        print("new fetch")
                        //MARK: fetch new posts using last item if != nil (initial fetch or pagination)
                        let limit = self.lastRecentDocument == nil ? self.initialRecentFetchLimit : self.paginatingRecentFetchLimit
                        let data = await self.postService.fetchRecentPostsFor(spotID: spotID, limit: limit, endDocument: self.lastRecentDocument)

                        guard self.activeSortMethod != .Top else {
                            return
                        }

                        if data.0.isEmpty {
                            self.disableRecentPagination = true
                        }
                        let posts = self.getAllPosts(posts: self.recentPosts.elements + data.0).removingDuplicates()
                  //      let posts = (self.recentPosts.elements + allPosts).removingDuplicates()
                        promise(.success((spot ?? self.cachedSpot, posts)))

                        self.lastRecentDocument = data.1
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)

                    case .Top:
                        print("top fetch")
                        //MARK: Fetch top posts for algo sort
                        let postIDs = self.topPosts.elements.map({ $0.id ?? ""})
                        let limit = self.lastTopDocument == nil ? self.initialTopFetchLimit : self.paginatingTopFetchLimit

                        let data = await self.postService.fetchTopPostsFor(spotID: spotID, limit: limit, endDocument: self.lastTopDocument, cachedPosts: self.cachedTopPostObjects, presentedPostIDs: postIDs)

                        guard self.activeSortMethod != .New else {
                            return
                        }

                        if data.0.isEmpty {
                            self.disableTopPagination = true
                        }

                        let posts = self.getAllPosts(posts: self.topPosts.elements + data.0).removingDuplicates()
                        promise(.success((spot ?? self.cachedSpot, posts)))
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        self.topPosts = IdentifiedArrayOf(uniqueElements: posts)
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func getAllPosts(posts: [MapPost]) -> [MapPost] {
        var allPosts = [MapPost]()
        for parentPost in posts {
            allPosts.append(parentPost)
            for childPost in parentPost.postChildren ?? [] {
                var post = childPost
                let remainingParentComments = (parentPost.commentCount ?? 0) - (parentPost.postChildren?.count ?? 0)
                let lastPost = childPost == parentPost.postChildren?.last
                // parentCommentCount is only > 0 when "view x more" button will show
                post.parentCommentCount = lastPost ? remainingParentComments : 0
                allPosts.append(post)
            }
        }
        return allPosts
    }

    func postsAreEmpty() -> Bool {
        return recentPosts.isEmpty && topPosts.isEmpty
    }

    func addNewPost(post: MapPost) {
        if let id = post.parentPostID {
            if let i = recentPosts.firstIndex(where: { $0.id == id }) {
                recentPosts[i].postChildren?.insert(post, at: 0)
            }
            if let i = topPosts.firstIndex(where: { $0.id == id }) {
                topPosts[i].postChildren?.insert(post, at: 0)
            }
        } else {
            activeSortMethod = .New
            recentPosts.insert(post, at: 0)
        }
    }
}

extension SpotViewModel {
    func likePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
            recentPosts[i].likers.append(UserDataModel.shared.uid)
        }
        if let i = topPosts.firstIndex(where: { $0.id == postID }) {
            topPosts[i].likers.append(UserDataModel.shared.uid)
        }
        postService.likePostDB(post: post)
    }

    func unlikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
            recentPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
        }
        if let i = topPosts.firstIndex(where: { $0.id == postID }) {
            topPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
        }
        postService.unlikePostDB(post: post)
    }

    func dislikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
            recentPosts[i].dislikers.append(UserDataModel.shared.uid)
            print("dislikers", recentPosts[i].dislikers)
        }
        if let i = topPosts.firstIndex(where: { $0.id == postID }) {
            topPosts[i].dislikers.append(UserDataModel.shared.uid)
        }
        postService.dislikePostDB(post: post)
    }

    func undislikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
            recentPosts[i].dislikers.removeAll(where: { $0 == UserDataModel.shared.uid })
            print("dislikers", recentPosts[i].dislikers)
        }
        if let i = topPosts.firstIndex(where: { $0.id == postID }) {
            topPosts[i].dislikers.removeAll(where: { $0 == UserDataModel.shared.uid })
        }
        postService.undislikePostDB(post: post)
    }

    func userIsInRange() -> Bool {
        // about .1 mile
        return (locationService.currentLocation?.distance(from: cachedSpot.location) ?? 1000) < 160
    }
}
