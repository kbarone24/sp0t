//
//  MapPostCache.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore

final class MapPostCache: NSObject, NSCoding {
    let id: String?
    let addedUsers: [String]?
    let aspectRatios: [Double]?
    let boostMultiplier: Double?
    let caption: String
    let city: String?
    let createdBy: String?
    let commentCount: Int?
    let frameIndexes: [Int]?
    let friendsList: [String]
    let g: String?
    let hiddenBy: [String]?
    let hideFromFeed: Bool?
    let imageLocations: [[String: Double]]?
    let imageURLs: [String]
    let videoURL: String?
    let inviteList: [String]?
    let likers: [String]
    let mapID: String?
    let mapName: String?
    let postLat: Double
    let postLong: Double
    let posterID: String
    let posterUsername: String?
    let privacyLevel: String?
    let seenList: [String]?
    let spotID: String?
    let spotLat: Double?
    let spotLong: Double?
    let spotName: String?
    let spotPOICategory: String?
    let spotPrivacy: String?
    let tag: String?
    let taggedUserIDs: [String]?
    let taggedUsers: [String]?
    let timestamp: Timestamp
    let addedUserProfiles: [UserProfileCache]?
    let userInfo: UserProfileCache?
    let mapInfo: CustomMapCache?
    let commentList: [MapCommentCache]
    let postImage: [UIImage]
    let postVideo: Data?
    let videoLocalPath: URL?
    let postScore: Double?
    let selectedImageIndex: Int?
    let imageHeight: Double?
    let cellHeight: Double?
    let commentsHeight: Double?
    let setImageLocation: Bool
    
    init(mapPost: MapPost) {
        self.id = mapPost.id
        self.addedUsers = mapPost.addedUsers
        self.aspectRatios = mapPost.aspectRatios?.map { Double($0) }
        self.boostMultiplier = mapPost.boostMultiplier
        self.caption = mapPost.caption
        self.city = mapPost.city
        self.createdBy = mapPost.createdBy
        self.commentCount = mapPost.commentCount
        self.frameIndexes = mapPost.frameIndexes
        self.friendsList = mapPost.friendsList
        self.g = mapPost.g
        self.hiddenBy = mapPost.hiddenBy
        self.hideFromFeed = mapPost.hideFromFeed
        self.imageLocations = mapPost.imageLocations
        self.imageURLs = mapPost.imageURLs
        self.videoURL = mapPost.videoURL
        self.inviteList = mapPost.inviteList
        self.likers = mapPost.likers
        self.mapID = mapPost.mapID
        self.mapName = mapPost.mapName
        self.postLat = mapPost.postLat
        self.postLong = mapPost.postLong
        self.posterID = mapPost.posterID
        self.posterUsername = mapPost.posterUsername
        self.privacyLevel = mapPost.privacyLevel
        self.seenList = mapPost.seenList
        self.spotID = mapPost.spotID
        self.spotLat = mapPost.spotLat
        self.spotLong = mapPost.spotLong
        self.spotName = mapPost.spotName
        self.spotPOICategory = mapPost.spotPOICategory
        self.spotPrivacy = mapPost.spotPrivacy
        self.tag = mapPost.tag
        self.taggedUserIDs = mapPost.taggedUserIDs
        self.taggedUsers = mapPost.taggedUsers
        self.timestamp = mapPost.timestamp
        self.addedUserProfiles = mapPost.addedUserProfiles?.map { UserProfileCache(userProfile: $0) }
        
        if let userInfo = mapPost.userInfo {
            self.userInfo = UserProfileCache(userProfile: userInfo)
        } else {
            self.userInfo = nil
        }
        
        if let mapInfo = mapPost.mapInfo {
            self.mapInfo = CustomMapCache(customMap: mapInfo)
        } else {
            self.mapInfo = nil
        }
        
        self.commentList = mapPost.commentList.map { MapCommentCache(mapComment: $0) }
        self.postImage = mapPost.postImage
        self.postVideo = mapPost.postVideo
        self.videoLocalPath = mapPost.videoLocalPath
        self.postScore = mapPost.postScore
        self.selectedImageIndex = mapPost.selectedImageIndex
        self.imageHeight = Double(mapPost.imageHeight ?? 0.0)
        self.cellHeight = Double(mapPost.cellHeight ?? 0.0)
        self.commentsHeight = Double(mapPost.commentsHeight ?? 0.0)
        self.setImageLocation = mapPost.setImageLocation
        
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(addedUsers, forKey: "addedUsers")
        coder.encode(aspectRatios, forKey: "aspectRatios")
        coder.encode(boostMultiplier, forKey: "boostMultiplier")
        coder.encode(caption, forKey: "caption")
        coder.encode(city, forKey: "city")
        coder.encode(createdBy, forKey: "createdBy")
        coder.encode(commentCount, forKey: "commentCount")
        coder.encode(frameIndexes, forKey: "frameIndexes")
        coder.encode(friendsList, forKey: "friendsList")
        coder.encode(g, forKey: "g")
        coder.encode(hiddenBy, forKey: "hiddenBy")
        coder.encode(hideFromFeed, forKey: "hideFromFeed")
        coder.encode(imageLocations, forKey: "imageLocations")
        coder.encode(imageURLs, forKey: "imageURLs")
        coder.encode(videoURL, forKey: "videoURL")
        coder.encode(inviteList, forKey: "inviteList")
        coder.encode(likers, forKey: "likers")
        coder.encode(mapID, forKey: "mapID")
        coder.encode(mapName, forKey: "mapName")
        coder.encode(postLat, forKey: "postLat")
        coder.encode(postLong, forKey: "postLong")
        coder.encode(posterID, forKey: "posterID")
        coder.encode(posterUsername, forKey: "posterUsername")
        coder.encode(privacyLevel, forKey: "privacyLevel")
        coder.encode(seenList, forKey: "seenList")
        coder.encode(spotID, forKey: "spotID")
        coder.encode(spotLat, forKey: "spotLat")
        coder.encode(spotLong, forKey: "spotLong")
        coder.encode(spotName, forKey: "spotName")
        coder.encode(spotPOICategory, forKey: "spotPOICategory")
        coder.encode(spotPrivacy, forKey: "spotPrivacy")
        coder.encode(tag, forKey: "tag")
        coder.encode(taggedUserIDs, forKey: "taggedUserIDs")
        coder.encode(taggedUsers, forKey: "taggedUsers")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(addedUserProfiles, forKey: "addedUserProfiles")
        coder.encode(userInfo, forKey: "userInfo")
        coder.encode(mapInfo, forKey: "mapInfo")
        coder.encode(commentList, forKey: "commentList")
        coder.encode(postImage, forKey: "postImage")
        coder.encode(postVideo, forKey: "postVideo")
        coder.encode(videoLocalPath, forKey: "videoLocalPath")
        coder.encode(postScore, forKey: "postScore")
        coder.encode(selectedImageIndex, forKey: "selectedImageIndex")
        coder.encode(imageHeight, forKey: "imageHeight")
        coder.encode(cellHeight, forKey: "cellHeight")
        coder.encode(commentsHeight, forKey: "commentsHeight")
        coder.encode(setImageLocation, forKey: "setImageLocation")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String
        self.addedUsers = coder.decodeObject(forKey: "addedUsers") as? [String]
        self.aspectRatios = coder.decodeObject(forKey: "aspectRatios") as? [Double]
        self.boostMultiplier = coder.decodeDouble(forKey: "boostMultiplier")
        self.caption = coder.decodeObject(forKey: "caption") as? String ?? ""
        self.city = coder.decodeObject(forKey: "city") as?  String
        self.createdBy = coder.decodeObject(forKey: "createdBy") as? String
        self.commentCount = coder.decodeObject(forKey: "commentCount") as? Int
        self.frameIndexes = coder.decodeObject(forKey: "frameIndexes") as? [Int]
        self.friendsList = coder.decodeObject(forKey: "friendsList") as? [String] ?? []
        self.g = coder.decodeObject(forKey: "g") as? String
        self.hiddenBy = coder.decodeObject(forKey: "hiddenBy") as? [String]
        self.hideFromFeed = coder.decodeBool(forKey: "hideFromFeed")
        self.imageLocations = coder.decodeObject(forKey: "imageLocations") as? [[String: Double]]
        self.imageURLs = coder.decodeObject(forKey: "imageURLs") as? [String] ?? []
        self.videoURL = coder.decodeObject(forKey: "videoURL") as? String
        self.inviteList = coder.decodeObject(forKey: "inviteList") as? [String]
        self.likers = coder.decodeObject(forKey: "likers") as? [String] ?? []
        self.mapID = coder.decodeObject(forKey: "mapID") as? String
        self.mapName = coder.decodeObject(forKey: "mapName") as?  String
        self.postLat = coder.decodeDouble(forKey: "postLat")
        self.postLong = coder.decodeDouble(forKey: "postLong")
        self.posterID = coder.decodeObject(forKey: "posterID") as? String ?? ""
        self.posterUsername = coder.decodeObject(forKey: "posterUsername") as?  String
        self.privacyLevel = coder.decodeObject(forKey: "privacyLevel") as?  String
        self.seenList = coder.decodeObject(forKey: "seenList") as? [String]
        self.spotID = coder.decodeObject(forKey: "spotID") as?  String
        self.spotLat = coder.decodeDouble(forKey: "spotLat")
        self.spotLong = coder.decodeDouble(forKey: "spotLong")
        self.spotName = coder.decodeObject(forKey: "spotName") as?  String
        self.spotPOICategory = coder.decodeObject(forKey: "spotPOICategory") as?  String
        self.spotPrivacy = coder.decodeObject(forKey: "spotPrivacy") as? String
        self.tag = coder.decodeObject(forKey: "tag") as? String
        self.taggedUserIDs = coder.decodeObject(forKey: "taggedUserIDs") as? [String]
        self.taggedUsers = coder.decodeObject(forKey: "taggedUsers") as? [String]
        self.timestamp = coder.decodeObject(forKey: "timestamp") as? Timestamp ?? Timestamp(date: Date())
        self.addedUserProfiles = coder.decodeObject(forKey: "addedUserProfiles") as? [UserProfileCache]
        self.userInfo = coder.decodeObject(forKey: "userInfo") as? UserProfileCache
        self.mapInfo = coder.decodeObject(forKey: "mapInfo") as?  CustomMapCache
        self.commentList = coder.decodeObject(forKey: "commentList") as? [MapCommentCache] ?? []
        self.postImage = coder.decodeObject(forKey: "postImage") as? [UIImage] ?? []
        self.postVideo = coder.decodeObject(forKey: "postVideo") as?  Data
        self.videoLocalPath = coder.decodeObject(forKey: "videoLocalPath") as?  URL
        self.postScore = coder.decodeDouble(forKey: "postScore")
        self.selectedImageIndex = coder.decodeInteger(forKey: "selectedImageIndex")
        self.imageHeight = coder.decodeDouble(forKey: "imageHeight")
        self.cellHeight = coder.decodeDouble(forKey: "cellHeight")
        self.commentsHeight = coder.decodeDouble(forKey: "commentsHeight")
        self.setImageLocation = coder.decodeBool(forKey: "setImageLocation")
        
        super.init()
    }
}

extension MapPostCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}
