//
//  UserService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

protocol UserServiceProtocol {
    func getUserInfo(userID: String) async throws -> UserProfile
    func getUserFromUsername(username: String) async throws -> UserProfile?
    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String], mapID: String)
    func updateUsername(newUsername: String, oldUsername: String) async
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
                continuation.resume(returning: emptyProfile)
                return
            }
            
            if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.id == userID }) {
                continuation.resume(returning: user)
                return
                
            } else if userID == UserDataModel.shared.uid {
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
            
            self.fireStore.collection(FirebaseCollectionNames.maps.rawValue)
                .getDocuments { snap, _ in
                    guard let snap = snap else { return }
                    for doc in snap.documents {
                        var posterUsernames = doc.get(FirebaseCollectionFields.posterUsernames.rawValue) as? [String] ?? []
                        for i in 0..<posterUsernames.count where posterUsernames[i] == oldUsername {
                            posterUsernames[i] = newUsername
                        }
                        doc.reference.updateData([FirebaseCollectionFields.posterUsernames.rawValue: posterUsernames])
                    }
                }
            
            self.fireStore.collection(FirebaseCollectionNames.users.rawValue)
                .whereField(FirebaseCollectionFields.username.rawValue, isEqualTo: oldUsername)
                .getDocuments { snap, _ in
                    guard let snap = snap else { return }
                    if let doc = snap.documents.first {
                        let keywords = newUsername.getKeywordArray()
                        doc.reference.updateData([
                            FirebaseCollectionFields.username.rawValue: newUsername,
                            FirebaseCollectionFields.usernameKeywords.rawValue: keywords
                        ])
                    }
                }
            
            self.fireStore.collection(FirebaseCollectionNames.usernames.rawValue)
                .whereField(FirebaseCollectionFields.username.rawValue, isEqualTo: oldUsername)
                .getDocuments { snap, _ in
                    guard let snap = snap else { return }
                    if let doc = snap.documents.first {
                        doc.reference.updateData([FirebaseCollectionFields.username.rawValue: newUsername])
                    }
                }
            
            self.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                .whereField(FirebaseCollectionFields.posterUsername.rawValue, isEqualTo: oldUsername)
                .getDocuments { snap, _ in
                    guard let snap = snap else { return }
                    if let doc = snap.documents.first {
                        doc.reference.updateData([FirebaseCollectionFields.posterUsername.rawValue: newUsername])
                    }
                }
        }
    }
}
