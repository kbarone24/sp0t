//
//  FirestoreDecoder.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase

// https://stackoverflow.com/questions/69362825/how-to-use-swifts-new-async-await-features-with-firestore-listeners

struct FirestoreDecoder {
    static func decode<T>(_ type: T.Type) -> (DocumentSnapshot) -> T? where T: Decodable {
        { snapshot in
            try? snapshot.data(as: type)
        }
    }
}
