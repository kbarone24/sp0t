//
//  Notification.swift
//  Spot
//
//  Created by Shay Gyawali on 6/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore
import UIKit

struct UserNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var seen: Bool
    var senderID: String
    var timestamp: Timestamp
    var type: String
    var userInfo: UserProfile?
    var postInfo: Post? /// only for activity notifications
    var spotInfo: Spot?
    var popInfo: Spot?
    var mapID: String?
    var mapName: String?
    var spotID: String?
    var popID: String?
    var commentID: String?
    var imageURL: String?
    var originalPoster: String?
    var postID: String?
    var senderUsername: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case seen
        case senderID
        case type
        case timestamp
        case mapID
        case mapName
        case commentID
        case imageURL
        case originalPoster
        case postID
        case senderUsername
        case status
        case spotID
        case popID
    }
}

extension UserNotification: Hashable {
    static func == (lhs: UserNotification, rhs: UserNotification) -> Bool {
        return lhs.id == rhs.id &&
        lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
    }
}
