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
    func getUserFriends() async throws -> [UserProfile]
    func getUserFromUsername(username: String) async throws -> UserProfile?
    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String], mapID: String)
    func updateUsername(newUsername: String, oldUsername: String) async
    func usernameAvailable(username: String, completion: @escaping(_ err: String) -> Void)
    func fetchAllUsers() async throws -> [UserProfile]
}

final class UserService: UserServiceProtocol {
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func getUserInfo(userID: String) async throws -> UserProfile {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            let emptyProfile = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            
            guard !userID.isEmpty else {
                print("empty user id")
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

    func getUserFromUsername(username: String) async throws -> UserProfile? {
        try await withUnsafeThrowingContinuation { [weak self] continuation in
            if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == username }) {
                continuation.resume(returning: user)
                
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
    
    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String], mapID: String) {
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            let tag = post.tag ?? ""
            let addedUsers = post.addedUsers ?? []
            
            var posters = [poster]
            posters.append(contentsOf: addedUsers)
            
            let friendsService = try? ServiceContainer.shared.service(for: \.friendsService)
            
            // adjust user values for added users
            for poster in posters {
                /// increment addedUsers spotScore by 1
                var userValues = ["spotScore": FieldValue.increment(Int64(3))]
                if tag != "" {
                    userValues["tagDictionary.\(tag)"] = FieldValue.increment(Int64(1))
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
                let mapQuery = self.fireStore.collection(FirebaseCollectionNames.maps.rawValue).whereField(FirebaseCollectionFields.posterUsernames.rawValue, arrayContains: oldUsername)
                let mapService = try? ServiceContainer.shared.service(for: \.mapsService)
                let maps = try await mapService?.getMapsFrom(query: mapQuery)
                for map in maps ?? [] {
                    guard let mapID = map.id else { continue }
                    var posterUsernames = map.posterUsernames
                    for i in 0..<posterUsernames.count where posterUsernames[i] == oldUsername {
                        posterUsernames[i] = newUsername
                    }
                    try await self.fireStore.collection(FirebaseCollectionNames.maps.rawValue).document(mapID).updateData([FirebaseCollectionFields.posterUsernames.rawValue: posterUsernames])
                }

                let _ = try await self.updateUsernamesCollection(newUsername: newUsername, oldUsername: oldUsername)

                let spotQuery = self.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                    .whereField(FirebaseCollectionFields.posterUsername.rawValue, isEqualTo: oldUsername)
                let spotService = try? ServiceContainer.shared.service(for: \.spotService)
                let spots = try await spotService?.getSpots(query: spotQuery)
                for spot in spots ?? [] {
                    guard let spotID = spot.id else { continue }
                    try await self.fireStore.collection(FirebaseCollectionNames.spots.rawValue).document(spotID).updateData([FirebaseCollectionFields.posterUsername.rawValue: newUsername])
                }
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
}
