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

struct MapSpot: Identifiable, Codable {

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
    var spotLat: Double
    var spotLong: Double
    var spotName: String
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
    var postUsernames: [String]? = []
    var seenList: [String]? = []

    // supplemental values
    var isTopSpot = false
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
        case postMapIDs
        case posterDictionary
        case posterUsername
        case privacyLevel
        case searchKeywords
        case seenList
        case spotLat
        case spotLong
        case spotName
        case visitorList
        case hereNow
        case lastPostTimestamp

        case postIDs
        case posterIDs
        case postPrivacies
        case postTimestamps
        case postCaptions
        case postImageURLs
        case postVideoURLs
        case postCommentCounts
        case postLikeCounts
        case postDislikeCounts
        case postUsernames
    }

    init(id: String, spotName: String) {
        self.id = id
        self.spotName = spotName
        self.founderID = ""
        self.imageURL = ""
        self.privacyLevel = ""
        self.spotLat = 0
        self.spotLong = 0
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
        self.spotLat = mapItem.placemark.coordinate.latitude
        self.spotLong = mapItem.placemark.coordinate.longitude
        self.poiCategory = mapItem.pointOfInterestCategory?.toString() ?? ""
        self.phone = mapItem.phoneNumber ?? ""
        self.createdFromPOI = true
        self.hereNow = []
    }

    // init from current user create
    init(city: String, spotName: String, spotLat: Double, spotLong: Double) {
        self.city = city
        self.spotName = spotName
        self.spotLat = spotLat
        self.spotLong = spotLong

        let lowercaseName = spotName.lowercased()
        let keywords = lowercaseName.getKeywordArray()
        let geoHash = GFUtils.geoHash(forLocation: CLLocationCoordinate2D(latitude: spotLat, longitude: spotLong))

        self.founderID = UserDataModel.shared.uid
        self.imageURL = ""
        self.lowercaseName = lowercaseName
        self.g = geoHash
        self.phone = ""
        self.poiCategory = ""
        self.privacyLevel = "public"
        self.searchKeywords = keywords
        self.lastPostTimestamp = Timestamp()

        self.id = UUID().uuidString
    }

    mutating func setSpotScore() {
        // spot score for home screen nearby spots
        var scoreMultiplier: Double = postIDs.isEmpty ? 10.0 : 50.0
        for i in 0..<(min(30, postIDs.count)) {
            var post = MapPost(spotID: "", spotName: "", mapID: "", mapName: "")
            guard let timestamp = postTimestamps[safe: i] else { continue }
            post.timestamp = timestamp

            let baseScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, dislikeCount: postDislikeCounts?[safe: i] ?? 0, seenCount: 0, commentCount: postCommentCounts?[safe: i] ?? 0, feedMode: false)
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

            let baseScore = post.getBasePostScore(likeCount: postLikeCounts?[safe: i] ?? 0, dislikeCount: postDislikeCounts?[safe: i] ?? 0, seenCount: 0, commentCount: postCommentCounts?[safe: i] ?? 0, feedMode: false)
            rank += baseScore
        }

        rank *= 1 + Double(visitorList.count) / 100
        rank *= Double((hereNow?.count ?? 0) + 1)

        spotRank = rank
    }

    func userInRange() -> Bool {
        if AdminsAndBurners().containsUserPhoneNumber() {
            return true
        }

        guard !UserDataModel.shared.userInfo.flagged else {
            return false
        }

        return ServiceContainer.shared.locationService?.currentLocation?.distance(from: location) ?? 1000 < 250
    }

    func getLastAccessPostIndex() -> Int {
        guard !postPrivacies.isEmpty else { return -1 }
        var i = postPrivacies.count - 1
        while i >= 0 {
            if hasPostAccess(posterID: posterIDs[safe: i] ?? "", postPrivacy: postPrivacies[i]) {
                return i
            }
            i -= 1
        }
        return -1
    }

    func getLastAccessImageIndex() -> Int {
        guard !postPrivacies.isEmpty else { return -1 }
        var i = postPrivacies.count - 1
        while i >= 0 {
            if let imageURL = postImageURLs?[safe: i], imageURL != "" {
                if hasPostAccess(posterID: posterIDs[safe: i] ?? "", postPrivacy: postPrivacies[i]) {
                    return i
                }
            }
            i -= 1
        }
        return -1
    }

    private func hasPostAccess(posterID: String, postPrivacy: String) -> Bool {
        if postPrivacy == "public" {
            return true
        } else if (postPrivacy == "friends" && (UserDataModel.shared.userInfo.friendIDs.contains(posterID)
                    || posterID == UserDataModel.shared.uid)) {
            return true
        }
        return false
    }

    func showSpotOnHome() -> Bool {
        // if its a public spot, return true
        return privacyLevel == "public"
        /*
        if privacyLevel == "friends" {
            return (UserDataModel.shared.userInfo.friendIDs.contains(founderID) || UserDataModel.shared.uid == founderID) && getLastAccessPostIndex() > -1
        }
        */
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

extension MapSpot: Hashable {
    static func == (lhs: MapSpot, rhs: MapSpot) -> Bool {
        return lhs.id == rhs.id &&
        lhs.postIDs == rhs.postIDs &&
        lhs.visitorList == rhs.visitorList &&
        lhs.hereNow == rhs.hereNow &&
        lhs.isTopSpot == rhs.isTopSpot &&
        lhs.seenList == rhs.seenList
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(postIDs)
        hasher.combine(visitorList)
        hasher.combine(hereNow)
        hasher.combine(isTopSpot)
        hasher.combine(seenList)
    }
}
