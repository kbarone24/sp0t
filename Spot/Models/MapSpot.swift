//
//  MapSpot.swift
//  Spot
//
//  Created by kbarone on 6/23/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseFirestore
import MapKit
import UIKit
import GeoFireUtils

struct MapSpot: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    var city: String? = ""
    var founderID: String
    var imageURL: String
    var inviteList: [String]? = []
    var lowercaseName: String?
    var g: String?
    var phone: String? = ""
    var poiCategory: String? ///  poi category is a nil value to check on uploadPost for spot v poi
    var postIDs: [String] = []
    var postMapIDs: [String]? = []
    var postPrivacies: [String] = []
    var postTimestamps: [Timestamp] = []
    var posterDictionary: [String: [String]] = [:]
    var posterIDs: [String] = []
    var posterUsername: String? = ""
    var privacyLevel: String
    var searchKeywords: [String]?
    var spotDescription: String
    var spotLat: Double
    var spotLong: Double
    var spotName: String
    var tagDictionary: [String: Int] = [:]
    var visitorList: [String] = []

    // added values for 2.0
    var hereNow: [String]? = []
    var lastPostTimestamp: Timestamp?
    var postCaptions: [String]? = []
    var postImageURLs: [String]? = []
    var postVideoURLs: [String]? = []
    var postCommentCounts: [Int]? = []
    var postLikeCounts: [Int]? = []
    var postDislikeCounts: [Int]? = []
    var postSeenCounts: [Int]? = []
    var postUsernames: [String]? = []
    var seenList: [String]? = []

    // supplemental values
    var checkInTime: Int64?
    var selected: Bool? = false
    var spotImage: UIImage = UIImage()
    var createdFromPOI = false
    var distance: CLLocationDistance = CLLocationDistance() {
        didSet {
            setSpotScore()
        }
    }
    // spotscore factors in distance to the user
    var spotScore: Double = 0
    // spot rank is a raw popularity score
    var spotRank: Double = 0

    var friendVisitors: [String] {
        return UserDataModel.shared.userInfo.friendIDs.filter({ visitorList.contains($0) })
    }

    var friendsHereNow: [String] {
        return UserDataModel.shared.userInfo.friendIDs.filter({ hereNow?.contains($0) ?? false })
    }

    var location: CLLocation {
        return CLLocation(latitude: spotLat, longitude: spotLong)
    }

    var seen: Bool {
        let oneWeek = Date().timeIntervalSince1970 - 86_400 * 7
        return (seenList?.contains(UserDataModel.shared.uid) ?? true) || lastPostTimestamp?.seconds ?? Int64.max < Int64(oneWeek)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case city
        case founderID = "createdBy"
        case g
        case imageURL
        case inviteList
        case lowercaseName
        case phone
        case poiCategory
        case postIDs
        case postMapIDs
        case postPrivacies
        case postTimestamps
        case posterDictionary
        case posterIDs
        case posterUsername
        case privacyLevel
        case searchKeywords
        case seenList
        case spotDescription = "description"
        case spotLat
        case spotLong
        case spotName
        case visitorList

        case hereNow
        case lastPostTimestamp
        case postCaptions
        case postImageURLs
        case postVideoURLs
        case postCommentCounts
        case postLikeCounts
        case postDislikeCounts
        case postSeenCounts
        case postUsernames
    }

    init(post: MapPost?, postDraft: PostDraft, imageURL: String) {
        self.founderID = postDraft.createdBy ?? ""
        self.imageURL = imageURL
        self.privacyLevel = postDraft.spotPrivacy ?? ""
        self.spotDescription = postDraft.caption ?? ""
        self.spotLat = postDraft.spotLat
        self.spotLong = postDraft.spotLong
        self.spotName = postDraft.spotName
        self.visitorList = postDraft.visitorList ?? []
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.id = post?.spotID ?? ""
        self.poiCategory = postDraft.poiCategory
        self.phone = postDraft.phone
    }

    init(id: String, spotName: String) {
        self.id = id
        self.spotName = spotName
        self.founderID = ""
        self.imageURL = ""
        self.privacyLevel = ""
        self.spotDescription = ""
        self.spotLat = 0
        self.spotLong = 0
    }

    init(
        id: String,
        founderID: String,
        post: MapPost,
        imageURL: String,
        spotName: String,
        privacyLevel: String,
        description: String
    ) {
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.id = id
        self.founderID = founderID
        self.imageURL = imageURL
        self.privacyLevel = privacyLevel
        self.spotName = spotName
        self.spotDescription = description
        self.spotLat = post.postLat ?? 0
        self.spotLong = post.postLong ?? 0
    }

    // MARK: init from poi
    init(
        id: String,
        founderID: String,
        mapItem: MKMapItem,
        imageURL: String,
        spotName: String,
        privacyLevel: String
    ) {
        self.posterUsername = UserDataModel.shared.userInfo.username
        self.id = id
        self.founderID = founderID
        self.imageURL = imageURL
        self.privacyLevel = privacyLevel
        self.spotName = spotName
        self.spotDescription = mapItem.pointOfInterestCategory?.toString() ?? ""
        self.spotLat = mapItem.placemark.coordinate.latitude
        self.spotLong = mapItem.placemark.coordinate.longitude
        self.poiCategory = mapItem.pointOfInterestCategory?.toString() ?? ""
        self.phone = mapItem.phoneNumber ?? ""
        self.createdFromPOI = true
        self.hereNow = []
    }

    /// used for nearby spots in choose spot sections on Upload and LocationPicker. Similar logic as get post score
    func getSpotRank(location: CLLocation) -> Double {
        return 0
        /*
        var scoreMultiplier = postIDs.isEmpty ? 10.0 : 50.0 /// 5x boost to any spot that has posts at it
        let distance = max(CLLocation(latitude: spotLat, longitude: spotLong).distance(from: location), 1)

        for i in 0..<postIDs.count {
            var postScore: Double = 10

            /// increment for each friend post
            if posterIDs.count <= i { continue }
            if isFriends(id: posterIDs[safe: i] ?? "") { postScore += 5 }
            let timestamp = postTimestamps[safe: i] ?? Timestamp()
            let postTime = Double(timestamp.seconds)

            let current = Date().timeIntervalSince1970
            let currentTime = Double(current)
            let timeSincePost = currentTime - postTime

            /// add multiplier for recent posts
            var factor = min(1 + (1_000_000 / timeSincePost), 5)
            let multiplier = pow(1.2, factor)
            factor = multiplier

            postScore *= factor
            scoreMultiplier += postScore
        }
        let finalScore = scoreMultiplier / pow(distance, 1.7)
        return finalScore
        */
    }

    mutating func setSpotScore() {
        // spot score for home screen nearby spots
        var scoreMultiplier: Double = postIDs.isEmpty ? 10.0 : 50.0
        for i in 0..<(min(30, postIDs.count)) {
            var post = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            guard let timestamp = postTimestamps[safe: i] else { continue }
            post.timestamp = timestamp

            let baseScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, dislikeCount: postDislikeCounts?[safe: i] ?? 0, seenCount: 0, commentCount: postCommentCounts?[safe: i] ?? 0)
            scoreMultiplier += baseScore
        }

        spotScore = scoreMultiplier / pow(distance, 1.7)
    }

    mutating func setSpotRank() {
        // spot rank for home screen top spots
        var rank: Double = 0
        for i in 0..<(min(20, postIDs.count)) {
            var post = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            guard let timestamp = postTimestamps[safe: i] else { continue }
            post.timestamp = timestamp

            let baseScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, dislikeCount: postDislikeCounts?[safe: i] ?? 0, seenCount: 0, commentCount: postCommentCounts?[safe: i] ?? 0)
            rank += baseScore
        }

        rank *= 1 + Double(visitorList.count) / 100
        rank *= 1 + Double(hereNow?.count ?? 0) / 5

        spotRank = rank
    }

    func userInRange() -> Bool {
        return ServiceContainer.shared.locationService?.currentLocation?.distance(from: location) ?? 1000 < 250
    }

    func getLastAccessPostIndex() -> Int {
        guard !postPrivacies.isEmpty else { return -1 }
        let reversedPostPrivacies = Array(postPrivacies.reversed())
        var i = reversedPostPrivacies.count - 1
        while i > 0 {
            let posterID = posterIDs[safe: i] ?? ""
            if reversedPostPrivacies[i] == "public" {
                return i
            } else if reversedPostPrivacies[i] == "friends" && UserDataModel.shared.userInfo.friendIDs.contains(posterID)
                        || posterID == UserDataModel.shared.uid {
                return i
            }
            i -= 1
        }
        return -1
    }

    func showSpotOnMap() -> Bool {
        // if its a public spot, return true
        if privacyLevel == "public" || poiCategory ?? "" != "" {
            return true
        }

        return getLastAccessPostIndex() > -1
    }

    mutating func setUploadValuesFor(post: MapPost) {
        let lowercaseName = spotName.lowercased()
        let keywords = lowercaseName.getKeywordArray()
        let geoHash = GFUtils.geoHash(forLocation: location.coordinate)

        var posterDictionary: [String: [String]] = [:]
        posterDictionary[post.id ?? ""] = [UserDataModel.shared.uid]

        self.lowercaseName = lowercaseName
        founderID = UserDataModel.shared.uid
        posterUsername = UserDataModel.shared.userInfo.username
        visitorList = [UserDataModel.shared.uid]
        g = geoHash
        imageURL = post.imageURLs.first ?? ""
        searchKeywords = keywords
        postIDs = [post.id ?? ""]
        postMapIDs = [post.mapID ?? ""]
        postTimestamps = [post.timestamp]
        posterIDs = [UserDataModel.shared.uid]
        postPrivacies = [post.privacyLevel ?? ""]
        self.posterDictionary = posterDictionary

        lastPostTimestamp = post.timestamp
        postCaptions = [post.caption]
        postImageURLs = [post.imageURLs.first ?? ""]
        postVideoURLs = [post.videoURL ?? ""]
        postCommentCounts = [0]
        postDislikeCounts = [0]
        postLikeCounts = [0]
        postUsernames = [UserDataModel.shared.userInfo.username]
    }
}
