//
//  FireStoreDocument.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import FirebaseFirestoreSwift
import FirebaseFirestore
import Combine

struct Document<Model: Codable> {
    let ref: DocumentReference
    let data: Model
    static func get(collectionPath: String, id: String) -> Deferred<Future<Document<Model>, Error>> {
        .init { () -> Future<Document<Model>, Error> in
            let document = Firestore.firestore().collection(collectionPath).document(id)
            return get(documentRef: document)
        }
    }
    
    static func get(documentRef: DocumentReference) -> Deferred<Future<Document<Model>, Error>> {
        .init { () -> Future<Document<Model>, Error> in
            get(documentRef: documentRef)
        }
    }
    
    static func listen(documentRef: DocumentReference) -> Deferred<FirestoreDocumentPublisher<Model>> {
        .init { () -> FirestoreDocumentPublisher<Model> in
            listen(documentRef: documentRef)
        }
    }
    
    static func listen(query: Query) -> Deferred<FirestoreCollectionPublisher<Model>> {
        .init { () -> FirestoreCollectionPublisher<Model> in
            listen(query: query)
        }
    }
    
    private static func get(documentRef: DocumentReference) -> Future<Document<Model>, Error> {
        .init { observer in
            documentRef.getDocument { (snapshot, error) in
                if let error = error {
                    observer(.failure(error))
                } else {
                    do {
                        let data = try snapshot!.data(as: Model.self, decoder: Firestore.Decoder())
                        observer(.success(.init(ref: documentRef, data: data)))
                    } catch {
                        observer(.failure(error))
                    }
                }
            }
        }
    }
    
    private static func get(query: Query) -> Future<[Document<Model>], Error> {
        .init { observer in
            query.getDocuments { (snapshot, error) in
                if let error = error {
                    observer(.failure(error))
                } else {
                    do {
                        let data = try snapshot!.documents.map { document -> Document<Model> in
                            let data = try document.data(as: Model.self, decoder: Firestore.Decoder())
                            return .init(ref: document.reference, data: data)
                        }
                        observer(.success(data))
                    } catch {
                        observer(.failure(error))
                    }
                }
            }
        }
    }
    
    private static func listen(documentRef: DocumentReference) -> FirestoreDocumentPublisher<Model> {
        return .init(documentRef: documentRef)
    }
    
    private static func listen(query: Query) -> FirestoreCollectionPublisher<Model> {
        return .init(query: query)
    }
}

public extension Query {
    // MARK: - Get Documents
    /// Reads the documents matching this query.
    ///
    /// - Parameter source: Indicates whether the results should be fetched from the cache only
    ///   (`Source.cache`), the server only (`Source.server`), or to attempt the server and fall back
    ///   to the cache (`Source.default`).
    /// - Returns: A publisher emitting a `QuerySnapshot` instance.
    func getDocuments(source: FirestoreSource = .default) -> Future<QuerySnapshot, Error> {
        Future { promise in
            self.getDocuments(source: source) { snapshot, error in
                if let error = error {
                    promise(.failure(error))
                } else if let snapshot = snapshot {
                    promise(.success(snapshot))
                }
            }
        }
    }
    
    // MARK: - Snapshot Publisher
    /// Registers a publisher that publishes query snapshot changes.
    ///
    /// - Parameter includeMetadataChanges: Whether metadata-only changes (i.e. only
    ///   `QuerySnapshot.metadata` changed) should trigger snapshot events.
    /// - Returns: A publisher emitting `QuerySnapshot` instances.
    func snapshotPublisher(includeMetadataChanges: Bool = false)
    -> AnyPublisher<QuerySnapshot, Error> {
        let subject = PassthroughSubject<QuerySnapshot, Error>()
        let listenerHandle =
        addSnapshotListener(includeMetadataChanges: includeMetadataChanges) { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(error))
            } else if let snapshot = snapshot {
                subject.send(snapshot)
            }
        }
        return subject
            .handleEvents(receiveCancel: listenerHandle.remove)
            .eraseToAnyPublisher()
    }
}
