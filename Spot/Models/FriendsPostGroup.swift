//
//  friendsPost.swift
//  Spot
//
//  Created by Kenny Barone on 4/7/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import UIKit

struct FriendsPostGroup {
    var posterID: String
    var postIDs: [(id: String, timestamp: Timestamp, seen: Bool)]
}
