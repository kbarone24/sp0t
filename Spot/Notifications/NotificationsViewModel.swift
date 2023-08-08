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

    private let fetchLimit = 12

    var cachedFriendRequestNotifications: IdentifiedArrayOf<UserNotification> = []
    var cachedActivityNotifications: IdentifiedArrayOf<UserNotification> = []

    private var endDocument: DocumentSnapshot?
    var disablePagination = false

    init(serviceContainer: ServiceContainer) {
        guard let notificationsService = try? serviceContainer.service(for: \.notificationsService),
              let postService = try? serviceContainer.service(for: \.mapPostService),
              let userService = try? serviceContainer.service(for: \.userService)
        else {
            let imageVideoService = ImageVideoService(fireStore: Firestore.firestore(), storage: Storage.storage())
            self.notificationsService = NotificationsService(fireStore: Firestore.firestore())
            self.postService = MapPostService(fireStore: Firestore.firestore(), imageVideoService: imageVideoService)
            userService = UserService(fireStore: Firestore.firestore())
            return
        }
        self.notificationsService = notificationsService
        self.postService = postService
        self.userService = userService
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

                snapshot.appendSections([.friendRequest(title: friendRequestTitle), .activity(title: activityTitle)])

                snapshot.appendItems([.friendRequestItem(notifications: friendRequests)], toSection: .friendRequest(title: friendRequestTitle))

                _ = activity.map {
                    snapshot.appendItems([.activityItem(notification: $0)], toSection: .activity(title: activityTitle))
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
                    promise(.success((self.cachedActivityNotifications.elements, self.cachedFriendRequestNotifications.elements)))
                    return
                }

                Task {
                    let data = await self.notificationsService.fetchNotifications(limit: self.fetchLimit, endDocument: self.endDocument)

                    if data.2 == nil {
                        self.disablePagination = true
                    }

                    let pendingFriendRequests = (self.cachedFriendRequestNotifications.elements + data.0).removingDuplicates()
                    let activityNotifications = (self.cachedActivityNotifications.elements + data.1).removingDuplicates()

                    promise(.success((pendingFriendRequests, activityNotifications)))

                    self.cachedFriendRequestNotifications = IdentifiedArrayOf(uniqueElements: pendingFriendRequests)
                    self.cachedActivityNotifications = IdentifiedArrayOf(uniqueElements: activityNotifications)
                    self.endDocument = data.2
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
