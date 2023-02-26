//
//  FirestoreSubscription.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift
import Firebase

final class FirestoreSubscription<S: Subscriber, Model: Codable>: Subscription {
    private var subscriber: S?
    private var listener: ListenerRegistration? = nil
    init(subscriber: S) {
        self.subscriber = subscriber
        self.listener = nil
    }
    deinit {
        listener?.remove()
    }

    func request(_ demand: Subscribers.Demand) {
    }
    
    func cancel() {
        subscriber = nil
        listener?.remove()
        listener = nil
    }
}

extension FirestoreSubscription  where S.Input == [Document<Model>], S.Failure == Error {
    convenience init(query: Query, subscriber: S) {
        self.init(subscriber: subscriber)
        self.listener = query.addSnapshotListener(result())
    }
    func result() -> ((QuerySnapshot?, Error?) -> Void) {
        { [weak self] (snapshot, error) in
            if let error = error {
                self?.subscriber?.receive(completion: Subscribers.Completion.failure(error))
            } else {
                do {
                    let data = try snapshot?.documents.map { document -> Document<Model> in
                        let data = try document.data(as: Model.self, decoder: Firestore.Decoder())
                        return .init(ref: document.reference, data: data)
                    }
                    
                    guard let data else { return }
                    _ = self?.subscriber?.receive(data)
                } catch {
                    self?.subscriber?.receive(completion: Subscribers.Completion.failure(error))
                }
            }
        }
    }
}

extension FirestoreSubscription where S.Input == Document<Model>, S.Failure == Error {
    convenience init(documentRef: DocumentReference, subscriber: S) {
        self.init(subscriber: subscriber)
        self.listener = documentRef.addSnapshotListener(result(ref: documentRef))
    }
    func result(ref: DocumentReference) -> ((DocumentSnapshot?, Error?) -> Void) {
        { [weak self] (snapshot, error) in
            if let error = error {
                self?.subscriber?.receive(completion: Subscribers.Completion.failure(error))
            } else {
                do {
                    guard let data = try snapshot?.data(as: Model.self, decoder: Firestore.Decoder()) else {
                        return
                    }
                    _ = self?.subscriber?.receive(.init(ref: ref, data: data))
                } catch {
                    self?.subscriber?.receive(completion: Subscribers.Completion.failure(error))
                }
            }
        }
    }
}
