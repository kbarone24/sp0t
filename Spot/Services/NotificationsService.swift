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
    func setSeen(notiID: String)
    func removeDeprecatedNotification(notiID: String)
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

                guard let spotService = try? ServiceContainer.shared.service(for: \.spotService),
                      let userService = try? ServiceContainer.shared.service(for: \.userService) else {
                    return
                }

                var pendingFriendRequests = [UserNotification]()
                var activityNotis = [UserNotification]()
                
                guard let docs = try? await query.getDocuments() else { return }
                for doc in docs.documents {
                    guard var noti = try? doc.data(as: UserNotification.self) else { continue }

                    let user = try? await userService.getUserInfo(userID: noti.senderID)
                    guard var user, user.id != "", user.username != "" else {
                        self.setSeen(notiID: noti.id ?? "")
                        continue
                    }

                    user.contactInfo = getContactFor(number: user.phone ?? "")

                    noti.userInfo = user
                    // pending friend request
                    if noti.status == NotificationStatus.pending.rawValue {
                        pendingFriendRequests.append(noti)
                    }
                    // user activity notification
                    else if noti.type == NotificationType.contactJoin.rawValue || noti.type == NotificationType.friendRequest.rawValue {
                        activityNotis.append(noti)
                    }
                    // content activity notification related to spot
                    else if let spotID = noti.spotID, spotID != "" {
                        let spot = try? await spotService.getSpot(spotID: spotID)
                        noti.spotInfo = spot
                        activityNotis.append(noti)
                    }
                }

                let finalActivityNotis = removeBrokensAndDuplicates(activityNotis: activityNotis, friendRequests: pendingFriendRequests)

                let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.documents.last
                
                continuation.resume(returning: (pendingFriendRequests, finalActivityNotis, endDocument))
            }
        }
    }

    private func getContactFor(number: String) -> ContactInfo? {
        let number = String(number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().suffix(10))
        return ContactsFetcher.shared.contactInfos.first(where: { $0.formattedNumber == number })
    }

    private func removeBrokensAndDuplicates(activityNotis: [UserNotification], friendRequests: [UserNotification]) -> [UserNotification] {
        var finalActivityNotis = [UserNotification]()
        for noti in activityNotis {
            // remove broken contact join noti, set seen so new indicator goes away
            if noti.type == NotificationType.contactJoin.rawValue {
                if noti.userInfo?.contactInfo == nil || friendRequests.contains(where: { $0.userInfo?.id == noti.senderID }) || UserDataModel.shared.userInfo.friendIDs.contains(noti.senderID) {
                    setSeen(notiID: noti.id ?? "")
                    continue
                }
            }
            finalActivityNotis.append(noti)
        }
        return finalActivityNotis
    }

    func setSeen(notiID: String) {
        guard notiID != "" else { return }
        Firestore.firestore().collection(FirebaseCollectionNames.users.rawValue).document(UserDataModel.shared.uid).collection(FirebaseCollectionNames.notifications.rawValue).document(notiID).updateData([
            FirebaseCollectionFields.seen.rawValue: true
        ])
    }

    func removeDeprecatedNotification(notiID: String) {
        Firestore.firestore().collection(FirebaseCollectionNames.users.rawValue).document(UserDataModel.shared.uid).collection(FirebaseCollectionNames.notifications.rawValue).document(notiID).delete()
    }
}

