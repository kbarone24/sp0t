//
//  MapViewDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 8/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Mixpanel

//functions for loading nearby spots in nearby view
extension MapController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mapView = mapView as? SpotMapView else { return MKAnnotationView() }
        let selectedMap = getSelectedMap()
        
        if let anno = annotation as? PostAnnotation {
            guard let post = friendsPostsDictionary[anno.postID] else { return MKAnnotationView() }
            return mapView.getPostAnnotation(anno: anno, post: post)
            
        } else if let anno = annotation as? SpotPostAnnotation {
            /// set up spot post view with 1 post
            return mapView.getSpotAnnotation(anno: anno, selectedMap: selectedMap)
            
        } else if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.first is PostAnnotation {
                let posts = getPostsFor(cluster: anno)
                return mapView.getPostClusterAnnotation(anno: anno, posts: posts)
            } else {
                return mapView.getSpotClusterAnnotation(anno: anno, selectedMap: selectedMap)
            }
        }
        
        return MKAnnotationView()
    }
    
    func getPostsFor(cluster: MKClusterAnnotation) -> [MapPost] {
        var posts: [MapPost] = []
        for memberAnno in cluster.memberAnnotations {
            if let member = memberAnno as? PostAnnotation, let post = friendsPostsDictionary[member.postID] {
                posts.append(post)
            }
        }
        return posts
    }
    
    func centerMapOnMapPosts(animated: Bool) {
        /// zoom out map to show all annotations in view
        let map = getSelectedMap()
        var coordinates = getSortedCoordinates()
        /// add fist 10 post coordiates to set location for map with no new posts
        if coordinates.isEmpty && map != nil {
            for location in map!.postLocations.prefix(10) { coordinates.append(CLLocationCoordinate2D(latitude: location["lat"] ?? 0.0, longitude: location["long"] ?? 0.0)) }
        }
        
        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapView.setRegion(region, animated: animated)
    }
    
    func isSelectedMap(mapID: String) -> Bool {
        if mapID == "" { return selectedItemIndex == 0 }
        return mapID == UserDataModel.shared.userInfo.mapsList[selectedItemIndex - 1].id ?? ""
    }
    
    func getSelectedMap() -> CustomMap? {
        return selectedItemIndex == 0 ? nil : UserDataModel.shared.userInfo.mapsList[selectedItemIndex - 1]
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        /// remove clustering if zoomed in to ground level
        guard let mapView = mapView as? SpotMapView else { return }
        if mapView.region.span.longitudeDelta < 0.0013 {
            if mapView.shouldCluster {
                mapView.shouldCluster = false
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    self.mapView.addAnnotations(annotations)
                }
            }
        } else {
            if !mapView.shouldCluster {
                mapView.shouldCluster = true
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    self.mapView.addAnnotations(annotations)
                }
            }
        }
    }
    
    func animateToMostRecentPost() {
        let map = getSelectedMap()
        if map == nil {
            let posts = friendsPostsDictionary.map({$0.value})
            let coordinate = mapView.sortPosts(posts).first?.coordinate
            animateTo(coordinate: coordinate)
        } else {
            let group = map!.postGroup
            let coordinate = mapView.sortPostGroup(group).first?.coordinate
            animateTo(coordinate: coordinate)
        }
    }
    
    func animateTo(coordinate: CLLocationCoordinate2D?) {
        if coordinate != nil {
            DispatchQueue.main.async { self.mapView.setRegion(MKCoordinateRegion(center: coordinate!, span: MKCoordinateSpan(latitudeDelta: 0.0012, longitudeDelta: 0.0012)), animated: true) }
        }
    }
    
    func offsetCustomMapCenter() {
        DispatchQueue.main.async { self.centerMapOnMapPosts(animated: false) }
    }
}

extension MapController: SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        let map = getSelectedMap()
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append((map?.postsDictionary[id])!) }
        DispatchQueue.main.async { self.openPost(posts: posts) }
    }
    
    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }
    
    func openSpotFromSpotName(view: SpotNameAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }
    
    func openPostFromFriendsPost(view: FriendPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append(friendsPostsDictionary[id]!) }
        DispatchQueue.main.async { self.openPost(posts: posts) }
    }
    
    func centerMapOnPostsInCluster(view: FriendPostAnnotationView) {
        var coordinates: [CLLocationCoordinate2D] = []
        for id in view.postIDs {
            if let post = friendsPostsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false)
        DispatchQueue.main.async { self.mapView.setRegion(region, animated: true) }
    }
}

protocol SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView)
    func openSpotFromSpotPost(view: SpotPostAnnotationView)
    func openSpotFromSpotName(view: SpotNameAnnotationView)
    func openPostFromFriendsPost(view: FriendPostAnnotationView)
    func centerMapOnPostsInCluster(view: FriendPostAnnotationView)
}

class SpotMapView: MKMapView {
    var shouldCluster = false
    var spotMapDelegate: SpotMapViewDelegate?
    
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
        
    func addPostAnnotation(post: MapPost) {
        let postAnnotation = PostAnnotation()
        postAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
        postAnnotation.postID = post.id!
        DispatchQueue.main.async { self.addAnnotation(postAnnotation) }
    }
    
    func addSpotAnnotation(group: MapPostGroup, map: CustomMap) {
        let spotAnnotation = SpotPostAnnotation()
        spotAnnotation.id = group.id
        
        if let index = map.spotIDs.firstIndex(of: group.id) {
            let location = map.spotLocations[index]
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: location["lat"]!, longitude: location["long"]!)
        } else if let post = map.postsDictionary[group.id] {
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
        }
        DispatchQueue.main.async { self.addAnnotation(spotAnnotation) }
    }
    
    func removeAllAnnos() {
        removeAnnotations(annotations)
    }
    
    func getSpotPostAnnotation(anno: MKAnnotation, posts: [MapPost], group: MapPostGroup, cluster: Bool) -> SpotPostAnnotationView {
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: "SpotPost") as? SpotPostAnnotationView else { return SpotPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.updateImage(posts: posts, spotName: group.spotName, id: group.id)
        annotationView.isSelected = posts.contains(where: {!$0.seen})
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotPostTap(_:))))
        return annotationView
    }
        
    func getSpotNameAnnotation(anno: MKAnnotation, spotID: String, spotName: String, cluster: Bool) -> SpotNameAnnotationView {
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: "SpotName") as? SpotNameAnnotationView else { return SpotNameAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.setUp(spotID: spotID, spotName: spotName)
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotNameTap(_:))))
        return annotationView
    }
    
    func getPostAnnotation(anno: PostAnnotation, post: MapPost) -> FriendPostAnnotationView {
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: "FriendsPost") as? FriendPostAnnotationView else { return FriendPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.clusteringIdentifier = shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.updateImage(posts: [post])
        annotationView.isSelected = !post.seen
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(friendsPostTap(_:))))
        return annotationView
    }
    
    func getSpotAnnotation(anno: SpotPostAnnotation, selectedMap: CustomMap?) -> MKAnnotationView {
        guard selectedMap != nil, let group = selectedMap!.postGroup.first(where: {$0.id == anno.id}) else { return MKAnnotationView() }
        var posts: [MapPost] = []
        for id in group.postIDs.map({$0.id}) { posts.append(selectedMap!.postsDictionary[id]!) }
       
        return !posts.isEmpty ? getSpotPostAnnotation(anno: anno, posts: posts, group: group, cluster: false) : getSpotNameAnnotation(anno: anno, spotID: group.id, spotName: group.spotName, cluster: false)
    }
    
    
    func getPostClusterAnnotation(anno: MKClusterAnnotation, posts: [MapPost]) -> FriendPostAnnotationView {
        // set up friend posts view with multiple posts
        guard let annotationView = dequeueReusableAnnotationView(withIdentifier: "FriendsPost") as? FriendPostAnnotationView else { return FriendPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = self
        annotationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(friendsPostTap(_:))))
        
        let posts = sortPosts(posts)
        annotationView.updateImage(posts: posts)
        return annotationView
    }
    
    func getSpotClusterAnnotation(anno: MKClusterAnnotation, selectedMap: CustomMap?) -> MKAnnotationView {
        if selectedMap == nil { return MKAnnotationView() }
        var selectedPostGroup: [MapPostGroup] = []
        /// each member has a post group -> get all the post groups
        for annotation in anno.memberAnnotations {
            if let member = annotation as? SpotPostAnnotation, let group = selectedMap!.postGroup.first(where: {$0.id == member.id}) { selectedPostGroup.append(group) }
        }
        /// sort post groups for display and get all posts in cluster
        var posts: [MapPost] = []
        selectedPostGroup = sortPostGroup(selectedPostGroup)
        guard let firstPostGroup = selectedPostGroup.first else { return MKAnnotationView() }

        for group in selectedPostGroup {
            for id in group.postIDs.map({$0.id}) { posts.append((selectedMap!.postsDictionary[id])!) }
        }
        
        return !posts.isEmpty ? getSpotPostAnnotation(anno: anno, posts: posts, group: firstPostGroup, cluster: true) : getSpotNameAnnotation(anno: anno, spotID: firstPostGroup.id, spotName: firstPostGroup.spotName, cluster: true)
    }
    
    @objc func friendsPostTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "MapControllerFriendAnnotationTap")
        let tapLocation = sender.location(in: sender.view)
        guard let annotationView = sender.view as? FriendPostAnnotationView else { return }
        tapLocation.y > 65 ? spotMapDelegate?.centerMapOnPostsInCluster(view: annotationView) : spotMapDelegate?.openPostFromFriendsPost(view: annotationView)
    }
    
    @objc func spotPostTap(_ sender: UITapGestureRecognizer) {
        Mixpanel.mainInstance().track(event: "MapControllerSpotPostAnnotationTap")
        let tapLocation = sender.location(in: sender.view)
        guard let annotationView = sender.view as? SpotPostAnnotationView else { return }
        
        if tapLocation.y > 72 {
            if annotationView.spotName != "" { spotMapDelegate?.openSpotFromSpotPost(view: annotationView) }
        } else {
            spotMapDelegate?.openPostFromSpotPost(view: annotationView)
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
}

// supplementary methods for offsetCenterCoordinate
extension CLLocationCoordinate2D {
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    private func radians(from degrees: CLLocationDegrees) -> Double {
        return degrees * .pi / 180.0
    }
    
    private func degrees(from radians: Double) -> CLLocationDegrees {
        return radians * 180.0 / .pi
    }
    
    func adjust(by distance: CLLocationDistance, at bearing: CLLocationDegrees) -> CLLocationCoordinate2D {
        
        let distanceRadians = distance / 6_371.0   // 6,371 = Earth's radius in km
        let bearingRadians = radians(from: bearing)
        let fromLatRadians = radians(from: latitude)
        let fromLonRadians = radians(from: longitude)
        
        let toLatRadians = asin( sin(fromLatRadians) * cos(distanceRadians)
                                 + cos(fromLatRadians) * sin(distanceRadians) * cos(bearingRadians) )
        
        var toLonRadians = fromLonRadians + atan2(sin(bearingRadians)
                                                  * sin(distanceRadians) * cos(fromLatRadians), cos(distanceRadians)
                                                  - sin(fromLatRadians) * sin(toLatRadians))
        
        // adjust toLonRadians to be in the range -180 to +180...
        toLonRadians = fmod((toLonRadians + 3.0 * .pi), (2.0 * .pi)) - .pi
        
        let result = CLLocationCoordinate2D(latitude: degrees(from: toLatRadians), longitude: degrees(from: toLonRadians))
        
        return result
    }
    
    func isEqualTo(coordinate: CLLocationCoordinate2D) -> Bool {
        return location.coordinate.latitude == coordinate.latitude && location.coordinate.longitude == coordinate.longitude
    }
}
///https://stackoverflow.com/questions/15421106/centering-mkmapview-on-spot-n-pixels-below-pin


// Supposed to exclude invalid geoQuery regions. Not sure how well it works
extension MKCoordinateRegion {
    var maxSpan: Double {
        get {
            return 200
        }
    }
    
    init(coordinates: [CLLocationCoordinate2D], overview: Bool) {
        self.init()
        
        if coordinates.isEmpty {
            self.init(center: UserDataModel.shared.currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
            return
        }
        
        let minSpan = overview ? 0.05 : 0.0001
        var span = MKCoordinateSpan(latitudeDelta: 0.0, longitudeDelta: 0.0)
        var minLatitude: CLLocationDegrees = coordinates.first!.latitude
        var maxLatitude: CLLocationDegrees = coordinates.first!.latitude
        var minLongitude: CLLocationDegrees = coordinates.first!.longitude
        var maxLongitude: CLLocationDegrees = coordinates.first!.longitude

        for coordinate in coordinates {
            /// set local variables in case continue called before completion
            var minLat = minLatitude
            var maxLat = maxLatitude
            var minLong = minLongitude
            var maxLong = maxLongitude
            
            let lat = Double(coordinate.latitude)
            let long = Double(coordinate.longitude)
            if lat < minLatitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: maxLatitude - lat, longitudeDelta: span.longitudeDelta).getAdjustedSpan()) { continue }
                
                minLat = lat
            }
            if lat > maxLatitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: lat - minLatitude, longitudeDelta: span.longitudeDelta).getAdjustedSpan()) { continue }
                maxLat = lat
            }
            if long < minLongitude {
                if spanOutOfRange(span: MKCoordinateSpan(latitudeDelta: span.latitudeDelta, longitudeDelta: maxLongitude - long).getAdjustedSpan()) { continue }
                minLong = long
            }
            if long > maxLongitude {
                if spanOutOfRange(span:  MKCoordinateSpan(latitudeDelta: span.latitudeDelta, longitudeDelta: long - minLongitude).getAdjustedSpan()) { continue }
                maxLong = long
            }
            
            minLatitude = minLat
            maxLatitude = maxLat
            minLongitude = minLong
            maxLongitude = maxLong
            span = MKCoordinateSpan(latitudeDelta: max(minSpan, maxLatitude - minLatitude), longitudeDelta: max(minSpan, maxLongitude - minLongitude)).getAdjustedSpan()
        }
        
        let center = CLLocationCoordinate2DMake((minLatitude + maxLatitude)/2, (minLongitude + maxLongitude)/2)
        self.init(center: center, span: span)
    }
  
    
    ///https://stackoverflow.com/questions/14374030/center-coordinate-of-a-set-of-cllocationscoordinate2d
    func spanOutOfRange(span: MKCoordinateSpan) -> Bool {
        let span = span.getAdjustedSpan()
        return span.latitudeDelta > maxSpan || span.longitudeDelta > maxSpan
    }
}

extension MKCoordinateSpan {
    func getAdjustedSpan() -> MKCoordinateSpan {
        return MKCoordinateSpan(latitudeDelta: latitudeDelta * 2.0, longitudeDelta: longitudeDelta * 2.0)
    }
}

