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
                        
                        do {
                            guard var userInfo = try document.data(as: UserProfile.self) else {
                                continuation.resume(returning: emptyProfile)
                                return
                            }
                            
                            userInfo.id = document.documentID
                            continuation.resume(returning: userInfo)
                            
                        } catch {
                            continuation.resume(returning: emptyProfile)
                        }
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
                    .whereField(FireBaseCollectionFields.username.rawValue, isEqualTo: username)
                    .getDocuments { snapshot, error in
                        guard error == nil,
                              let doc = snapshot?.documents.first else {
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        do {
                            guard let userInfo = try doc.data(as: UserProfile.self) else {
                                continuation.resume(returning: nil)
                                return
                            }
                            
                            continuation.resume(returning: userInfo)
                            
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    }
            }
        }
    }
}
