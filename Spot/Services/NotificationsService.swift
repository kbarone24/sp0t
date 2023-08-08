//
//  NotificationsService.swift
//  Spot
//
//  Created by Kenny Barone on 8/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

protocol NotificationsServiceProtocol {
    func fetchNotifications(limit: Int, endDocument: DocumentSnapshot?) async -> ([UserNotification], [UserNotification], DocumentSnapshot?)
}

final class NotificationsService: NotificationsServiceProtocol {

    private let fireStore: Firestore

    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }

    func fetchNotifications(limit: Int, endDocument: DocumentSnapshot?) async -> ([UserNotification], [UserNotification], DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                var query = self.fireStore
                    .collection(FirebaseCollectionNames.users.rawValue)
                    .document(UserDataModel.shared.uid)
                    .collection(FirebaseCollectionNames.notifications.rawValue)
                    .limit(to: limit)
                    .order(by: FirebaseCollectionFields.seen.rawValue)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                guard let postService = try? ServiceContainer.shared.service(for: \.mapPostService),
                      let userService = try? ServiceContainer.shared.service(for: \.userService) else {
                    return
                }

                var pendingFriendRequests = [UserNotification]()
                var activityNotis = [UserNotification]()
                
                guard let docs = try? await query.getDocuments() else { return }
                for doc in docs.documents {
                    guard var noti = try? doc.data(as: UserNotification.self) else { continue }
                    let user = try? await userService.getUserInfo(userID: noti.senderID)
                    guard var user, user.id != "" else { continue }

                    if noti.type == NotificationType.contactJoin.rawValue {
                        user.contactInfo = getContactFor(number: user.phone ?? "")
                        noti.userInfo = user
                        activityNotis.append(noti)
                    }

                    else if noti.status == NotificationStatus.pending.rawValue {
                        user.contactInfo = getContactFor(number: user.phone ?? "")
                        noti.userInfo = user
                        pendingFriendRequests.append(noti)
                    }

                    else {
                        guard let postID = noti.postID, postID != "" else { continue }
                        let post = try? await postService.getPost(postID: postID)
                        noti.postInfo = post
                        noti.userInfo = user
                        activityNotis.append(noti)
                    }
                }

                let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.documents.last

                continuation.resume(returning: (pendingFriendRequests, activityNotis, endDocument))
            }
        }
    }

    private func getContactFor(number: String) -> ContactInfo? {
        let number = String(number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().suffix(10))
        return ContactsFetcher.shared.contactInfos.first(where: { $0.formattedNumber == number })
    }
}

