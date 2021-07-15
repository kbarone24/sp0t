//
//  SpotNotification.swift
//  Spot
//
//  Created by Kenny Barone on 6/18/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class SpotNotification {
    
    var notiID: String
    var userInfo: UserProfile
    var originalPoster: String
    var timestamp: Firebase.Timestamp
    var type: String
    var spot: MapSpot
    
    init(notiID: String, userInfo: UserProfile, originalPoster: String, timestamp: Firebase.Timestamp, type: String, spot: MapSpot) {
        self.notiID = notiID
        self.userInfo = userInfo
        self.originalPoster = originalPoster
        self.timestamp = timestamp
        self.type = type
        self.spot = spot
    }
}
