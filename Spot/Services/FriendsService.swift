//
//  FriendsService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

protocol FriendsServiceProtocol {
    func incrementTopFriends(friendID: String, increment: Int64, completion: ((Error?) -> Void)?)
    func sendFriendRequestNotis(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func addFriendToFriendsList(userID: String, friendID: String, completion: ((Error?) -> Void)?)
    func revokeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func removeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func acceptFriendRequest(friend: UserProfile, notificationID: String, completion: ((Error?) -> Void)?)
    func addFriend(receiverID: String, completion: ((Error?) -> Void)?)
}

final class FriendsService: FriendsServiceProtocol {
    
    enum FriendError: Error {
        case userNotLoggedIn
    }
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func incrementTopFriends(friendID: String, increment: Int64, completion: ((Error?) -> Void)?) {
        guard UserDataModel.shared.userInfo.friendIDs.contains(friendID) else {
            completion?(nil)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(UserDataModel.shared.uid)
                .updateData(
                    [
                        "\(FireBaseCollectionFields.topFriends.rawValue).\(friendID)": FieldValue.increment(increment)
                    ]
                )
            
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(friendID)
                .updateData(
                    [
                        "\(FireBaseCollectionFields.topFriends.rawValue).\(UserDataModel.shared.uid)": FieldValue.increment(increment)
                    ]
                )
            
            completion?(nil)
        }
    }
    
    func sendFriendRequestNotis(friendID: String, notificationID: String, completion: ((Error?) -> Void)?) {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(FriendError.userNotLoggedIn)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            let timestamp = Timestamp(date: Date())
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(uid)
                .collection(FirebaseCollectionNames.notifications.rawValue)
                .document(notificationID)
                .updateData(
                    [
                        FireBaseCollectionFields.status.rawValue: "accepted",
                        FireBaseCollectionFields.timestamp.rawValue: timestamp
                    ]
                )
            
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(friendID)
                .collection(FirebaseCollectionNames.notifications.rawValue)
                .document(UUID().uuidString)
                .setData(
                    [
                        FireBaseCollectionFields.status.rawValue: "accepted",
                        FireBaseCollectionFields.timestamp.rawValue: timestamp,
                        FireBaseCollectionFields.senderID.rawValue: uid,
                        FireBaseCollectionFields.senderUsername.rawValue: UserDataModel.shared.userInfo.username,
                        FireBaseCollectionFields.type.rawValue: "friendRequest",
                        FireBaseCollectionFields.seen.rawValue: false
                    ]
                )
        }
    }
    
    func addFriendToFriendsList(userID: String, friendID: String, completion: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(userID)
                .updateData(
                    [
                        FireBaseCollectionFields.friendsList.rawValue: FieldValue.arrayUnion([friendID]),
                        FireBaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([friendID]),
                        "topFriends.\(friendID)": 0
                    ]
                )
            
            completion?(nil)
        }
    }
    
    func revokeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(FriendError.userNotLoggedIn)
            return
        }
        
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(uid)
            .updateData(
                [
                    FireBaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([friendID])
                ]
            )
        
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(friendID)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .document(notificationID)
            .delete()
        
        completion?(nil)
    }
    
    func removeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(FriendError.userNotLoggedIn)
            return
        }
        
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(friendID)
            .updateData(
                [
                    FireBaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([uid])
                ]
            )
        
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(uid)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .document(notificationID)
            .delete()
        
        completion?(nil)
    }
    
    func acceptFriendRequest(friend: UserProfile, notificationID: String, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid,
              let friendId = friend.id
        else {
            completion?(FriendError.userNotLoggedIn)
            return
        }
        
        addFriendToFriendsList(userID: uid, friendID: friendId, completion: nil)
        addFriendToFriendsList(userID: friendId, friendID: uid, completion: nil)
        sendFriendRequestNotis(friendID: friendId, notificationID: notificationID, completion: nil)

        /// adjust individual posts "friendsList" docs
        DispatchQueue.global().async {
            do {
                let mapPostService = try ServiceContainer.shared.service(for: \.mapPostService)
                mapPostService.adjustPostFriendsList(userID: uid, friendID: friendId) { _ in
                    /// send notification to home to reload posts
                    NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListAdd")))
                }
                
                mapPostService.adjustPostFriendsList(userID: friendId, friendID: uid, completion: nil)
            } catch {
                completion?(error)
            }
        }
        
    }
    
    func addFriend(receiverID: String, completion: ((Error?) -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(FriendError.userNotLoggedIn)
            return
        }
        
        let ref = fireStore.collection("users")
            .document(receiverID)
            .collection("notifications")
            .document(UserDataModel.shared.uid) // using UID for friend rquest should make it so user cant send a double friend request
        
        let time = Date()
        
        let values = [
            "senderID": uid,
            "type": "friendRequest",
            "senderUsername": UserDataModel.shared.userInfo.username,
            "timestamp": time,
            "status": "pending",
            "seen": false
        ] as [String: Any]
        
        ref.setData(values)
        
        fireStore.collection("users")
            .document(uid)
            .updateData(
                [
                    "pendingFriendRequests": FieldValue.arrayUnion([receiverID])
                ]
            )
        
        completion?(nil)
    }
}
