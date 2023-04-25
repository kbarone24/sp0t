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

struct MapSpot: Identifiable, Codable, Hashable {

    @DocumentID var id: String?

    var city: String? = ""
    var founderID: String
    var imageURL: String
    var inviteList: [String]? = []
    var lowercaseName: String?
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

    // supplemental values
    var checkInTime: Int64?
    var distance: CLLocationDistance = CLLocationDistance()
    var friendVisitors = 0
    var selected: Bool? = false
    var spotImage: UIImage = UIImage()
    var spotScore: Double = 0

    var location: CLLocation {
        return CLLocation(latitude: spotLat, longitude: spotLong)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case city
        case founderID = "createdBy"
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
        case spotDescription = "description"
        case spotLat
        case spotLong
        case spotName
        case tagDictionary
        case visitorList
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
        self.spotLat = post.postLat
        self.spotLong = post.postLong
    }

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
    }

    /// used for nearby spots in choose spot sections on Upload and LocationPicker. Similar logic as get post score
    func getSpotRank(location: CLLocation) -> Double {
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
    }

    func isFriends(id: String) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if id == uid || (UserDataModel.shared.userInfo.friendIDs.contains(where: { $0 == id }) && !(UserDataModel.shared.adminIDs.contains(id))) { return true }
        return false
    }

    func showSpotOnMap() -> Bool {
        // if its a public spot, return true
        if privacyLevel == "public" || poiCategory ?? "" != "" {
            return true
        }

        // if its a user-created spot and friends have posted to it, return true
        if privacyLevel == "friends" && UserDataModel.shared.userInfo.friendIDs.contains(founderID) || founderID == UserDataModel.shared.uid {
            return true
        }

        // if its a user-created spot and user has map access to post, return true
        for i in 0..<postIDs.count {
            // public map post to this spot that user is a part of
            if UserDataModel.shared.userInfo.mapsList.contains(where: { $0.id == postMapIDs?[safe: i] }) {
                return true
            }
            // friend has posted here
            if postPrivacies[safe: i] != "invite" &&
                (UserDataModel.shared.userInfo.friendIDs.contains(posterIDs[safe: i] ?? "") || posterIDs[safe: i] == UserDataModel.shared.uid) {
                return true
            }
        }
        return false
    }
}
