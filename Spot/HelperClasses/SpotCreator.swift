//
//  SpotCreator.swift
//  Spot
//
//  Created by Kenny Barone on 8/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class SpotCreator {
    static let shared = SpotCreator()
    let ChapelHillString = "Chapel Hill, NC"

    // variables: city, name, founderID, posterUsername, visitorList, imageURL, searchKeywords,
    func createAndUploadSpot(city: String, spotName: String, spotLat: Double, spotLong: Double) {
        let spot = Spot(city: city, spotName: spotName, spotLat: spotLat, spotLong: spotLong)
        if let spotID = spot.id {
            try? Firestore.firestore().collection(FirebaseCollectionNames.spots.rawValue).document(spotID).setData(from: spot)
        } else {
            print("no id")
        }
    }

    func createAndUploadPop(popName: String, popDescription: String, coverImageURL: String, popHostSpotID: String, startTimestamp: Timestamp, endTimestamp: Timestamp, radius: Double) {
        Task {
            let hostSpot = try? await ServiceContainer.shared.spotService?.getSpot(spotID: popHostSpotID)
            guard let hostSpot else { return }
            let pop = Spot(city: ChapelHillString, popName: popName, popDescription: popDescription, coverImageURL: coverImageURL, hostSpot: hostSpot, startTimestamp: startTimestamp, endTimestamp: endTimestamp, radius: radius)
            if let popID = pop.id {
                try? Firestore.firestore().collection(FirebaseCollectionNames.pops.rawValue).document(popID).setData(from: pop)
            }
        }
    }
}
