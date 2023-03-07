//
//  CustomMapCache.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Firebase
import UIKit

final class CustomMapCache: NSObject, NSCoding {
    let id: String?
    let communityMap: Bool?
    let founderID: String
    let imageURL: String
    let videoURL: String
    var likers: [String]
    let lowercaseName: String?
    let mainCampusMap: Bool?
    let mapDescription: String?
    let mapName: String
    let memberIDs: [String]
    let posterDictionary: [String: [String]]
    let posterIDs: [String]
    let posterUsernames: [String]
    let postIDs: [String]
    let postImageURLs: [String]
    let postLocations: [[String: Double]]
    let postSpotIDs: [String]
    let postTimestamps: [Firebase.Timestamp]
    let searchKeywords: [String]?
    let secret: Bool
    let spotIDs: [String]
    let spotNames: [String]
    let spotLocations: [[String: Double]]
    let spotPOICategories: [String]
    let selected: Bool
    let memberProfiles: [UserProfileCache]?
    let coverImage: UIImage?
    let postsDictionary: [String: MapPostCache]
    let postGroup: [MapPostGroupCache]
    
    init(customMap: CustomMap) {
        self.id = customMap.id
        self.communityMap = customMap.communityMap
        self.founderID = customMap.founderID
        self.imageURL = customMap.imageURL
        self.videoURL = customMap.videoURL
        self.likers = customMap.likers
        self.lowercaseName = customMap.lowercaseName
        self.mainCampusMap = customMap.mainCampusMap
        self.mapDescription = customMap.mapDescription
        self.mapName = customMap.mapName
        self.memberIDs = customMap.memberIDs
        self.posterDictionary = customMap.posterDictionary
        self.posterIDs = customMap.postIDs
        self.posterUsernames = customMap.posterUsernames
        self.postIDs = customMap.postIDs
        self.postImageURLs = customMap.postImageURLs
        self.postLocations = customMap.postLocations
        self.postSpotIDs = customMap.postSpotIDs
        self.postTimestamps = customMap.postTimestamps
        self.searchKeywords = customMap.searchKeywords
        self.secret = customMap.secret
        self.spotIDs = customMap.spotIDs
        self.spotNames = customMap.spotNames
        self.spotLocations = customMap.spotLocations
        self.spotPOICategories = customMap.spotPOICategories
        self.selected = customMap.selected
        self.memberProfiles = customMap.memberProfiles?.map { UserProfileCache(userProfile: $0) }
        self.coverImage = customMap.coverImage
        self.postsDictionary = customMap.postsDictionary.mapValues{ MapPostCache(mapPost: $0) }
        self.postGroup = customMap.postGroup.map { MapPostGroupCache(group: $0) }
        
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(communityMap, forKey: "communityMap")
        coder.encode(founderID, forKey: "founderID")
        coder.encode(imageURL, forKey: "imageURL")
        coder.encode(videoURL, forKey: "videoURL")
        coder.encode(likers, forKey: "likers")
        coder.encode(lowercaseName, forKey: "lowercaseName")
        coder.encode(mainCampusMap, forKey: "mainCampusMap")
        coder.encode(mapDescription, forKey: "mapDescription")
        coder.encode(mapName, forKey: "mapName")
        coder.encode(memberIDs, forKey: "memberIDs")
        coder.encode(posterDictionary, forKey: "posterDictionary")
        coder.encode(posterIDs, forKey: "posterIDs")
        coder.encode(posterUsernames, forKey: "posterUsernames")
        coder.encode(postIDs, forKey: "postIDs")
        coder.encode(postImageURLs, forKey: "postImageURLs")
        coder.encode(postLocations, forKey: "postLocations")
        coder.encode(postSpotIDs, forKey: "postSpotIDs")
        coder.encode(postTimestamps, forKey: "postTimestamps")
        coder.encode(searchKeywords, forKey: "searchKeywords")
        coder.encode(secret, forKey: "secret")
        coder.encode(spotIDs, forKey: "spotIDs")
        coder.encode(spotNames, forKey: "spotNames")
        coder.encode(spotLocations, forKey: "spotLocations")
        coder.encode(spotPOICategories, forKey: "spotPOICategories")
        coder.encode(selected, forKey: "selected")
        coder.encode(memberProfiles, forKey: "memberProfiles")
        coder.encode(coverImage, forKey: "coverImage")
        coder.encode(postsDictionary, forKey: "postsDictionary")
        coder.encode(postGroup, forKey: "postGroup")
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String
        self.communityMap = coder.decodeBool(forKey: "communityMap")
        self.founderID = coder.decodeObject(forKey: "founderID") as? String ?? ""
        self.imageURL = coder.decodeObject(forKey: "imageURL") as? String ?? ""
        self.videoURL = coder.decodeObject(forKey: "videoURL") as? String ?? ""
        self.likers = coder.decodeObject(forKey: "likers") as? [String] ?? []
        self.lowercaseName = coder.decodeObject(forKey: "lowercaseName") as? String? ?? ""
        self.mainCampusMap = coder.decodeBool(forKey: "mainCampusMap")
        self.mapDescription = coder.decodeObject(forKey: "mapDescription") as? String? ?? ""
        self.mapName = coder.decodeObject(forKey: "mapName") as? String ?? ""
        self.memberIDs = coder.decodeObject(forKey: "memberIDs") as? [String] ?? []
        self.posterDictionary = coder.decodeObject(forKey: "posterDictionary") as? [String: [String]] ?? [:]
        self.posterIDs = coder.decodeObject(forKey: "posterIDs") as? [String] ?? []
        self.posterUsernames = coder.decodeObject(forKey: "posterUsernames") as? [String] ?? []
        self.postIDs = coder.decodeObject(forKey: "postIDs") as? [String] ?? []
        self.postImageURLs = coder.decodeObject(forKey: "postImageURLs") as? [String] ?? []
        self.postLocations = coder.decodeObject(forKey: "postLocations") as? [[String: Double]] ?? []
        self.postSpotIDs = coder.decodeObject(forKey: "postSpotIDs") as? [String] ?? []
        self.postTimestamps = coder.decodeObject(forKey: "postTimestamps") as? [Firebase.Timestamp] ?? []
        self.searchKeywords = coder.decodeObject(forKey: "searchKeywords") as? [String]
        self.secret = coder.decodeBool(forKey: "secret")
        self.spotIDs = coder.decodeObject(forKey: "spotIDs") as? [String] ?? []
        self.spotNames = coder.decodeObject(forKey: "spotNames") as? [String] ?? []
        self.spotLocations = coder.decodeObject(forKey: "spotLocations") as? [[String: Double]] ?? []
        self.spotPOICategories = coder.decodeObject(forKey: "spotPOICategories") as? [String] ?? []
        self.selected = coder.decodeBool(forKey: "selected")
        self.memberProfiles = coder.decodeObject(forKey: "memberProfiles") as? [UserProfileCache]
        self.coverImage = coder.decodeObject(forKey: "coverImage") as? UIImage? ?? UIImage()
        self.postsDictionary = coder.decodeObject(forKey: "postsDictionary") as? [String: MapPostCache] ?? [:]
        self.postGroup = coder.decodeObject(forKey: "postGroup") as? [MapPostGroupCache] ?? []
        
        super.init()
    }
}

extension CustomMapCache: NSCopying {
    func copy(with zone: NSZone? = nil) -> Any {
        super.copy()
    }
}
