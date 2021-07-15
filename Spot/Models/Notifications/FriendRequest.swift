//
//  FriendRequest.swift
//  Spot
//
//  Created by kbarone on 8/15/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class FriendRequest {
    
    var notiID: String
    var userInfo: UserProfile
    var timestamp: Firebase.Timestamp
    var accepted: Bool
    
    init(notiID: String, userInfo: UserProfile, timestamp: Firebase.Timestamp, accepted: Bool) {
        self.notiID = notiID
        self.userInfo = userInfo
        self.timestamp = timestamp
        self.accepted = accepted
    }
}
