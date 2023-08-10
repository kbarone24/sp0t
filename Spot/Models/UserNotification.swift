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

struct UserNotification: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var seen: Bool
    var senderID: String
    var timestamp: Timestamp
    var type: String
    var userInfo: UserProfile?
    var postInfo: MapPost? /// only for activity notifications
    var spotInfo: MapSpot?
    var mapID: String?
    var mapName: String?
    var spotID: String?
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
    }
}
