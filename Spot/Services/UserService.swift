//
//  UserService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseFirestore
import Firebase

protocol UserServiceProtocol {
    func getUserInfo(userID: String) async throws -> UserProfile
    func getUserFromUsername(username: String) async throws -> UserProfile?
    func getUserFriends() async throws -> [UserProfile]
    func getProfileInfo(cachedProfile: UserProfile) async throws -> UserProfile
    func setUserValues(poster: String, post: MapPost)
    func updateUsername(newUsername: String, oldUsername: String) async
    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void)
    func fetchAllUsers() async throws -> [UserProfile]
    func setNewAvatarSeen()
    func getUsersFrom(searchText: String, limit: Int) async throws -> [UserProfile]
    func queryFriendsFromFriendsList(searchText: String) -> [UserProfile]
    func uploadContactsToDB(contacts: [ContactInfo])
    func updateProfile(userProfile: UserProfile, keywords: [String], oldUsername: String)
    func deleteAccount() async throws -> Bool
    func updateUserLastSeen(spotID: String)
}

final class UserService: UserServiceProtocol {
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func getUserInfo(userID: String) async throws -> UserProfile {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            let emptyProfile = UserProfile()
            
            guard !userID.isEmpty else {
                continuation.resume(returning: emptyProfile)
                return
            }
            
            if UserDataModel.shared.friendsFetched, let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.id == userID }) {
                continuation.resume(returning: user)
                return
                
            } else if userID == UserDataModel.shared.uid && UserDataModel.shared.userInfo.username != "" {
                continuation.resume(returning: UserDataModel.shared.userInfo)
                return
                
            } else {
                self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                    .document(userID)
                    .getDocument { document, error in
                        guard let document, error == nil else {
                            continuation.resume(returning: emptyProfile)
                            return
                        }
                        
                        guard var userInfo = try? document.data(as: UserProfile.self) else {
                            continuation.resume(returning: emptyProfile)
                            return
                        }
                        
                        userInfo.id = document.documentID
                        continuation.resume(returning: userInfo)
                    }
            }
        }
    }

    func getUserFriends() async throws -> [UserProfile] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).whereField(FirebaseCollectionFields.friendsList.rawValue, arrayContains: UserDataModel.shared.uid).getDocuments(completion: { snap, error in
                guard let docs = snap?.documents, error == nil else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: [])
                    }
                    return
                }

                Task {
                    var friendsList: [UserProfile] = []
                    for doc in docs {
                        guard let userInfo = try? doc.data(as: UserProfile.self) else { continue }
                        friendsList.append(userInfo)
                    }
                    continuation.resume(returning: friendsList)
                }
            })
        }
    }

    func getProfileInfo(cachedProfile: UserProfile) async throws -> UserProfile {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            // only fetch strangers profile
            guard cachedProfile.id != UserDataModel.shared.uid else {
                continuation.resume(returning: cachedProfile)
                return
            }

            if let id = cachedProfile.id, id != "" {
                // fetch with id
                self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                    .document(cachedProfile.id ?? "")
                    .getDocument(completion: { doc, _ in
                        let userInfo = try? doc?.data(as: UserProfile.self)
                        continuation.resume(returning: userInfo ?? cachedProfile)
                    })
            } else {
                // query for username
                self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                    .whereField(FirebaseCollectionFields.username.rawValue, isEqualTo: cachedProfile.username)
                    .getDocuments(completion: { snap, _ in
                        let userInfo = try? snap?.documents.first?.data(as: UserProfile.self)
                        continuation.resume(returning: userInfo ?? cachedProfile)
                    })
            }
        }
    }

    func getUserFromUsername(username: String) async throws -> UserProfile? {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == username }) {
                continuation.resume(returning: user)
                return
                
            } else if username == UserDataModel.shared.userInfo.username && UserDataModel.shared.userInfo.username != "" {
                continuation.resume(returning: UserDataModel.shared.userInfo)
                return

            } else {
                self?.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                    .whereField(FirebaseCollectionFields.username.rawValue, isEqualTo: username)
                    .getDocuments { snapshot, error in
                        guard error == nil,
                              let doc = snapshot?.documents.first else {
                            continuation.resume(returning: nil)
                            return
                        }
                        guard let userInfo = try? doc.data(as: UserProfile.self) else {
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        continuation.resume(returning: userInfo)
                    }
            }
        }
    }
    
    func setUserValues(poster: String, post: MapPost) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let addedUsers = post.taggedUserIDs ?? []
            
            var posters = [poster]
            posters.append(contentsOf: addedUsers)
            
            let friendsService = try? ServiceContainer.shared.service(for: \.friendsService)
            
            // adjust user values for added users
            for poster in posters {
                /// increment addedUsers spotScore by 1. don't increment if secret map to prevent users from cheating
                var userValues = [
                    UserCollectionFields.spotScore.rawValue: FieldValue.increment(Int64(1)),
                    UserCollectionFields.lastSeen.rawValue: Timestamp(),
                    UserCollectionFields.lastHereNow.rawValue: post.spotID ?? ""
                ] as [AnyHashable : Any]

                if post.parentPostID == nil {
                    // increment post count if this isn't a comment
                    userValues[UserCollectionFields.postCount.rawValue] = FieldValue.increment(Int64(1))
                }

                if let spotID = post.spotID, spotID != "" {
                    userValues[UserCollectionFields.spotsList.rawValue] = FieldValue.arrayUnion([spotID])
                }
                
                /// remove this user for topFriends increments
                var dictionaryFriends = posters
                dictionaryFriends.removeAll(where: { $0 == poster })
                
                /// increment top friends if added friends
                for user in dictionaryFriends {
                    friendsService?.incrementTopFriends(friendID: user, increment: 5, completion: nil)
                }
                
                self?.fireStore
                    .collection(FirebaseCollectionNames.users.rawValue)
                    .document(poster)
                    .updateData(userValues)
            }
        }
    }
    
    func updateUsername(newUsername: String, oldUsername: String) async {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            Task {
                // update spot post's poster usernames
                let spotsQuery = self.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .whereField(SpotCollectionFields.postUsernames.rawValue, arrayContains: oldUsername)
                let spotService = try? ServiceContainer.shared.service(for: \.spotService)
                let spots = try await spotService?.getSpots(query: spotsQuery)

                for spot in spots ?? [] {
                    guard let spotID = spot.id, var postUsernames = spot.postUsernames, var posterUsername = spot.posterUsername else { continue }
                    // check for usernames of individual posts
                    for i in 0..<postUsernames.count where postUsernames[i] == oldUsername {
                        postUsernames[i] = newUsername
                    }
                    var values: [String: Any] = [
                        SpotCollectionFields.postUsernames.rawValue: postUsernames
                    ]

                    // original spot creator username updated
                    if posterUsername == oldUsername {
                        posterUsername = newUsername
                        values[posterUsername] = posterUsername
                    }
                    try await self.fireStore.collection(FirebaseCollectionNames.spots.rawValue).document(spotID).updateData(values)
                }

                // update posts' posterUsername field with new username
                let postService = try? ServiceContainer.shared.service(for: \.mapPostService)
                let postQuery = self.fireStore.collection(FirebaseCollectionNames.posts.rawValue)
                    .whereField(PostCollectionFields.posterUsername.rawValue, isEqualTo: oldUsername)
                let posts = try await postService?.getPostDocuments(query: postQuery)

                for post in posts ?? [] {
                        guard let postID = post.id else { continue }
                        try await self.fireStore.collection(FirebaseCollectionNames.posts.rawValue).document(postID).updateData([
                            PostCollectionFields.posterUsername.rawValue: newUsername
                        ])
                }

                let _ = try await self.updateUsernamesCollection(newUsername: newUsername, oldUsername: oldUsername)

                return
            }
        }
    }

    private func updateUsernamesCollection(newUsername: String, oldUsername: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.fireStore.collection(FirebaseCollectionNames.usernames.rawValue)
                .whereField(FirebaseCollectionFields.username.rawValue, isEqualTo: oldUsername)
                .getDocuments { snap, error in
                    guard error == nil, let docs = snap?.documents, !docs.isEmpty
                    else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: false)
                        }
                        return
                    }
                    Task {
                        if let doc = docs.first {
                            try await doc.reference.updateData([FirebaseCollectionFields.username.rawValue: newUsername])
                            continuation.resume(returning: true)
                        }
                    }
                }
        }
    }

    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void) {
        if let error = username.checkIfInvalid() {
            completion(error)
            return
        }

        let usersRef = fireStore.collection("usernames")
        let query = usersRef.whereField("username", isEqualTo: username)

        query.getDocuments { snap, err in
            guard err == nil else {
                completion("error")
                return
            }

            if let documents = snap?.documents, !documents.isEmpty {
                completion("Taken")
            } else {
                completion("")
            }
        }
    }

    func fetchAllUsers() async throws -> [UserProfile] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).getDocuments(completion: { snap, error in
                guard let docs = snap?.documents, error == nil else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: [])
                    }
                    return
                }

                Task {
                    var userList: [UserProfile] = []
                    for doc in docs {
                        guard let userInfo = try? doc.data(as: UserProfile.self) else { continue }
                        userList.append(userInfo)
                    }
                    continuation.resume(returning: userList)
                }
            })
        }
    }

    func setNewAvatarSeen() {
        DispatchQueue.global(qos: .background).async {
            Firestore.firestore().collection(FirebaseCollectionNames.users.rawValue).document(UserDataModel.shared.uid).updateData([UserCollectionFields.newAvatarNoti.rawValue: false])
        }
    }

    func getUsersFrom(searchText: String, limit: Int) async throws -> [UserProfile] {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.users.rawValue).whereField("usernameKeywords", arrayContains: searchText.lowercased()).limit(to: limit).getDocuments(completion: { snap, error in
                guard let docs = snap?.documents, error == nil else {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: [])
                    }
                    return
                }

                Task {
                    var userList: [UserProfile] = []
                    for doc in docs {
                        guard let userInfo = try? doc.data(as: UserProfile.self) else { continue }
                        userList.append(userInfo)
                    }
                    continuation.resume(returning: userList)
                }
            })
        }
    }

    func queryFriendsFromFriendsList(searchText: String) -> [UserProfile] {
        var friendsList = UserDataModel.shared.userInfo.friendsList
        friendsList.append(UserDataModel.shared.userInfo)
        var queryFriends = [UserProfile]()

        let usernames = friendsList.map({ $0.username })
        let filteredNames = usernames.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: .caseInsensitive) != nil
        })

        for name in filteredNames {
            if let friend = friendsList.first(where: { $0.username == name }) { queryFriends.append(friend) }
        }
        return queryFriends
    }

    func uploadContactsToDB(contacts: [ContactInfo]) {
        DispatchQueue.global(qos: .background).async {
            var contactsDictionary = [String: String]()
            for contact in contacts {
                contactsDictionary[contact.formattedNumber] = contact.fullName
            }
            self.fireStore.collection("users").document(UserDataModel.shared.uid).updateData(["contactsDictionary" : contactsDictionary])
        }
    }

    func updateProfile(userProfile: UserProfile, keywords: [String], oldUsername: String) {
        DispatchQueue.global(qos: .background).async {
            Firestore.firestore().collection(FirebaseCollectionNames.users.rawValue).document(UserDataModel.shared.uid).updateData([
                UserCollectionFields.avatarURL.rawValue: userProfile.avatarURL ?? "",
                UserCollectionFields.avatarFamily.rawValue: userProfile.avatarFamily ?? "",
                UserCollectionFields.avatarItem.rawValue: userProfile.avatarItem ?? "",
                UserCollectionFields.userBio.rawValue: userProfile.userBio,
                UserCollectionFields.username.rawValue: userProfile.username,
                UserCollectionFields.usernameKeywords.rawValue: keywords
            ])
        }

        if userProfile.username != oldUsername {
            Task {
                await updateUsername(newUsername: userProfile.username, oldUsername: oldUsername)
            }
        }
    }

    func updateUserLastSeen(spotID: String) {
        fireStore.collection(FirebaseCollectionNames.users.rawValue).document(UserDataModel.shared.uid).updateData([
            UserCollectionFields.lastSeen.rawValue: Timestamp(),
            UserCollectionFields.lastHereNow.rawValue: spotID
        ])
    }

    func deleteAccount() async throws -> Bool {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                // delete from friends' friendsList
                for id in UserDataModel.shared.userInfo.friendIDs {
                    let friendsService = ServiceContainer.shared.friendsService
                    friendsService?.removeFriendFromFriendsList(userID: id, friendID: UserDataModel.shared.uid)
                }

                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "phoneNumber")

                let delete0 = try? await deleteUserFromUsernames()
                let delete1 = try? await deleteUserFromSpots()
                let delete2 = try? await deleteUserFromNotifications()

                let uid = UserDataModel.shared.uid
                try? await fireStore.collection(FirebaseCollectionNames.users.rawValue).document(uid).delete()

                if delete0 != nil, delete1 != nil, delete2 != nil {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }

        }
    }

    private func deleteUserFromUsernames() async throws -> Bool {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                print("delete from usernames")
                let username = UserDataModel.shared.userInfo.username
                let docs = try? await fireStore.collection(FirebaseCollectionNames.usernames.rawValue)
                    .whereField(UserCollectionFields.username.rawValue, isEqualTo: username)
                    .getDocuments()
                for doc in docs?.documents ?? [] {
                    try? await doc.reference.delete()
                }
                continuation.resume(returning: true)
            }
        }
    }

    private func deleteUserFromSpots() async throws -> Bool {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                print("delete from spots")
                let uid = UserDataModel.shared.uid
                let docs = try? await fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .whereField(SpotCollectionFields.visitorList.rawValue, arrayContains: uid)
                    .getDocuments()
                for doc in docs?.documents ?? [] {
                    try? await doc.reference.updateData([
                        SpotCollectionFields.visitorList.rawValue: FieldValue.arrayRemove([uid])
                    ])
                }
                continuation.resume(returning: true)
            }
        }
    }

    // have to delete nested collections for full document delete
    private func deleteUserFromNotifications() async throws -> Bool {
        try await withUnsafeThrowingContinuation { continuation in
            Task {
                print("delete from notis")
                let uid = UserDataModel.shared.uid
                let docs = try? await fireStore.collection(FirebaseCollectionNames.users.rawValue).document(uid).collection(FirebaseCollectionNames.notifications.rawValue).getDocuments()
                for doc in docs?.documents ?? [] {
                    try? await doc.reference.delete()
                }
                continuation.resume(returning: true)
            }
        }
    }
}
