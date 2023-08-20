//
//  BotChat.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestoreSwift
import FirebaseFirestore
import UIKit

struct BotChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var senderID: String
    var seenByUser: Bool
    var seenByBot: Bool
    var text: String
    var timestamp: Timestamp
    var userID: String
    var userInfo: UserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID
        case seenByUser
        case seenByBot
        case text
        case timestamp
        case userID
    }
}

extension BotChatMessage: Hashable {
    static func == (lhs: BotChatMessage, rhs: BotChatMessage) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
