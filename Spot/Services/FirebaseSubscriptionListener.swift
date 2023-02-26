//
//  FirebaseSubscriptionListener.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Combine
import FirebaseFirestore
import FirebaseFirestoreSwift
import Firebase

// https://stackoverflow.com/questions/69362825/how-to-use-swifts-new-async-await-features-with-firestore-listeners

struct FirestoreSubscriptionListener {
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


// https://stackoverflow.com/questions/69362825/how-to-use-swifts-new-async-await-features-with-firestore-listeners

struct FirestoreDecoder {
    static func decode<T>(_ type: T.Type) -> (DocumentSnapshot) -> T? where T: Decodable {
        { snapshot in
            try? snapshot.data(as: type)
        }
    }
}
