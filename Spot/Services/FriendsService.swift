//
//  FriendsService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseAuth
import FirebaseFirestore
import Firebase

protocol FriendsServiceProtocol {
    func incrementTopFriends(friendID: String, increment: Int64, completion: ((Error?) -> Void)?)
    func sendFriendRequestNotis(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func addFriendToFriendsList(userID: String, friendID: String, completion: ((Error?) -> Void)?)
    func revokeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func removeFriendRequest(friendID: String, notificationID: String, completion: ((Error?) -> Void)?)
    func acceptFriendRequest(friend: UserProfile, notificationID: String, completion: ((Error?) -> Void)?)
    func addFriend(receiverID: String, completion: ((Error?) -> Void)?)
    func removeFriend(friendID: String)
    func removeFriendFromFriendsList(userID: String, friendID: String)
    func removeSuggestion(userID: String)
    func removeContactNotification(notiID: String)
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
                        "\(FirebaseCollectionFields.topFriends.rawValue).\(friendID)": FieldValue.increment(increment)
                    ]
                )
            
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(friendID)
                .updateData(
                    [
                        "\(FirebaseCollectionFields.topFriends.rawValue).\(UserDataModel.shared.uid)": FieldValue.increment(increment)
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
                        FirebaseCollectionFields.status.rawValue: "accepted",
                        FirebaseCollectionFields.seen.rawValue: true,
                        FirebaseCollectionFields.timestamp.rawValue: timestamp
                    ]
                )
            
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).document(friendID)
                .collection(FirebaseCollectionNames.notifications.rawValue)
                .document(UUID().uuidString)
                .setData(
                    [
                        FirebaseCollectionFields.status.rawValue: "accepted",
                        FirebaseCollectionFields.timestamp.rawValue: timestamp,
                        FirebaseCollectionFields.senderID.rawValue: uid,
                        FirebaseCollectionFields.senderUsername.rawValue: UserDataModel.shared.userInfo.username,
                        FirebaseCollectionFields.type.rawValue: "friendRequest",
                        FirebaseCollectionFields.seen.rawValue: false
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
                        FirebaseCollectionFields.friendsList.rawValue: FieldValue.arrayUnion([friendID]),
                        FirebaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([friendID]),
                        "topFriends.\(friendID)": 0,
                        "spotScore": FieldValue.increment(Int64(1))
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
                    FirebaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([friendID])
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

        if friendID != "" {
            fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(friendID)
                .updateData(
                    [
                        FirebaseCollectionFields.pendingFriendRequests.rawValue: FieldValue.arrayRemove([uid])
                    ]
                )
        }
        
        if notificationID != "" {
            fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .document(uid)
                .collection(FirebaseCollectionNames.notifications.rawValue)
                .document(notificationID)
                .delete()
        }
        
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
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "AcceptedFriendRequest"), object: nil, userInfo: ["notiID": notificationID, "userID": friendId])

        // adjust individual posts "friendsList" docs
        DispatchQueue.global().async {
            do {
                let mapPostService = try ServiceContainer.shared.service(for: \.mapPostService)
                mapPostService.adjustPostFriendsList(userID: uid, friendID: friendId) { _ in
                    // send notification to home to reload posts
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

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SendFriendRequest"), object: nil, userInfo: ["userID": receiverID])
        completion?(nil)
    }
    
    func removeFriend(friendID: String) {
        /// firebase function broken
        DispatchQueue.global(qos: .utility).async { [weak self] in
            UserDataModel.shared.userInfo.friendIDs.removeAll(where: { $0 == friendID })
            UserDataModel.shared.userInfo.friendsList.removeAll(where: { $0.id == friendID })
            UserDataModel.shared.userInfo.topFriends?.removeValue(forKey: friendID)
            UserDataModel.shared.deletedFriendIDs.append(friendID)

            let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

            self?.removeFriendFromFriendsList(userID: uid, friendID: friendID)
            self?.removeFriendFromFriendsList(userID: friendID, friendID: uid)
            
            self?.removeFriendFromPosts(userID: uid, friendID: friendID)
            self?.removeFriendFromPosts(userID: friendID, friendID: uid)

            self?.removeFriendFromNotis(userID: uid, friendID: friendID)
            self?.removeFriendFromNotis(userID: friendID, friendID: uid)
        }
    }
    
    func removeFriendFromFriendsList(userID: String, friendID: String) {
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(userID).updateData(
                [
                    FirebaseCollectionFields.friendsList.rawValue: FieldValue.arrayRemove([friendID]),
                    "\(FirebaseCollectionFields.topFriends.rawValue).\(friendID)": FieldValue.delete(),
                    "spotScore": FieldValue.increment(Int64(-1))
                ]
            )
    }

    func removeSuggestion(userID: String) {
        fireStore.collection("users").document(UserDataModel.shared.uid).updateData(["hiddenUsers": FieldValue.arrayUnion([userID])])
    }

    func removeContactNotification(notiID: String) {
        print("remove contact notification", notiID)
        fireStore.collection("users").document(UserDataModel.shared.uid).collection("notifications").document(notiID).delete()
    }
    
    private func removeFriendFromPosts(userID: String, friendID: String) {
        fireStore.collection(FirebaseCollectionNames.posts.rawValue)
            .whereField(FirebaseCollectionFields.posterID.rawValue, isEqualTo: friendID)
            .getDocuments { snap, _ in
                guard let docs = snap?.documents else { return }
                for doc in docs {
                    doc.reference.updateData(
                        [
                            FirebaseCollectionFields.friendsList.rawValue: FieldValue.arrayRemove([userID])
                        ]
                    )
                }
            }
    }
    
    private func removeFriendFromNotis(userID: String, friendID: String) {
        let friendRequestValueString = "friendRequest"
        
        fireStore.collection(FirebaseCollectionNames.users.rawValue)
            .document(userID)
            .collection(FirebaseCollectionNames.notifications.rawValue)
            .whereField(FirebaseCollectionFields.senderID.rawValue, isEqualTo: friendID)
            .whereField(FirebaseCollectionFields.type.rawValue, isEqualTo: friendRequestValueString)
            .getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            for doc in docs {
                doc.reference.delete()
            }
        }
    }
}
