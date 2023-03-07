//
//  MapCommentCache.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Firebase

final class MapCommentCache: NSObject, NSCoding {
    
    let id: String
    let comment: String
    let commenterID: String
    let taggedUsers: [String]
    let timestamp: Firebase.Timestamp?
    let likers: [String]
    let userInfo: UserProfileCache?
    let feedHeight: Double
    
    init(mapComment: MapComment) {
        self.id = mapComment.id ?? ""
        self.comment = mapComment.comment
        self.commenterID = mapComment.commenterID
        self.taggedUsers = mapComment.taggedUsers ?? []
        self.timestamp = mapComment.timestamp
        self.likers = mapComment.likers ?? []
        
        if let userInfo = mapComment.userInfo {
            self.userInfo = UserProfileCache(userProfile: userInfo)
        } else {
            self.userInfo = nil
        }
        self.feedHeight = Double(mapComment.feedHeight)
        
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(comment, forKey: "comment")
        coder.encode(commenterID, forKey: "commenterID")
        coder.encode(taggedUsers, forKey: "taggedUsers")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(likers, forKey: "likers")
        coder.encode(userInfo, forKey: "userInfo")
        coder.encode(feedHeight, forKey: "feedHeight")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.comment = coder.decodeObject(forKey: "comment") as? String ?? ""
        self.commenterID = coder.decodeObject(forKey: "commenterID") as? String ?? ""
        self.taggedUsers = coder.decodeObject(forKey: "taggedUsers") as? [String] ?? []
        self.timestamp = coder.decodeObject(forKey: "timestamp") as? Firebase.Timestamp
        self.likers = coder.decodeObject(forKey: "likers") as? [String] ?? []
        self.userInfo = coder.decodeObject(forKey: "userInfo") as? UserProfileCache
        self.feedHeight = coder.decodeDouble(forKey: "feedHeight")
        
        super.init()
    }
}

extension MapCommentCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}