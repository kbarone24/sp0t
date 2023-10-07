//
//  HomeScreenViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 7/6/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseStorage
import CoreLocation
import Combine
import IdentifiedCollections

class HomeScreenViewModel {
    typealias Section = HomeScreenController.Section
    typealias Item = HomeScreenController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let postListener: PassthroughSubject<(forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)), Never>
        let useEndDoc: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let postService: PostServiceProtocol
    let spotService: SpotServiceProtocol
    let locationService: LocationServiceProtocol
    let notificationService: NotificationsServiceProtocol
    let popService: PopServiceProtocol

    var parentPosts: IdentifiedArrayOf<Post> = []
    var presentedPosts: IdentifiedArrayOf<Post> = [] {
        didSet {
            var posts = presentedPosts
            posts.removeAll(where: { $0.parentPostID ?? "" != "" })
            parentPosts = posts
        }
    }
    var endDocument: DocumentSnapshot?
    var disablePagination = false

    init(serviceContainer: ServiceContainer) {
        guard let postService = try? serviceContainer.service(for: \.postService),
              let spotService = try? serviceContainer.service(for: \.spotService),
              let locationService = try? serviceContainer.service(for: \.locationService),
              let notificationService = try? serviceContainer.service(for: \.notificationsService),
              let popService = try? serviceContainer.service(for: \.popService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            self.postService = PostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            self.spotService = SpotService(fireStore: Firestore.firestore())
            self.locationService = LocationService(locationManager: CLLocationManager())
            self.notificationService = NotificationsService(fireStore: Firestore.firestore())
            self.popService = PopService(fireStore: Firestore.firestore())
            return
        }
        self.postService = postService
        self.spotService = spotService
        self.locationService = locationService
        self.notificationService = notificationService
        self.popService = popService
    }

    func bindForCachedPosts(to input: Input) -> Output {
        let request = input.refresh
            .map { _ in
                return self.getCachedPosts()
            }
            .switchToLatest()

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

    func bindForFetchedPosts(to input: Input) -> Output {
        let requestItems = Publishers.CombineLatest(
            input.postListener,
            input.useEndDoc
        )
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.global())

        let request = requestItems
            .receive(on: DispatchQueue.global())
            .map { [unowned self] requestItemsPublisher in
                (self.fetchPosts(
                    postListener: requestItemsPublisher.0,
                    useEndDoc: requestItemsPublisher.1
                ))
            }
            .switchToLatest()
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { posts in
                // if pops available, only show pop section
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

    private func getCachedPosts() -> AnyPublisher<([Post]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success([]))
                    return
                }

                let posts = self.getAllPosts(posts: self.parentPosts.elements).removingDuplicates()
                DispatchQueue.main.async {
                    self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                }

                promise(.success(posts))
            }
        }
        .eraseToAnyPublisher()
    }

    private func fetchPosts(
        postListener: (forced: Bool, commentInfo: (post: Post?, endDocument: DocumentSnapshot?)),
        useEndDoc: Bool
    ) -> AnyPublisher<([Post]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success(([])))
                    return
                }
                Task {
                    guard !postListener.forced else {
                        if let post = postListener.commentInfo.post, let postID = post.id {
                            //MARK: Specific post sent through for comment updates
                            //MARK: End document sent through (user tapped to load more comments)
                            let moreComments = await self.postService.fetchCommentsFor(post: post, limit: 3, endDocument: postListener.commentInfo.endDocument)

                            var posts = self.presentedPosts.elements

                            if let i = posts.firstIndex(where: { $0.id == postID }) {
                                posts[i].postChildren?.append(contentsOf: moreComments.comments)
                                posts[i].postChildren?.removeDuplicates()
                                posts[i].lastCommentDocument = moreComments.endDocument
                            }

                            posts = self.getAllPosts(posts: posts).removingDuplicates()
                            self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                            promise(.success((posts)))
                        }
                        return
                    }

                    let endDocument = useEndDoc ? self.endDocument : nil
                    let postData = await self.postService.fetchFriendPosts(limit: 20, endDocument: endDocument)
                    let rawPosts = useEndDoc ? self.presentedPosts.elements + postData.0 : postData.0
                    let posts = self.getAllPosts(posts: rawPosts).removingDuplicates()

                    self.disablePagination = postData.0.isEmpty

                    DispatchQueue.main.async {
                        if useEndDoc {
                            self.endDocument = postData.1
                        }

                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)
                        promise(.success((posts)))
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
}
//MARK: actions
extension HomeScreenViewModel {
    func setSeenLocally(spot: Spot) {
        return
    }

    func addUserToPopVisitors(pop: Spot) {
        popService.addUserToVisitorList(pop: pop)
    }

    func removeDeprecatedNotification(notiID: String) {
        notificationService.removeDeprecatedNotification(notiID: notiID)
    }

    func addNewPost(post: Post) {
        if let parentID = post.parentPostID, parentID != "" {
            // add new comment at end of comments
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }) {
                parentPosts[i].postChildren?.append(post)
            }
        } else {
            // insert new post at beginning of posts
            parentPosts.insert(post, at: 0)
        }
    }

    func hidePost(post: Post) {
        deletePostLocally(post: post)
        postService.hidePost(post: post)
    }

    func reportPost(post: Post, feedbackText: String) {
        deletePostLocally(post: post)
        postService.reportPost(post: post, feedbackText: feedbackText)
    }

    func deletePost(post: Post) {
        deletePostLocally(post: post)
        postService.deletePost(post: post)
    }

    private func deletePostLocally(post: Post) {
        UserDataModel.shared.deletedPostIDs.append(post.id ?? "")
        if let parentID = post.parentPostID, parentID != "" {
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }) {
                parentPosts[i].commentCount = (parentPosts[i].commentCount ?? 1) - 1
                parentPosts[i].postChildren?.removeAll(where: { $0.id == post.id ?? "" })
            }
        } else {
            parentPosts.removeAll(where: { $0.id == post.id ?? "" })
        }
    }

    func likePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }), let j = parentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                parentPosts[i].postChildren?[j].likers.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = parentPosts.firstIndex(where: { $0.id == postID }) {
                parentPosts[i].likers.append(UserDataModel.shared.uid)
            }
        }
        postService.likePostDB(post: post)
    }

    func unlikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }), let j = parentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                parentPosts[i].postChildren?[j].likers.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = parentPosts.firstIndex(where: { $0.id == postID }) {
                parentPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.unlikePostDB(post: post)
    }

    func dislikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }), let j = parentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                parentPosts[i].postChildren?[j].dislikers?.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = parentPosts.firstIndex(where: { $0.id == postID }) {
                parentPosts[i].dislikers?.append(UserDataModel.shared.uid)
            }
        }
        postService.dislikePostDB(post: post)
    }

    func undislikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = parentPosts.firstIndex(where: { $0.id == parentID }), let j = parentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                parentPosts[i].postChildren?[j].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = parentPosts.firstIndex(where: { $0.id == postID }) {
                parentPosts[i].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.undislikePostDB(post: post)
    }

    func getSelectedIndexFor(postID: String) -> Int? {
        return presentedPosts.firstIndex(where: { $0.id == postID })
    }
}
