//
//  MapPostGroupCache.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Firebase

final class MapPostGroupCache: NSObject, NSCoding {
    let id: String
    let longitude: Double
    let latitude: Double
    let spotName: String
    let postIDs: [PostIDCache]
    let postsToSpot: [String]
    let postTimestamps: [Timestamp]
    let numberOfPosters: Int
    let poiCategory: String?
    
    init(group: MapPostGroup) {
        self.id = group.id
        self.longitude = Double(group.coordinate.longitude)
        self.latitude = Double(group.coordinate.latitude)
        self.spotName = group.spotName
        self.postIDs = group.postIDs.map { PostIDCache(postID: $0) }
        self.postsToSpot = group.postsToSpot
        self.postTimestamps = group.postTimestamps
        self.numberOfPosters = group.numberOfPosters
        self.poiCategory = group.poiCategory?.rawValue
        
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(longitude, forKey: "longitude")
        coder.encode(latitude, forKey: "latitude")
        coder.encode(spotName, forKey: "spotName")
        coder.encode(postIDs, forKey: "postIDs")
        coder.encode(postsToSpot, forKey: "postsToSpot")
        coder.encode(postTimestamps, forKey: "postTimestamps")
        coder.encode(numberOfPosters, forKey: "numberOfPosters")
        coder.encode(poiCategory, forKey: "poiCategory")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.longitude = coder.decodeDouble(forKey: "longitude")
        self.latitude = coder.decodeDouble(forKey: "latitude")
        self.spotName = coder.decodeObject(forKey: "spotName") as? String ?? ""
        self.postIDs = coder.decodeObject(forKey: "postIDs") as? [PostIDCache] ?? []
        self.postsToSpot = coder.decodeObject(forKey: "postsToSpot") as? [String] ?? []
        self.postTimestamps = coder.decodeObject(forKey: "postTimestamps") as? [Timestamp] ?? []
        self.numberOfPosters = coder.decodeInteger(forKey: "numberOfPosters")
        self.poiCategory = coder.decodeObject(forKey: "poiCategory") as? String
        
        super.init()
    }
}

extension MapPostGroupCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}

final class PostIDCache: NSObject, NSCoding {
    let id: String
    let timestamp: Timestamp
    let seen: Bool
    
    init(postID: MapPostGroup.PostID) {
        self.id = postID.id
        self.timestamp = postID.timestamp
        self.seen = postID.seen
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(seen, forKey: "seen")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.timestamp = coder.decodeObject(forKey: "timestamp") as? Timestamp ?? Timestamp(date: Date())
        self.seen = coder.decodeBool(forKey: "seen")
        super.init()
    }
}

extension PostIDCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}
