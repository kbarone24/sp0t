//
//  PostTypes.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

enum PostParent: String {
    case Home
    case Spot
    case Map
    case Profile
    case Notifications
}

// values for feed fetch
enum FeedFetchType: Hashable {
    case MyPosts
    case NearbyPosts
}
