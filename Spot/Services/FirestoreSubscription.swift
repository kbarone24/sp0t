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

// https://stackoverflow.com/questions/69362825/how-to-use-swifts-new-async-await-features-with-firestore-listeners

struct FirestoreSubscription {
    static func subscribe(id: AnyHashable, docPath: String) -> AnyPublisher<DocumentSnapshot, Never> {
        let subject = PassthroughSubject<DocumentSnapshot, Never>()
        
        let docRef = Firestore.firestore().document(docPath)
        let listener = docRef.addSnapshotListener { snapshot, _ in
            if let snapshot = snapshot {
                subject.send(snapshot)
            }
        }
        
        listeners[id] = Listener(document: docRef, listener: listener, subject: subject)
        
        return subject.eraseToAnyPublisher()
    }
    
    static func cancel(id: AnyHashable) {
        listeners[id]?.listener.remove()
        listeners[id]?.subject.send(completion: .finished)
        listeners[id] = nil
    }
}

private var listeners: [AnyHashable: Listener] = [:]
private struct Listener {
    let document: DocumentReference
    let listener: ListenerRegistration
    let subject: PassthroughSubject<DocumentSnapshot, Never>
}
