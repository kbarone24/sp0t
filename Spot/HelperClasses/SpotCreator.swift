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
        let spot = MapSpot(city: city, spotName: spotName, spotLat: spotLat, spotLong: spotLong)
        if let spotID = spot.id {
            try? Firestore.firestore().collection(FirebaseCollectionNames.spots.rawValue).document(spotID).setData(from: spot)
        } else {
            print("no id")
        }
    }
}
