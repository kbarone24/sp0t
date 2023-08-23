//
//  ProfileViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Combine
import IdentifiedCollections
import FirebaseStorage

class ProfileViewModel {
    typealias Section = ProfileViewController.Section
    typealias Item = ProfileViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
        let commentPaginationForced: PassthroughSubject<((MapPost?, DocumentSnapshot?)), Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let postService: MapPostServiceProtocol
    let userService: UserServiceProtocol
    let friendService: FriendsServiceProtocol

    var cachedProfile = UserProfile()
    var presentedPosts: IdentifiedArrayOf<MapPost> = []

    var disablePagination = false
    var endDocument: DocumentSnapshot?

    let fetchLimit = 15

    init(serviceContainer: ServiceContainer, profile: UserProfile) {
        guard let postService = try? serviceContainer.service(for: \.mapPostService),
              let userService = try? serviceContainer.service(for: \.userService),
              let friendService = try? serviceContainer.service(for: \.friendsService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            userService = UserService(fireStore: Firestore.firestore())
            friendService = FriendsService(fireStore: Firestore.firestore())
            return
        }
        self.userService = userService
        self.postService = postService
        self.friendService = friendService

        self.cachedProfile = profile
    }

    func bind(to input: Input) -> Output {
        let requestItems = Publishers.CombineLatest(
            input.refresh,
            input.commentPaginationForced
            )

        let request = requestItems
            .receive(on: DispatchQueue.global())
            .map { [unowned self] requestItemsPublisher in
                self.fetchProfileData(
                    refresh: requestItemsPublisher.0,
                    commentPaginationForced: requestItemsPublisher.1
                )
            }
            .switchToLatest()
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { profile, posts in
                var snapshot = Snapshot()
                snapshot.appendSections([.overview, .timeline])
                snapshot.appendItems([.profileHeader(profile: profile)], toSection: .overview)
                _ = posts.map {
                    snapshot.appendItems([.post(post: $0)], toSection: .timeline)
                }
                return snapshot
            }
            .eraseToAnyPublisher()

        return Output(snapshot: snapshot)
    }

    private func fetchProfileData(
        refresh: Bool,
        commentPaginationForced: ((MapPost?, DocumentSnapshot?))
    ) -> AnyPublisher<(UserProfile, [MapPost]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success((UserProfile(), [])))
                    return
                }

                guard refresh else {
                    // re run get all posts to pull in comment changes
                    let posts = getAllPosts(posts: self.presentedPosts.elements).removingDuplicates()
                    promise(.success((cachedProfile, posts)))
                    return
                }

                Task {
                    let userInfo = try? await self.userService.getProfileInfo(cachedProfile: self.cachedProfile)
                    let user = userInfo ?? self.cachedProfile

                    if let post = commentPaginationForced.0, let postID = post.id {
                        let endDoc = commentPaginationForced.1
                        let moreComments = await self.postService.fetchCommentsFor(post: post, limit: 3, endDocument: endDoc)
                        var posts = self.presentedPosts.elements
                        if let i = posts.firstIndex(where: { $0.id == postID }) {
                            posts[i].postChildren?.append(contentsOf: moreComments.comments)
                            posts[i].lastCommentDocument = moreComments.endDocument
                        }

                        posts = self.getAllPosts(posts: posts).removingDuplicates()
                        promise(.success((user, posts)))

                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: posts)

                    } else {
                        let postData = await self.postService.fetchRecentPostsFor(userID: userInfo?.id ?? "", limit: self.fetchLimit, endDocument: self.endDocument)
                        let posts = (self.presentedPosts.elements + postData.0).removingDuplicates()
                        let allPosts = self.getAllPosts(posts: posts).removingDuplicates()
                        let endDocument = postData.1

                        if endDocument == nil {
                            self.disablePagination = true
                        }

                        promise(.success((user, allPosts)))

                        self.cachedProfile = user
                        self.presentedPosts = IdentifiedArrayOf(uniqueElements: allPosts)
                        self.endDocument = endDocument
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func getAllPosts(posts: [MapPost]) -> [MapPost] {
        var allPosts = [MapPost]()
        for parentPost in posts {
            var parentPost = parentPost
            // set parent comment count so view more comments will show if comments havent been fetched yet
            parentPost.parentCommentCount = (parentPost.postChildren?.isEmpty ?? true) ? parentPost.commentCount ?? 0 : 0
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
}

extension ProfileViewModel {
    func likePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = presentedPosts.firstIndex(where: { $0.id == parentID }), let j = presentedPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                presentedPosts[i].postChildren?[j].likers.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = presentedPosts.firstIndex(where: { $0.id == postID }) {
                presentedPosts[i].likers.append(UserDataModel.shared.uid)
            }
        }
        postService.likePostDB(post: post)
    }
    
    func unlikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = presentedPosts.firstIndex(where: { $0.id == parentID }), let j = presentedPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                presentedPosts[i].postChildren?[j].likers.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = presentedPosts.firstIndex(where: { $0.id == postID }) {
                presentedPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.unlikePostDB(post: post)
    }
    
    func dislikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = presentedPosts.firstIndex(where: { $0.id == parentID }), let j = presentedPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                presentedPosts[i].postChildren?[j].dislikers?.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = presentedPosts.firstIndex(where: { $0.id == postID }) {
                presentedPosts[i].dislikers?.append(UserDataModel.shared.uid)
                postService.dislikePostDB(post: post)
            }
        }
    }

    func undislikePost(post: MapPost) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = presentedPosts.firstIndex(where: { $0.id == parentID }), let j = presentedPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                presentedPosts[i].postChildren?[j].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = presentedPosts.firstIndex(where: { $0.id == postID }) {
                presentedPosts[i].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.undislikePostDB(post: post)
    }

    func hidePost(post: MapPost) {
        deletePostLocally(postID: post.id ?? "", parentPostID: post.parentPostID)
        postService.hidePost(post: post)
    }

    func reportPost(post: MapPost, feedbackText: String) {
        deletePostLocally(postID: post.id ?? "", parentPostID: post.parentPostID)
        postService.reportPost(post: post, feedbackText: feedbackText)
    }

    func deletePost(post: MapPost) {
        // deletePostLocally(post: post)
        // delete post will be called from notification
        postService.deletePost(post: post)
    }

    func deletePostLocally(postID: String, parentPostID: String?) {
        UserDataModel.shared.deletedPostIDs.append(postID)
        if let parentID = parentPostID, parentID != "" {
            if let i = presentedPosts.firstIndex(where: { $0.id == parentID }) {
                presentedPosts[i].commentCount = (presentedPosts[i].commentCount ?? 1) - 1
                presentedPosts[i].postChildren?.removeAll(where: { $0.id == postID })
            }
        } else {
            presentedPosts.removeAll(where: { $0.id == postID })
        }
    }

    func addFriend() {
        guard let receiverID = cachedProfile.id else { return }
        UserDataModel.shared.userInfo.pendingFriendRequests.append(receiverID)
        cachedProfile.updateToggle.toggle()
        
        friendService.addFriend(receiverID: receiverID) { _ in }
    }

    func removeFriend() {
        guard let receiverID = cachedProfile.id else { return }
        cachedProfile.friendIDs.removeAll(where: { $0 == UserDataModel.shared.uid })
        UserDataModel.shared.userInfo.friendsList.removeAll(where: { $0.id == receiverID })
        cachedProfile.updateToggle.toggle()

        friendService.removeFriend(friendID: receiverID)
    }

    func removeFriendRequest() {
        guard let receiverID = cachedProfile.id else { return }
        UserDataModel.shared.userInfo.pendingFriendRequests.removeAll(where: { $0 == receiverID })
        cachedProfile.updateToggle.toggle()

        friendService.revokeFriendRequest(friendID: receiverID)
    }

    func blockUser() {
        guard let receiverID = cachedProfile.id else { return }
        // remove friend if user is friends with person they're blocking -> toggle called on remove
        removeFriend()
        UserDataModel.shared.userInfo.blockedUsers?.append(receiverID)

        friendService.blockUser(receiverID: receiverID)
    }

    func unblockUser() {
        guard let receiverID = cachedProfile.id else { return }
        UserDataModel.shared.userInfo.blockedUsers?.removeAll(where: { $0 == receiverID })
        cachedProfile.updateToggle.toggle()

        friendService.unblockUser(receiverID: receiverID)
    }

    func reportUser(text: String) {
        guard let receiverID = cachedProfile.id else { return }
        friendService.reportUser(text: text, reportedUserID: receiverID)
    }

    func acceptFriendRequest() {
        UserDataModel.shared.userInfo.friendIDs.append(cachedProfile.id ?? "")
        UserDataModel.shared.userInfo.friendsList.append(cachedProfile)
        cachedProfile.friendIDs.append(UserDataModel.shared.uid)
        cachedProfile.friendsList.append(UserDataModel.shared.userInfo)
        cachedProfile.pendingFriendRequests.removeAll(where: { $0 == UserDataModel.shared.uid })

        friendService.acceptFriendRequest(friend: cachedProfile, notificationID: nil)
    }

    func setNewAvatarSeen() {
        cachedProfile.newAvatarNoti = false
        userService.setNewAvatarSeen()
    }

    func updateUserAvatar(avatar: AvatarProfile) {
        print("update user avatar")
        cachedProfile.avatarFamily = avatar.family.rawValue
        cachedProfile.avatarItem = avatar.item?.rawValue
        cachedProfile.avatarURL = avatar.getURL()

        for i in 0..<presentedPosts.elements.count {
            if presentedPosts[i].posterID == UserDataModel.shared.uid {
                print("update post")
                presentedPosts[i].userInfo = cachedProfile
            }
        }
    }
}
