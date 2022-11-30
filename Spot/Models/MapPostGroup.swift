//
//  MapPostGroup.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import MapKit

struct MapPostGroup: Hashable {
    struct PostID: Hashable {
        var id: String
        var timestamp: Timestamp
        var seen: Bool
    }

    var id: String /// can be post or spotID
    var coordinate: CLLocationCoordinate2D
    var spotName: String
    var postIDs: [PostID]

    /// properties for sorting
    var postsToSpot: [String] = []
    var postTimestamps: [Timestamp] = []
    var numberOfPosters: Int = 0

    var poiCategory: POICategory?

    mutating func sortPostIDs() {
        postIDs = postIDs.sorted { p1, p2 in
            guard p1.seen == p2.seen else {
                return !p1.seen && p2.seen
            }
            return p1.timestamp.seconds > p2.timestamp.seconds
        }
    }
}
