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
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        guard let mapView = mapView as? SpotMapView else { return nil }
        let selectedMap = getFriendsMapObject()

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

    func centerMapOnMapPosts(animated: Bool, includeSeen: Bool) {
        // return before location services enabled
        if firstTimeGettingLocation { return }
        // zoom out map to show all annotations in view
        let coordinates = getSortedCoordinates(includeSeen: includeSeen)
        mapView.enableGeoQuery = true
        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapView.setRegion(region, animated: animated)
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        /// remove clustering if zoomed in to ground level
        guard let mapView = mapView as? SpotMapView else { return }
        if mapView.lockClusterOnUpload { return }

        if mapView.region.span.longitudeDelta < 0.0014 {
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
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let mapRadius = mapView.currentRadius()
        if shouldRunGeoQuery() {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.getVisibleSpots(mapRadius: mapRadius)
            }
        }
        
        if postsFetched {
            setCityLabel()
        }
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        // disable user location callout
        if let userLocationView = mapView.view(for: mapView.userLocation) {
            userLocationView.canShowCallout = false
        }
    }

    func animateToCurrentLocation(animationDuration: TimeInterval? = 0.6) {
        if UserDataModel.shared.currentLocation.coordinate.isEmpty() { return }
        DispatchQueue.main.async {
            let camera = MKMapCamera(lookingAtCenter: UserDataModel.shared.currentLocation.coordinate, fromDistance: 2_000, pitch: 30, heading: self.mapView.camera.heading)
            MKMapView.animate(withDuration: animationDuration ?? 0.7, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 10, options: UIView.AnimationOptions.curveEaseOut, animations: {
                self.mapView.setCamera(camera, animated: true)
            })
        }
    }

    func animateToMostRecentPost() {
        let coordinate = mapView.sortPostGroup(postGroup).first?.coordinate
        animateTo(coordinate: coordinate)
    }

    func animateTo(coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            DispatchQueue.main.async { self.mapView.setRegion(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.00139, longitudeDelta: 0.00139)), animated: true) }
        }
    }

    func offsetCustomMapCenter() {
        DispatchQueue.main.async { self.centerMapOnMapPosts(animated: false, includeSeen: false) }
    }

    func getSortedCoordinates(includeSeen: Bool) -> [CLLocationCoordinate2D] {
        // filter for spots without posts
        var group = postGroup.filter({ !$0.postIDs.isEmpty })
        // only center map on unseen posts
        if !includeSeen { group = group.filter({ $0.postIDs.contains(where: { !$0.seen }) }) }
        group = mapView.sortPostGroup(group)
        return group.map({ $0.coordinate })
    }

    func setCityLabel() {
        let radius = mapView.currentRadius() / 1_000
        let zoomLevel = radius < 60 ? 0 : radius < 800 ? 1 : 2
        let location = mapView.centerCoordinate.location
        location.reverseGeocode(zoomLevel: zoomLevel) { [weak self] (address, err) in
            guard let self = self else { return }
            if address == "" && err { return }
            self.cityLabel.text = address
            self.cityLabel.layoutIfNeeded()
            self.cityLabel.addShadow(shadowColor: UIColor(red: 0, green: 0, blue: 0, alpha: 0.4).cgColor, opacity: 1, radius: 2, offset: CGSize(width: 0.5, height: 0.5))
        }
    }

    func addMapAnnotations() {
        mapView.removeAllAnnos()
        let map = getFriendsMapObject()
        // create temp map to represent friends map
        for group in postGroup { mapView.addSpotAnnotation(group: group, map: map) }
    }

    func getFriendsMapObject() -> CustomMap {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.postsDictionary = postDictionary
        map.postGroup = postGroup
        return map
    }
}

extension MapController: SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        let map = getFriendsMapObject()
        var posts: [MapPost] = []
        var unseenPost = false
        /// patch fix for double post getting added
        for id in view.postIDs {
            guard let post = map.postsDictionary[id] else { continue }
            if !post.seen { unseenPost = true }
            if !posts.contains(where: { $0.id ?? "" == post.id ?? "" }) { posts.append(post) }
        }

        var nonClusterPosts: [MapPost] = []
        for post in map.postsDictionary where !posts.contains(where: { $0.id ?? "" == post.key }) && !nonClusterPosts.contains(where: { $0.id ?? "" == post.key }) {
            // only add new posts if user opened a new post
            if unseenPost {
                if !post.value.seen { nonClusterPosts.append(post.value) }
            } else {
                nonClusterPosts.append(post.value)
            }
        }
        nonClusterPosts.sort(by: { $0.seen == $1.seen ? $0.timestamp.seconds > $1.timestamp.seconds : $0.seen && !$1.seen })
        posts.append(contentsOf: nonClusterPosts)

        DispatchQueue.main.async { self.openPosts(posts: posts) }
    }

    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName, mapID: "", mapName: "")
    }

    func openSpotFromSpotName(view: SpotNameAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName, mapID: "", mapName: "")
    }

    func centerMapOnPostsInCluster(view: SpotPostAnnotationView) {
        let map = getFriendsMapObject()
        var coordinates: [CLLocationCoordinate2D] = []

        for id in view.postIDs {
            if let post = map.postsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false, clusterTap: true)
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
    var lockClusterOnUpload = false
    var enableGeoQuery = false
    var spotMapDelegate: SpotMapViewDelegate?
    private lazy var bottomMask = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        mapType = .standard
        overrideUserInterfaceStyle = .light
        pointOfInterestFilter = .excludingAll
        showsCompass = false
        showsTraffic = false
        showsUserLocation = true
        tag = 13
        register(SpotNameAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotName")
        register(SpotPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotPost")
        register(SpotPostAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SpotPostCluster")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        addBottomMask()
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
                // add new annotation
                addSpotAnnotation(group: group, map: map)

            } else if let anno = annotations.first(where: { $0.coordinate.isEqualTo(coordinate: group.coordinate) }) {
                // remove existing anno and update
                removeAnnotation(anno)
                addSpotAnnotation(group: group, map: map)
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
        DispatchQueue.main.async { self.addAnnotation(spotAnnotation) }
    }

    func removeAllAnnos() {
        removeAnnotations(annotations)
    }

    func getSpotPostAnnotation(anno: MKAnnotation, posts: [MapPost], group: MapPostGroup, cluster: Bool, spotCluster: Bool) -> SpotPostAnnotationView {
        let reuseIdentifier = cluster ? "SpotPostCluster" : "SpotPost"
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? SpotPostAnnotationView else { return SpotPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? "SpotPostCluster" : nil
        annotationView.updateImage(posts: posts, spotName: group.spotName, id: group.id, poiCategory: group.poiCategory, spotCluster: spotCluster)
        annotationView.isSelected = posts.contains(where: { !$0.seen })
        let tap = UITapGestureRecognizer(target: self, action: #selector(spotPostTap(_:)))
        tap.delegate = self
        annotationView.addGestureRecognizer(tap)
        return annotationView
    }

    func getSpotNameAnnotation(anno: MKAnnotation, group: MapPostGroup) -> SpotNameAnnotationView {
        let reuseIdentifier = "SpotName"
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? SpotNameAnnotationView else { return SpotNameAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        let priority = getSpotDisplayPriority(group: group)
        annotationView.setUp(spotID: group.id, spotName: group.spotName, poiCategory: group.poiCategory, priority: priority)

        let tap = UITapGestureRecognizer(target: self, action: #selector(spotNameTap(_:)))
        tap.delegate = self
        annotationView.addGestureRecognizer(tap)

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

        } else if usernameAvatarTouchArea.contains(tapLocation) && annotationView.clusteringIdentifier != nil {
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

    func addBottomMask() {
        if bottomMask.superview != nil { return }

        bottomMask.isUserInteractionEnabled = false
        addSubview(bottomMask)
        bottomMask.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-65)
            $0.height.equalTo(242)
        }
        bottomMask.layoutIfNeeded()

        let layer = CAGradientLayer()
        layer.frame = bottomMask.bounds
        layer.colors = [
            UIColor(red: 1, green: 1, blue: 1, alpha: 0).cgColor,
            UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.locations = [0, 1]
        bottomMask.layer.addSublayer(layer)
    }
}

extension SpotMapView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
