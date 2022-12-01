//
//  MapPostGroupExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

extension MapController {
    func updateFriendsPostGroup(post: MapPost?, spot: MapSpot?) -> (group: MapPostGroup?, newGroup: Bool) {
        if let post {
            if post.spotID ?? "" == "" {
                /// attach by postID
                let coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
                let newGroup = MapPostGroup(
                    id: post.id ?? "",
                    coordinate: coordinate,
                    spotName: "",
                    postIDs: [MapPostGroup.PostID(id: post.id ?? "", timestamp: post.timestamp, seen: post.seen)])
                postGroup.append(newGroup)
                return (newGroup, true)

            } else if !postGroup.contains(where: { $0.id == post.spotID ?? "" }) {
                let coordinate = CLLocationCoordinate2D(latitude: post.spotLat ?? 0, longitude: post.spotLong ?? 0)
                var newGroup = MapPostGroup(
                    id: post.spotID ?? "",
                    coordinate: coordinate,
                    spotName: post.spotName ?? "",
                    postIDs: [MapPostGroup.PostID(id: post.id ?? "", timestamp: post.timestamp, seen: post.seen)])
                postGroup.append(newGroup)
                return (newGroup, true)

            } else if let i = postGroup.firstIndex(where: { $0.id == post.spotID }) {
                if !postGroup[i].postIDs.contains(where: { $0.id == post.id }) {
                    postGroup[i].postIDs.append(MapPostGroup.PostID(id: post.id ?? "", timestamp: post.timestamp, seen: post.seen))
                    postGroup[i].sortPostIDs()
                    return (postGroup[i], false)
                }
            }
        } else if let spot, !postGroup.contains(where: { $0.id == spot.id }) {
            let coordinate = CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong)
            // add spot group with no postIDs -> include extra values for setting display priority
            var newGroup = MapPostGroup(
                id: spot.id ?? "",
                coordinate: coordinate,
                spotName: spot.spotName,
                postIDs: [],
                postsToSpot: spot.postIDs,
                postTimestamps: spot.postTimestamps,
                numberOfPosters: spot.posterIDs.uniqued().count
            )
            if let category = spot.poiCategory, let poiCategory = POICategory(rawValue: category) {
                newGroup.poiCategory = poiCategory
            }
            postGroup.append(newGroup)
            return (newGroup, true)
        }
        return (nil, false)
    }

    func updateFriendsPostGroupSeen(postID: String) {
        if let i = postGroup.firstIndex(where: { $0.postIDs.contains(where: { $0.id == postID }) }) {
            if let j = postGroup[i].postIDs.firstIndex(where: { $0.id == postID }) {
                postGroup[i].postIDs[j].seen = true
                postGroup[i].sortPostIDs()
            }
        }
    }

    func removeFromFriendsPostGroup(postID: String, spotID: String) {
        /// remove id from post group
        if let i = postGroup.firstIndex(where: { $0.postIDs.contains(where: { $0.id == postID }) }) {
            if let j = postGroup[i].postIDs.firstIndex(where: { $0.id == postID }) {
                postGroup[i].postIDs.remove(at: j)
                /// remove from post group entirely if no spot attached
                if postGroup[i].postIDs.isEmpty && postGroup[i].spotName == "" { postGroup.remove(at: i) }
            }
        }

        if spotID != "" { postGroup.removeAll(where: { $0.id == spotID }) }
    }
}
