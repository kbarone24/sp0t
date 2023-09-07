//
//  PopService.swift
//  Spot
//
//  Created by Kenny Barone on 8/25/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import FirebaseFunctions

protocol PopServiceProtocol {
    func fetchPops() async throws -> [Spot]
    func getPop(popID: String) async throws -> Spot?
    func setSeen(pop: Spot)
    func addUserToVisitorList(pop: Spot)
    func uploadPop(post: Post, spot: Spot, pop: Spot)
}

final class PopService: PopServiceProtocol {
    enum PopError: Error {
        case invalidPopID
    }

    private let fireStore: Firestore
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }


    func fetchPops() async throws -> [Spot] {
        try await withUnsafeThrowingContinuation { continuation in
            Task(priority: .high) {
                let query = self.fireStore.collection(FirebaseCollectionNames.pops.rawValue)
                    .order(by: PopCollectionFields.endTimestamp.rawValue, descending: true)
                    .whereField(PopCollectionFields.endTimestamp.rawValue, isGreaterThanOrEqualTo: Timestamp())

                var pops = [Spot]()
                let snap = try await query.getDocuments()

                // cant query 2 fields on inequality so check that the pop has started locally
                for doc in snap.documents {
                    if let pop = try? doc.data(as: Spot.self),
                       pop.userInRange(), !(pop.hidePop ?? false) {
                        pops.append(pop)
                    }
                }

                continuation.resume(returning: pops)
            }
        }
    }

    func getPop(popID: String) async throws -> Spot? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard popID != "" else {
                continuation.resume(throwing: PopError.invalidPopID)
                return
            }
            self?.fireStore.collection(FirebaseCollectionNames.pops.rawValue)
                .document(popID)
                .getDocument { doc, error in
                    guard error == nil, let doc
                    else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    guard let spotInfo = try? doc.data(as: Spot.self) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: spotInfo)
                }
        }
    }

    func setSeen(pop: Spot) {
        DispatchQueue.global(qos: .background).async {
            guard let popID = pop.id, popID != "" else { return }
            var values: [String: Any] = [
                SpotCollectionFields.seenList.rawValue : FieldValue.arrayUnion([UserDataModel.shared.uid]),
            ]
            if pop.userInRange() {
                values[SpotCollectionFields.visitorList.rawValue] = FieldValue.arrayUnion([UserDataModel.shared.uid])
            }
            self.fireStore.collection(FirebaseCollectionNames.pops.rawValue).document(popID).updateData(values)
        }
    }

    func addUserToVisitorList(pop: Spot) {
        // called from home screen pop overview
        DispatchQueue.global(qos: .background).async {
            guard let popID = pop.id, popID != "" else { return }
            self.fireStore.collection(FirebaseCollectionNames.pops.rawValue).document(popID).updateData([
                SpotCollectionFields.visitorList.rawValue: FieldValue.arrayUnion([UserDataModel.shared.uid])
            ])
        }
    }

    func uploadPop(post: Post, spot: Spot, pop: Spot) {
        guard let postID = post.id, let spotID = spot.id, let popID = pop.id else { return }
        var posters = post.taggedUserIDs ?? []
        posters.append(UserDataModel.shared.uid)

        let functions = Functions.functions()
        let parameters = [
            "popID": popID,
            "postID": postID,
            "uid": UserDataModel.shared.uid,
            "postPrivacy": post.privacyLevel ?? "public",
            "posters": posters,

            "caption": post.caption,
            "imageURL": post.imageURLs.first ?? "",
            "videoURL": post.videoURL ?? "",
            "username": UserDataModel.shared.userInfo.username,

            "homeSpotID": spotID,
            "homeSpotName": spot.spotName
        ] as [String: Any]

        Task {
            try? await functions.httpsCallable("runPopTransactions").call(parameters)
        }

    }
}

