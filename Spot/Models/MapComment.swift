//
//  MapComment.swift
//  Spot
//
//  Created by kbarone on 7/22/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestoreSwift

struct MapComment: Identifiable, Codable {
    
    @DocumentID var id: String?
    var comment: String
    var commenterID: String
    var timestamp: Firebase.Timestamp
    var userInfo: UserProfile?

    var taggedUsers: [String]? = []
    var commentHeight: CGFloat = 0
    var seconds: Int64 = 0
    
    enum CodingKeys: String, CodingKey {
        case comment
        case commenterID
        case taggedUsers
        case timestamp
    }
}
