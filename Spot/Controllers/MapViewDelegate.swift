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

//functions for loading nearby spots in nearby view
extension MapController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let anno = annotation as? PostAnnotation {
            return getPostAnnotation(anno: anno)
            
        } else if let anno = annotation as? SpotPostAnnotation {
            /// set up spot post view with 1 post
            return getSpotAnnotation(anno: anno)
            
        } else if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.first is PostAnnotation {
                return getPostClusterAnnotation(anno: anno)
                
            } else {
                return getSpotClusterAnnotation(anno: anno)
            }
        }
        
        return MKAnnotationView()
    }
    
    func getPostAnnotation(anno: PostAnnotation) -> FriendPostAnnotationView {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "FriendsPost") as? FriendPostAnnotationView else { return FriendPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = mapView
        annotationView.clusteringIdentifier = shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil

        guard let postInfo = friendsPostsDictionary[anno.postID] else { return FriendPostAnnotationView() }
        annotationView.updateImage(posts: [postInfo])
        return annotationView
    }
    
    func getSpotAnnotation(anno: SpotPostAnnotation) -> MKAnnotationView {
        let selectedMap = getSelectedMap()
        guard let group = selectedMap?.postGroup.first(where: {$0.id == anno.id}) else { return MKAnnotationView() }
        var posts: [MapPost] = []
        for id in group.postIDs.map({$0.id}) { posts.append(selectedMap!.postsDictionary[id]!) }
       
        return !posts.isEmpty ? getSpotPostAnnotation(anno: anno, posts: posts, group: group, cluster: false) : getSpotNameAnnotation(anno: anno, spotID: group.id, spotName: group.spotName, cluster: false)
    }
    
    func getSpotPostAnnotation(anno: MKAnnotation, posts: [MapPost], group: MapPostGroup, cluster: Bool) -> SpotPostAnnotationView {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "SpotPost") as? SpotPostAnnotationView else { return SpotPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = mapView
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.updateImage(posts: posts, spotName: group.spotName, id: group.id)
        return annotationView
    }
    
    func getSpotNameAnnotation(anno: MKAnnotation, spotID: String, spotName: String, cluster: Bool) -> SpotNameAnnotationView {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "SpotName") as? SpotNameAnnotationView else { return SpotNameAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = mapView
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.setUp(spotID: spotID, spotName: spotName)
        return annotationView
    }
    
    func getPostClusterAnnotation(anno: MKClusterAnnotation) -> FriendPostAnnotationView {
        // set up friend posts view with multiple posts
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "FriendsPost") as? FriendPostAnnotationView else { return FriendPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.mapView = mapView
        
        var posts: [MapPost] = []
        for memberAnno in anno.memberAnnotations {
            if let member = memberAnno as? PostAnnotation, let post = friendsPostsDictionary[member.postID] {
                posts.append(post)
            }
        }
        
        posts = sortPosts(posts)
        annotationView.updateImage(posts: posts)
        return annotationView
    }
    
    func getSpotClusterAnnotation(anno: MKClusterAnnotation) -> MKAnnotationView {
        let selectedMap = getSelectedMap()
        var selectedPostGroup: [MapPostGroup] = []
        /// each member has a post group -> get all the post groups
        for annotation in anno.memberAnnotations {
            if let member = annotation as? SpotPostAnnotation, let group = selectedMap?.postGroup.first(where: {$0.id == member.id}) { selectedPostGroup.append(group) }
        }
        /// sort post groups for display and get all posts in cluster
        var posts: [MapPost] = []
        selectedPostGroup = sortPostGroup(selectedPostGroup)
        guard let firstPostGroup = selectedPostGroup.first else { return MKAnnotationView() }

        for group in selectedPostGroup {
            for id in group.postIDs.map({$0.id}) { posts.append((selectedMap?.postsDictionary[id])!) }
        }
        
        return !posts.isEmpty ? getSpotPostAnnotation(anno: anno, posts: posts, group: firstPostGroup, cluster: true) : getSpotNameAnnotation(anno: anno, spotID: firstPostGroup.id, spotName: firstPostGroup.spotName, cluster: true)
    }
    
    func centerMapOnPosts(animated: Bool) {
        /// zoom out map to show all annotations in view
        let coordinates = getSortedCoordinates()
        let region = MKCoordinateRegion(coordinates: coordinates)
        mapView.setRegion(region, animated: animated)
    }
    
    func isSelectedMap(mapID: String) -> Bool {
        if mapID == "" { return selectedItemIndex == 0 }
        return mapID == UserDataModel.shared.userInfo.mapsList[selectedItemIndex - 1].id ?? ""
    }
    
    func getSelectedMap() -> CustomMap? {
        return selectedItemIndex == 0 ? nil : UserDataModel.shared.userInfo.mapsList[selectedItemIndex - 1]
    }
    
    func addPostAnnotation(post: MapPost) {
        let postAnnotation = PostAnnotation()
        postAnnotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
        postAnnotation.postID = post.id!
        DispatchQueue.main.async { self.mapView.addAnnotation(postAnnotation) }
    }
    
    func addSpotAnnotation(group: MapPostGroup) {
        let spotAnnotation = SpotPostAnnotation()
        spotAnnotation.id = group.id
        let selectedMap = getSelectedMap()!
        
        if let index = selectedMap.spotIDs.firstIndex(of: group.id) {
            let location = selectedMap.spotLocations[index]
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: location["lat"]!, longitude: location["long"]!)
        } else {
            let post = selectedMap.postsDictionary[group.id]
            spotAnnotation.coordinate = CLLocationCoordinate2D(latitude: post!.postLat, longitude: post!.postLong)
        }
        
        DispatchQueue.main.async { self.mapView.addAnnotation(spotAnnotation) }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let view = view as? SpotPostAnnotationView {
            let map = getSelectedMap()
            var posts: [MapPost] = []
            for id in view.postIDs { posts.append((map?.postsDictionary[id])!) }
            DispatchQueue.main.async { self.openPost(posts: posts) }
            
        } else if let view = view as? FriendPostAnnotationView {
            var posts: [MapPost] = []
            for id in view.postIDs { posts.append(friendsPostsDictionary[id]!) }
            DispatchQueue.main.async { self.openPost(posts: posts) }
            
        } else if let view = view as? SpotNameView {
            print("open spot page")
        }
        
        mapView.deselectAnnotation(view.annotation, animated: false)
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        /// remove clustering if zoomed in to ground level
        if mapView.region.span.longitudeDelta < 0.0017 {
            if shouldCluster {
                shouldCluster = false
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    self.mapView.removeAnnotations(annotations)
                    self.mapView.addAnnotations(annotations)
                }
            }
        } else {
            if !self.shouldCluster {
                self.shouldCluster = true
                let annotations = self.mapView.annotations
                DispatchQueue.main.async {
                    self.mapView.removeAnnotations(annotations)
                    self.mapView.addAnnotations(annotations)
                }
            }
        }
    }
    
    func animateToMostRecentPost() {
        let map = getSelectedMap()
        if map == nil {
            let posts = friendsPostsDictionary.map({$0.value})
            let coordinate = sortPosts(posts).first?.coordinate
            animateTo(coordinate: coordinate)
        } else {
            let group = map!.postGroup
            let coordinate = sortPostGroup(group).first?.coordinate
            animateTo(coordinate: coordinate)
        }
    }
    
    func animateTo(coordinate: CLLocationCoordinate2D?) {
        if coordinate != nil {
            DispatchQueue.main.async { self.mapView.setRegion(MKCoordinateRegion(center: coordinate!, span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)), animated: true) }
        }
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
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.init()
        
        if coordinates.isEmpty {
            self.init(center: UserDataModel.shared.currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
            return
        }
        
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
            span = MKCoordinateSpan(latitudeDelta: max(0.05, maxLatitude - minLatitude), longitudeDelta: max(0.05, maxLongitude - minLongitude)).getAdjustedSpan()
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

/*
extension MKMapView {
    func setOffsetRegion(region: MKCoordinateRegion, offset: CGFloat, animated: Bool) {
        let originalCoordinate = region.center
        var point = convert(originalCoordinate, toPointTo: self)
     //   print("point", point)
        //point.y -= offset
     //   print("point 2", point)
        
        let coordinate = convert(point, toCoordinateFrom: self)
     //   let offsetLocation = coordinate.location
     //   let distance = originalCoordinate.location.distance(from: offsetLocation) / 1000.0
      //  let adjustedCenter = originalCoordinate.adjust(by: distance, at: camera.heading - 180.0)
        
        let adjustedRegion = MKCoordinateRegion(center: coordinate, span: region.span)
        setRegion(adjustedRegion, animated: animated)
    }
}
*/
