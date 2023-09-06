//
//  PopViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseStorage
import IdentifiedCollections
import Combine
import CoreLocation

final class PopViewModel {
    typealias Section = PopController.Section
    typealias Item = PopController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    enum SortMethod: String {
        case New
        case Hot
    }

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let postListener: PassthroughSubject<(forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)), Never>
        let sort: PassthroughSubject<(sort: SortMethod, useEndDoc: Bool), Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let postService: MapPostServiceProtocol
    let popService: PopServiceProtocol
    let userService: UserServiceProtocol
    let locationService: LocationServiceProtocol

    private let initialRecentFetchLimit = 15
    private let paginatingRecentFetchLimit = 10
    private let initialTopFetchLimit = 50
    private let paginatingTopFetchLimit = 25

    var passedPostID: String?
    var passedCommentID: String?
    var activeSortMethod: SortMethod = .New
    var cachedPop: Spot = Spot(id: "", spotName: "") {
        didSet {
            if UserDataModel.shared.homeSpot == nil {
                UserDataModel.shared.homeSpot = cachedPop
            }
        }
    }

    var presentedPosts: IdentifiedArrayOf<Post> = [] {
        didSet {
            // remove comments from presented posts -> recent posts / top posts store comments as postChildren
            var posts = presentedPosts
            posts.removeAll(where: { $0.parentPostID ?? "" != "" })
            switch activeSortMethod {
            case .New:
                recentPosts = posts
            case .Hot:
                topPosts = posts
            }
        }
    }

    var disableRecentPagination = false
    var disableTopPagination = false

    var recentPosts: IdentifiedArrayOf<Post> = []
    var lastRecentDocument: DocumentSnapshot?
    var topPosts: IdentifiedArrayOf<Post> = []
    var cachedTopPostObjects = [Post]()
    var lastTopDocument: DocumentSnapshot?

    var addedPostIDs = [String]()
    var removedPostIDs = [String]()
    var modifiedPostIDs = [String]()

    init(serviceContainer: ServiceContainer, pop: Spot, passedPostID: String?, passedCommentID: String?) {
        guard let postService = try? serviceContainer.service(for: \.mapPostService),
              let popService = try? serviceContainer.service(for: \.popService),
              let userService = try? serviceContainer.service(for: \.userService),
              let locationService = try? serviceContainer.service(for: \.locationService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            popService = PopService(fireStore: Firestore.firestore())
            userService = UserService(fireStore: Firestore.firestore())
            locationService = LocationService(locationManager: CLLocationManager())
            return
        }
        self.userService = userService
        self.popService = popService
        self.postService = postService
        self.locationService = locationService

        self.cachedPop = pop
        self.passedPostID = passedPostID
        self.passedCommentID = passedCommentID
    }

    func bind(to input: Input) -> Output {
        let requestItems = Publishers.CombineLatest3(
            input.refresh,
            input.postListener.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global()),
            input.sort.debounce(for: .milliseconds(500), scheduler: DispatchQueue.global())
        )
            .receive(on: DispatchQueue.global())
            .share()

        let request = requestItems
            .receive(on: DispatchQueue.global())
            .map { [unowned self] requestItemsPublisher in
                self.fetchPosts(
                    refresh: requestItemsPublisher.0,
                    postListener: requestItemsPublisher.1,
                    sort: requestItemsPublisher.2)
            }
            .switchToLatest()
            .map { $0 }


        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { pop, posts in
                var snapshot = Snapshot()
                snapshot.appendSections([.main(pop: pop, sortMethod: self.activeSortMethod)])
                _ = posts.map {
                    snapshot.appendItems([.item(post: $0)], toSection: .main(pop: pop, sortMethod: self.activeSortMethod))
                }
                return snapshot
            }
            .eraseToAnyPublisher()

        return Output(snapshot: snapshot)
    }

    private func fetchPosts(
        refresh: Bool,
        postListener: (forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)),
        sort: (sort: SortMethod, useEndDoc: Bool)
    ) -> AnyPublisher<(Spot, [Post]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self, let popID = cachedPop.id, popID != "" else {
                    promise(.success((Spot(id: "", spotName: ""), [])))
                    return
                }

                //MARK: local update -> return cache
                // ALWAYS use recent / top posts, comment updates stored as postChildren
                guard refresh else {
                    switch self.activeSortMethod {
                    case .New:
                        let posts = self.getAllPosts(posts: self.recentPosts.elements).removingDuplicates()

                        DispatchQueue.main.async {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }
                        // set presented posts first becuase we need them for upload methods
                        promise(.success((self.cachedPop, posts)))

                    case .Hot:
                        let posts = self.getAllPosts(posts: self.topPosts.elements).removingDuplicates()

                        DispatchQueue.main.async {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        }

                        promise(.success((self.cachedPop, posts)))
                    }
                    return
                }

                guard refresh else {
                    return
                }

                // fetching something from database
                Task {
                    let popTask = Task.detached {
                        return try? await self.popService.getPop(popID: popID)
                    }

                    guard !postListener.forced else {
                        if let post = postListener.commentInfo.post, let postID = post.id {
                            //MARK: Specific post sent through for comment updates
                            //MARK: End document sent through (user tapped to load more comments)
                            let commentsTask = Task.detached {
                                return await self.postService.fetchCommentsFor(post: post, limit: 3, endDocument: postListener.commentInfo.endDocument)
                            }

                            let spot = await popTask.value
                            let moreComments = await commentsTask.value

                            var posts = self.activeSortMethod == .New ? self.recentPosts.elements : self.topPosts.elements

                            if let i = posts.firstIndex(where: { $0.id == postID }) {
                                posts[i].postChildren?.append(contentsOf: moreComments.comments)
                                posts[i].postChildren?.removeDuplicates()
                                posts[i].lastCommentDocument = moreComments.endDocument
                            }

                            posts = self.getAllPosts(posts: posts).removingDuplicates()
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                            if let spot { self.cachedPop = spot }

                            promise(.success((spot ?? self.cachedPop, posts)))
                        }
                        return
                    }

                    switch sort.sort {
                    case .New:
                        //MARK: fetch new posts using last item if != nil (initial fetch or pagination)
                        // useEndDoc == false on forced refresh (switching sort or pull to refresh) (get fresh posts)
                        let endDocument = sort.useEndDoc ? self.lastRecentDocument : nil
                        let limit = endDocument == nil ? self.initialRecentFetchLimit : self.paginatingRecentFetchLimit

                        let postsTask = Task.detached {
                            // pass through popID if pop to query posts by popID
                            return await self.postService.fetchRecentPostsFor(spotID: nil, popID: popID, limit: limit, endDocument: endDocument)
                        }

                        let spot = await popTask.value
                        let postData = await postsTask.value

                        guard self.activeSortMethod != .Hot else {
                            return
                        }

                        if postData.0.isEmpty {
                            self.disableRecentPagination = true
                        }

                        var rawPosts = sort.useEndDoc ? self.recentPosts.elements + postData.0 : postData.0

                        // MARK: insert / fetch passed post to show in row 0
                        if let postID = self.passedPostID, postID != "" {
                            let posts = try? await self.postService.configurePostsForPassthrough(rawPosts: rawPosts, passedPostID: postID, passedCommentID: self.passedCommentID)
                            rawPosts = posts ?? []
                        }

                        let posts = self.getAllPosts(posts: rawPosts).removingDuplicates()

                        DispatchQueue.main.async {
                            if sort.useEndDoc {
                                self.lastRecentDocument = postData.1
                            } else {
                                self.addedPostIDs.removeAll()
                            }

                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                            self.passedPostID = nil
                            if let spot { self.cachedPop = spot }

                            promise(.success((spot ?? self.cachedPop, posts)))
                        }

                    case .Hot:
                        //MARK: Fetch top posts for algo sort
                        let postIDs = self.topPosts.elements.map({ $0.id ?? ""})
                        let endDocument = sort.useEndDoc ? self.lastTopDocument : nil
                        let cachedPosts = sort.useEndDoc ? self.cachedTopPostObjects : []
                        let limit = endDocument == nil ? self.initialTopFetchLimit : self.paginatingTopFetchLimit

                        let postsTask = Task.detached {
                            // pass through popID if pop to query posts by popID
                            return await self.postService.fetchTopPostsFor(
                                spotID: nil,
                                popID: popID,
                                limit: limit,
                                endDocument: endDocument,
                                cachedPosts: cachedPosts,
                                presentedPostIDs: postIDs)
                        }

                        let spot = await popTask.value
                        let postData = await postsTask.value

                        guard self.activeSortMethod != .New else {
                            return
                        }

                        if postData.0.isEmpty {
                            self.disableTopPagination = true
                        }

                        let rawPosts = sort.useEndDoc ? self.topPosts.elements + postData.0 : postData.0
                        let posts = self.getAllPosts(posts: rawPosts).removingDuplicates()

                        DispatchQueue.main.async {
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                            if sort.useEndDoc {
                                self.lastTopDocument = postData.1
                            }
                            self.cachedTopPostObjects = postData.2
                            if let spot { self.cachedPop = spot }

                            promise(.success((spot ?? self.cachedPop, posts)))
                        }
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func getAllPosts(posts: [Post]) -> [Post] {
        var allPosts = [Post]()
        for parentPost in posts {
            var parentPost = parentPost
            // set parent comment count so view more comments will show if comments havent been fetched yet
            parentPost.parentCommentCount = (parentPost.postChildren?.isEmpty ?? true) ? parentPost.commentCount ?? 0 : 0
            parentPost.isLastPost = parentPost.postChildren?.isEmpty ?? true
            allPosts.append(parentPost)

            for childPost in parentPost.postChildren ?? [] {
                var post = childPost
                let remainingParentComments = (parentPost.commentCount ?? 0) - (parentPost.postChildren?.count ?? 0)
                let lastPost = childPost == parentPost.postChildren?.last
                // parentCommentCount is only > 0 when "view x more" button will show
                post.parentCommentCount = lastPost ? remainingParentComments : 0
                post.isLastPost = lastPost
                allPosts.append(post)
            }
        }
        return allPosts
    }

    func postsAreEmpty() -> Bool {
        return recentPosts.isEmpty && topPosts.isEmpty
    }
}

