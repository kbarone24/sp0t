//
//  FirestorePublishers.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import FirebaseFirestore
import Combine

struct FirestoreCollectionPublisher<Model: Codable>: Publisher {
    typealias Output = [Document<Model>]
    typealias Failure = Error
    let query: Query
    init(query: Query) {
        self.query = query
    }
    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let subscription = FirestoreSubscription(query: query, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

struct FirestoreDocumentPublisher<Model: Codable>: Publisher {
    typealias Output = Document<Model>
    typealias Failure = Error
    let ref: DocumentReference
    init(documentRef: DocumentReference) {
        self.ref = documentRef
    }
    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let subscription = FirestoreSubscription(documentRef: ref, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}
