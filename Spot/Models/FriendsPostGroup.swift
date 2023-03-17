//
//  friendsPost.swift
//  Spot
//
//  Created by Kenny Barone on 4/7/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import Foundation
import UIKit

struct FriendsPostGroup: Hashable {
    var posterID: String
    var postIDs: [PostID]
    
    struct PostID: Hashable {
        let id: String
        let timestamp: Timestamp
        let seen: Bool
    }
}
