//
//  NotificationsViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Combine
import Firebase
import FirebaseStorage
import IdentifiedCollections

class NotificationsViewModel {

    typealias Section = NotificationsViewController.Section
    typealias Item = NotificationsViewController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let notificationsService: NotificationsServiceProtocol
    let postService: MapPostServiceProtocol
    let userService: UserServiceProtocol
    let friendService: FriendsServiceProtocol

    private let fetchLimit = 12

    var cachedFriendRequestNotifications: IdentifiedArrayOf<UserNotification> = []
    var cachedActivityNotifications: IdentifiedArrayOf<UserNotification> = []

    private var endDocument: DocumentSnapshot?
    var disablePagination = false

    init(serviceContainer: ServiceContainer) {
        guard let notificationsService = try? serviceContainer.service(for: \.notificationsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let userService = try? serviceContainer.service(for: \.userService),
              let friendService = try? serviceContainer.service(for: \.friendsService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            self.notificationsService = NotificationsService(fireStore: Firestore.firestore())
            self.postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            self.userService = UserService(fireStore: Firestore.firestore())
            self.friendService = FriendsService(fireStore: Firestore.firestore())
            return
        }
        self.notificationsService = notificationsService
        self.postService = postService
        self.userService = userService
        self.friendService = friendService
    }

    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global(qos: .background))
            .flatMap { [unowned self] refresh in
                (self.fetchNotis(refresh: refresh))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { friendRequests, activity in

                var snapshot = Snapshot()
                let friendRequestTitle = "FRIEND REQUESTS"
                let activityTitle = "ACTIVITY"

                if !friendRequests.isEmpty {
                    snapshot.appendSections([.friendRequest(title: friendRequestTitle)])
                    snapshot.appendItems([.friendRequestItem(notifications: friendRequests)], toSection: .friendRequest(title: friendRequestTitle))
                }

                if !activity.isEmpty {
                    snapshot.appendSections([.activity(title: activityTitle)])
                    _ = activity.map {
                        snapshot.appendItems([.activityItem(notification: $0)], toSection: .activity(title: activityTitle))
                    }
                }

                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)

    }

    private func fetchNotis(
        refresh: Bool
    ) -> AnyPublisher<([UserNotification], [UserNotification]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success(([], [])))
                    return
                }
                guard refresh else {
                    promise(.success((self.cachedFriendRequestNotifications.elements, self.cachedActivityNotifications.elements)))
                    return
                }

                Task {
                    let data = await self.notificationsService.fetchNotifications(limit: self.fetchLimit, endDocument: self.endDocument)

                    if data.2 == nil {
                        self.disablePagination = true
                    }

                    let pendingFriendRequests = (self.cachedFriendRequestNotifications.elements + data.0.removingDuplicates()).removingDuplicates()
                    let activityNotifications = (self.cachedActivityNotifications.elements + data.1.removingDuplicates()).removingDuplicates()

                    promise(.success((pendingFriendRequests, activityNotifications)))

                    self.cachedFriendRequestNotifications = IdentifiedArrayOf(uniqueElements: pendingFriendRequests)
                    self.cachedActivityNotifications = IdentifiedArrayOf(uniqueElements: activityNotifications)
                    self.endDocument = data.2
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func setSeenFor(notiID: String) {
        notificationsService.setSeen(notiID: notiID)
    }

    func addFriend(receiverID: String) {
        friendService.addFriend(receiverID: receiverID, completion: nil)
    }

    func removeContactNotification(notiID: String) {
        friendService.removeContactNotification(notiID: notiID)
    }

    func removeSuggestion(userID: String) {
        friendService.removeSuggestion(userID: userID)
    }

    func removeFriend(friendID: String) {

    }
}
