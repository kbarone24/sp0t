//
//  SearchResult.swift
//  Spot
//
//  Created by Kenny Barone on 6/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

enum SearchResultType {
    case spot
    case user
}

struct SearchResult: Identifiable, Hashable, Equatable {
    var id: String?
    var type: SearchResultType
    var map: CustomMap?
    var spot: MapSpot?
    var user: UserProfile?
    var ranking: Int

    init(id: String?, type: SearchResultType, map: CustomMap? = nil, spot: MapSpot? = nil, user: UserProfile? = nil, ranking: Int) {
        self.id = id
        self.type = type
        self.map = map
        self.spot = spot
        self.user = user
        self.ranking = ranking
    }
}
