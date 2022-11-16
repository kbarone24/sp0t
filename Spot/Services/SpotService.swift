//
//  SpotService.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

protocol SpotServiceProtocol {
    func getSpot(spotID: String) async throws -> MapSpot?
}

final class SpotService: SpotServiceProtocol {
    
    private let fireStore: Firestore
    
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }
    
    func getSpot(spotID: String) async throws -> MapSpot? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.fireStore.collection(FirebaseCollectionNames.spots.rawValue)
                .document(spotID)
                .getDocument { doc, error in
                    guard error == nil,
                          let doc
                    else {
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    do {
                        guard var spotInfo = try doc.data(as: MapSpot.self) else {
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        
                        spotInfo.id = spotID
                        spotInfo.spotDescription = "" /// remove spotdescription, no use for it here, will either be replaced with POI description or username
                        for visitor in spotInfo.visitorList where UserDataModel.shared.userInfo.friendIDs.contains(visitor) {
                            spotInfo.friendVisitors += 1
                        }
                        
                        continuation.resume(returning: spotInfo)
                        
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}
