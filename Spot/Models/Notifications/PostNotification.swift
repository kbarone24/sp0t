//
//  PostNotification.swift
//  Spot
//
//  Created by kbarone on 8/30/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import UIKit

class PostNotification {

    var notiID: String
    var userInfo: UserProfile
    var originalPoster: String
    var timestamp: Firebase.Timestamp
    var type: String
    var post: MapPost

    init(notiID: String, userInfo: UserProfile, originalPoster: String, timestamp: Firebase.Timestamp, type: String, post: MapPost) {
        self.notiID = notiID
        self.userInfo = userInfo
        self.originalPoster = originalPoster
        self.timestamp = timestamp
        self.type = type
        self.post = post
    }
}
