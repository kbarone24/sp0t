//
//  BotChatService.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

protocol BotChatServiceProtocol {
    func fetchMessages(limit: Int, endDocument: DocumentSnapshot?) async -> ([BotChatMessage], DocumentSnapshot?)
    func setSeen(chatID: String)
    func uploadChat(message: BotChatMessage)
}

final class BotChatService: BotChatServiceProtocol {
    private let fireStore: Firestore
    init(fireStore: Firestore) {
        self.fireStore = fireStore
    }

    func fetchMessages(limit: Int, endDocument: DocumentSnapshot?) async -> ([BotChatMessage], DocumentSnapshot?) {
        await withUnsafeContinuation { continuation in
            Task(priority: .high) {
                var query = self.fireStore
                    .collection(FirebaseCollectionNames.botChat.rawValue)
                    .whereField(BotChatCollectionFields.userID.rawValue, isEqualTo: UserDataModel.shared.uid)
                    .order(by: FirebaseCollectionFields.timestamp.rawValue, descending: true)

                if let endDocument {
                    query = query.start(afterDocument: endDocument)
                }

                guard let userService = try? ServiceContainer.shared.service(for: \.userService) else {
                    return
                }

                var botChatMessages = [BotChatMessage]()

                guard let docs = try? await query.getDocuments() else { return }
                for doc in docs.documents {
                    guard var chat = try? doc.data(as: BotChatMessage.self) else { continue }
                    let user = try? await userService.getUserInfo(userID: chat.senderID)
                    chat.userInfo = user
                    botChatMessages.append(chat)
                }

                let endDocument: DocumentSnapshot? = docs.count < limit ? nil : docs.documents.last

                continuation.resume(returning:( botChatMessages, endDocument))
            }
        }
    }

    func setSeen(chatID: String) {
        DispatchQueue.global(qos: .background).async {
            Firestore.firestore().collection(FirebaseCollectionNames.botChat.rawValue).document(chatID).updateData([
                BotChatCollectionFields.seenByUser.rawValue: true
            ])
        }
    }

    func uploadChat(message: BotChatMessage) {
        DispatchQueue.global(qos: .background).async {
            guard let messageID = message.id else { return }
            try? Firestore.firestore().collection(FirebaseCollectionNames.botChat.rawValue).document(messageID).setData(from: message)
        }
    }
}
