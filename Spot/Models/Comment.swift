//
//  Comment.swift
//  Spot
//
//  Created by kbarone on 6/24/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit

class Comment {

    var commentID: String
    var commenterID: String
    var comment: String
    var time: Int64
    var date: Date
    var taggedFriends: [String]
    var commentHeight: CGFloat

    init(commentID: String, commenterID: String, comment: String, time: Int64, date: Date, taggedFriends: [String], commentHeight: CGFloat) {
        self.commentID = commentID
        self.commenterID = commenterID
        self.comment = comment
        self.time = time
        self.date = date
        self.taggedFriends = taggedFriends
        self.commentHeight = commentHeight
    }
}
