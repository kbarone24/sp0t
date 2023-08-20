//
//  BotChatViewModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Combine
import IdentifiedCollections

class BotChatViewModel {
    typealias Section = BotChatController.Section
    typealias Item = BotChatController.Item
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    struct Input {
        let refresh: PassthroughSubject<Bool, Never>
    }

    struct Output {
        let snapshot: AnyPublisher<Snapshot, Never>
    }

    let userService: UserServiceProtocol
    let botService: BotChatServiceProtocol

    private let fetchLimit = 10

    var cachedChats: IdentifiedArrayOf<BotChatMessage> = []

    init(serviceContainer: ServiceContainer) {
        guard let userService = try? serviceContainer.service(for: \.userService),
              let botService = try? serviceContainer.service(for: \.botChatService)
        else {
            self.userService = UserService(fireStore: Firestore.firestore())
            self.botService = BotChatService(fireStore: Firestore.firestore())
            return
        }
        self.userService = userService
        self.botService = botService
    }

    func bind(to input: Input) -> Output {
        let request = input.refresh
            .receive(on: DispatchQueue.global(qos: .background))
            .flatMap { [unowned self] refresh in
                (self.fetchSpots(refresh: refresh))
            }
            .map { $0 }

        let snapshot = request
            .receive(on: DispatchQueue.main)
            .map { chats in
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                _ = chats.map {
                    snapshot.appendItems([.item(chat: $0)], toSection: .main)
                }
                return snapshot
            }
            .eraseToAnyPublisher()
        return Output(snapshot: snapshot)
    }



    private func fetchSpots(
        refresh: Bool
    ) -> AnyPublisher<([BotChatMessage]), Never> {
        Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.success(([])))
                    return
                }

                guard refresh else {
                    promise(.success((self.cachedChats.elements)))
                    return
                }

                Task {
                    let data = await self.botService.fetchMessages(limit: self.fetchLimit, endDocument: nil)

                    let reversedMessages = data.0.reversed()
                    let messages = (self.cachedChats.elements + reversedMessages).removingDuplicates()
                    promise(.success((messages)))

                    DispatchQueue.main.async {
                        self.cachedChats = IdentifiedArrayOf(uniqueElements: messages)
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func setSeenFor(chatID: String) {
        botService.setSeen(chatID: chatID)
    }

    func uploadChat(text: String) {
        var message = BotChatMessage(
            senderID: UserDataModel.shared.uid,
            seenByUser: true,
            seenByBot: false,
            text: text,
            timestamp: Timestamp(),
            userID: UserDataModel.shared.uid
        )
        message.id = UUID().uuidString
        message.userInfo = UserDataModel.shared.userInfo

        botService.uploadChat(message: message)
        cachedChats.append(message)
    }
}
