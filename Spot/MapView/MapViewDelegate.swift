//
//  MapViewDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 8/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import MapKit
import Mixpanel
import UIKit

// functions for loading nearby spots in nearby view
extension MapController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mapView = mapView as? SpotMapView else { return MKAnnotationView() }
        var selectedMap = getSelectedMap()
        if selectedMap == nil { selectedMap = getFriendsMapObject() }

        if let anno = annotation as? SpotAnnotation {
            // set up spot post view with 1 post
            return mapView.getSpotAnnotation(anno: anno, selectedMap: selectedMap)

        } else if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.contains(where: { $0 is SpotAnnotation }) {
                return mapView.getSpotClusterAnnotation(anno: anno, selectedMap: selectedMap)
            }
        }
        return MKAnnotationView()
    }

    func centerMapOnMapPosts(animated: Bool) {
        /// zoom out map to show all annotations in view
        let map = getSelectedMap()
        var coordinates = getSortedCoordinates()
        /// add fist 10 post coordiates to set location for map with no new posts
        if coordinates.isEmpty && map != nil {
            for location in map?.postLocations.prefix(10) ?? [] { coordinates.append(CLLocationCoordinate2D(latitude: location["lat"] ?? 0.0, longitude: location["long"] ?? 0.0)) }
        }

        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapView.setRegion(region, animated: animated)
    }

    func isSelectedMap(mapID: String) -> Bool {
        if mapID == "" { return selectedItemIndex == 0 }
        return mapID == UserDataModel.shared.userInfo.mapsList[selectedItemIndex - 1].id ?? ""
    }

    func getSelectedMap() -> CustomMap? {
        return selectedItemIndex == 0 ? nil : UserDataModel.shared.userInfo.mapsList[safe: selectedItemIndex - 1]
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        /// remove clustering if zoomed in to ground level
        guard let mapView = mapView as? SpotMapView else { return }
        if mapView.lockClusterOnUpload { return }

        if mapView.region.span.longitudeDelta < 0.001_4 {
            if mapView.shouldCluster {
                mapView.shouldCluster = false
                let annotations = mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    self.mapView.addAnnotations(annotations)
                }
            }
        } else {
            if !mapView.shouldCluster {
                mapView.shouldCluster = true
                let annotations = mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    self.mapView.addAnnotations(annotations)
                }
            }
            /// see if should add/remove spot annos
            if mapView.region.span.longitudeDelta < 0.2 {
                if !mapView.shouldShowSpots {
                    mapView.shouldShowSpots = true
                  //  mapView.addSpotAnnotationsOnZoom(map: getSelectedMap())
                }
            } else {
                if mapView.shouldShowSpots {
                    mapView.shouldShowSpots = false
                 //   mapView.removeSpotAnnotationsOnZoom(map: getSelectedMap())
                }
            }
        }
    }

    func animateToMostRecentPost() {
        let map = getSelectedMap() ?? getFriendsMapObject()
        let group = map.postGroup
        let coordinate = mapView.sortPostGroup(group).first?.coordinate
        animateTo(coordinate: coordinate)
    }

    func animateTo(coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            DispatchQueue.main.async { self.mapView.setRegion(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.001_39, longitudeDelta: 0.001_39)), animated: true) }
        }
    }

    func offsetCustomMapCenter() {
        DispatchQueue.main.async { self.centerMapOnMapPosts(animated: false) }
    }

    func getSortedCoordinates() -> [CLLocationCoordinate2D] {
        let map = getSelectedMap()
        /// filter for spots without posts
        let group = map == nil ? postGroup.filter({ !$0.postIDs.isEmpty }) : map?.postGroup.filter({ !$0.postIDs.isEmpty })
        guard var group else { return [] }

        if group.contains(where: { $0.postIDs.contains(where: { !$0.seen }) }) { group = group.filter({ $0.postIDs.contains(where: { !$0.seen }) })}
        group = mapView.sortPostGroup(group)
        return group.map({ $0.coordinate })
    }
}

extension MapController: SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        let map = getSelectedMap() ?? getFriendsMapObject()
        var posts: [MapPost] = []
        /// patch fix for double post getting added
        for id in view.postIDs {
            guard let post = map.postsDictionary[id] else { continue }
            if !posts.contains(where: { $0.id ?? "" == post.id ?? "" }) { posts.append(post) }
        }
        DispatchQueue.main.async { self.openPost(posts: posts) }
    }

    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        let map = getSelectedMap()
        openSpot(spotID: view.id, spotName: view.spotName, mapID: map?.id ?? "", mapName: map?.mapName ?? "")
    }

    func openSpotFromSpotName(view: SpotNameAnnotationView) {
        let map = getSelectedMap()
        openSpot(spotID: view.id, spotName: view.spotName, mapID: map?.id ?? "", mapName: map?.mapName ?? "")
    }

    func centerMapOnPostsInCluster(view: SpotPostAnnotationView) {
        let map = getSelectedMap() ?? getFriendsMapObject()
        var coordinates: [CLLocationCoordinate2D] = []

        for id in view.postIDs {
            if let post = map.postsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false)
        DispatchQueue.main.async { self.mapView.setRegion(region, animated: true) }
    }
}

protocol SpotMapViewDelegate: AnyObject {
    func openPostFromSpotPost(view: SpotPostAnnotationView)
    func openSpotFromSpotPost(view: SpotPostAnnotationView)
    func openSpotFromSpotName(view: SpotNameAnnotationView)
    func centerMapOnPostsInCluster(view: SpotPostAnnotationView)
}

class SpotMapView: MKMapView {
    var shouldCluster = false
    var shouldShowSpots = false
    var lockClusterOnUpload = false
    var spotMapDelegate: SpotMapViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        mapType = .mutedStandard
        overrideUserInterfaceStyle = .light
        pointOfInterestFilter = .excludingAll
        showsCompass = false
        showsTraffic = false
        showsUserLocation = false
        tag = 13
        register(SpotNameAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotName")
        register(SpotPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotPost")
        register(SpotPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotPostCluster")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setOffsetRegion(region: MKCoordinateRegion, offset: CGFloat, animated: Bool) {
        let originalCoordinate = region.center
        var point = convert(originalCoordinate, toPointTo: self)
        point.y -= offset
     //   print("point 2", point)

        let coordinate = convert(point, toCoordinateFrom: self)
     //   let offsetLocation = coordinate.location
     //   let distance = originalCoordinate.location.distance(from: offsetLocation) / 1000.0
      //  let adjustedCenter = originalCoordinate.adjust(by: distance, at: camera.heading - 180.0)

        let adjustedRegion = MKCoordinateRegion(center: coordinate, span: region.span)
        setRegion(adjustedRegion, animated: animated)
    }

    func addPostAnnotation(group: MapPostGroup?, newGroup: Bool, map: CustomMap) {
        if let group {
            if newGroup {
                /// add new group
                print("add new group")
                addSpotAnnotation(group: group, map: map)
            } else {
                /// update existing group
                if let anno = annotations.first(where: { $0.coordinate.isEqualTo(coordinate: group.coordinate) }) {
                    removeAnnotation(anno)
                    print("update existing group")
                    addSpotAnnotation(group: group, map: map)
                }
            }
        }
    }

    func addSpotAnnotation(group: MapPostGroup, map: CustomMap) {
        let spotAnnotation = SpotAnnotation()
        spotAnnotation.id = group.id
        spotAnnotation.type = group.postIDs.isEmpty ? .name : .post

        if group.spotName == "", let post = map.postsDictionary[group.id] {
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
        } else {
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: group.coordinate.latitude, longitude: group.coordinate.longitude)
        }
        print("add spot annotation", group.postIDs.map({ $0.id }))
        DispatchQueue.main.async { self.addAnnotation(spotAnnotation) }
    }

    func removeAllAnnos() {
        removeAnnotations(annotations)
    }

    func removeSpotAnnotationsOnZoom(map: CustomMap?) {
        if map == nil { return }
        var annotations = annotations.filter({ $0 is SpotAnnotation }) as? [SpotAnnotation] ?? []
        annotations = annotations.filter({ $0.type == .name })
        DispatchQueue.main.async { self.removeAnnotations(annotations) }
    }

    func addSpotAnnotationsOnZoom(map: CustomMap?) {
        if let map {
            for group in map.postGroup.filter({ $0.postIDs.isEmpty }) {
                DispatchQueue.main.async { self.addSpotAnnotation(group: group, map: map) }
            }
        }
    }

    func getSpotPostAnnotation(anno: MKAnnotation, posts: [MapPost], group: MapPostGroup, cluster: Bool, spotCluster: Bool) -> SpotPostAnnotationView {
        let reuseIdentifier = cluster ? "SpotPostCluster" : "SpotPost"
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? SpotPostAnnotationView else { return SpotPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? "SpotPostCluster" : nil
        annotationView.updateImage(posts: posts, spotName: group.spotName, id: group.id, spotCluster: spotCluster)
        annotationView.isSelected = posts.contains(where: { !$0.seen })
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotPostTap(_:))))
        return annotationView
    }

    func getSpotNameAnnotation(anno: MKAnnotation, group: MapPostGroup) -> SpotNameAnnotationView {
        let reuseIdentifier = "SpotName"
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? SpotNameAnnotationView else { return SpotNameAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        let priority = getSpotDisplayPriority(group: group)
        annotationView.setUp(spotID: group.id, spotName: group.spotName, priority: priority)
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotNameTap(_:))))
        return annotationView
    }

    func getSpotAnnotation(anno: SpotAnnotation, selectedMap: CustomMap?) -> MKAnnotationView {
        guard let selectedMap, let group = selectedMap.postGroup.first(where: { $0.id == anno.id }) else { return MKAnnotationView() }
        var posts: [MapPost] = []
        for id in group.postIDs.map({ $0.id }) {
            guard let post = selectedMap.postsDictionary[id] else { continue }
            posts.append(post)
        }

        return !posts.isEmpty ? getSpotPostAnnotation(anno: anno, posts: posts, group: group, cluster: false, spotCluster: false) : getSpotNameAnnotation(anno: anno, group: group)
    }

    func getSpotClusterAnnotation(anno: MKClusterAnnotation, selectedMap: CustomMap?) -> MKAnnotationView {
        guard let selectedMap else { return MKAnnotationView() }
        var selectedPostGroup: [MapPostGroup] = []
        /// each member has a post group -> get all the post groups
        for annotation in anno.memberAnnotations {
            if let member = annotation as? SpotAnnotation, let group = selectedMap.postGroup.first(where: { $0.id == member.id }) { selectedPostGroup.append(group) }
        }
        /// sort post groups for display and get all posts in cluster
        var posts: [MapPost] = []
        selectedPostGroup = sortPostGroup(selectedPostGroup)
        guard let firstPostGroup = selectedPostGroup.first else { return MKAnnotationView() }

        for group in selectedPostGroup {
            for id in group.postIDs.map({ $0.id }) {
                guard let post = selectedMap.postsDictionary[id] else { continue }
                posts.append(post)
            }
        }

        let spotCluster = selectedPostGroup.count > 1
        return getSpotPostAnnotation(anno: anno, posts: posts, group: firstPostGroup, cluster: true, spotCluster: spotCluster)
    }

    @objc func spotPostTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "MapControllerSpotPostAnnotationTap")
        let tapLocation = sender.location(in: sender.view)
        guard let annotationView = sender.view as? SpotPostAnnotationView else { return }

        let frame = annotationView.bounds
        let postFrame = CGRect(x: frame.midX - 35, y: 0, width: 70, height: 70)

        let usernameAvatarTouchArea = CGRect(x: frame.midX + 10, y: 42, width: frame.width / 2 - 10, height: 38)
        if postFrame.contains(tapLocation) {
            spotMapDelegate?.openPostFromSpotPost(view: annotationView)

        } else if annotationView.spotCluster {
            /// avatar + username area becomes touch area (avatar and username are beneath the post frame)
            let avatarFrame = CGRect(x: frame.midX - 43, y: frame.maxY - 66, width: frame.width, height: 66)
            if avatarFrame.contains(tapLocation) { spotMapDelegate?.centerMapOnPostsInCluster(view: annotationView) }

        } else if tapLocation.y > frame.maxY - 22 {
            if annotationView.spotName != "" { spotMapDelegate?.openSpotFromSpotPost(view: annotationView) }

        } else if usernameAvatarTouchArea.contains(tapLocation) {
            /// username / avatar tap (avatar and username are to the right of the post frame)
            spotMapDelegate?.centerMapOnPostsInCluster(view: annotationView)
        }
    }

    @objc func spotNameTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "MapControllerSpotNameAnnotationTap")
        guard let annotationView = sender.view as? SpotNameAnnotationView else { return }
        spotMapDelegate?.openSpotFromSpotName(view: annotationView)
    }

    func sortPostGroup(_ group: [MapPostGroup]) -> [MapPostGroup] {
        /// MapPostGroup postIDs will already be sorted
        group.sorted(by: { g1, g2 in
            guard (g1.postIDs.first?.seen ?? true) == (g2.postIDs.first?.seen ?? true) else {
                return !(g1.postIDs.first?.seen ?? true) && (g2.postIDs.first?.seen ?? true)
            }
            return g1.postIDs.first?.timestamp.seconds ?? 0 > g2.postIDs.first?.timestamp.seconds ?? 0
        })
    }

    func sortPosts(_ posts: [MapPost]) -> [MapPost] {
        posts.sorted(by: { p1, p2 in
            guard p1.seen == p2.seen else {
                return !p1.seen && p2.seen
            }

            return p1.timestamp.seconds > p2.timestamp.seconds
        })
    }

    func getSpotDisplayPriority(group: MapPostGroup) -> Float {
        var spotScore = max(0, Float(group.numberOfPosters - 1) * 200)

        for i in 0..<group.postsToSpot.count {
            var postScore: Float = 10
            /// increment for each friend post
            let postTime = Float(group.postTimestamps[safe: i]?.seconds ?? 1)
            let currentTime = Float(Date().timeIntervalSince1970)
            let timeSincePost = currentTime - postTime

            /// add multiplier for recent posts
            var factor = min(1 + (2_500_000 / timeSincePost), 20)
            let multiplier = pow(1.2, factor)
            factor = multiplier

            postScore *= factor
            spotScore += postScore
        }
        /// > 1000 = required annotation, dont want this
        return min(900, spotScore)
    }
}
