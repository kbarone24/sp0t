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
        annotationView.clusteringIdentifier = shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil

        guard let postInfo = self.postsList.first(where: {$0.id == anno.postID}) else { return FriendPostAnnotationView() }
        annotationView.updateImage(posts: [postInfo])
        return annotationView
    }
    
    func getSpotAnnotation(anno: SpotPostAnnotation) -> MKAnnotationView {
        let selectedMap = getSelectedMap()
        guard let group = selectedMap?.postGroup.first(where: {$0.id == anno.id}) else { return MKAnnotationView() }
        let post = group.postIDs.isEmpty ? nil : selectedMap?.postsDictionary[group.postIDs.first!.id]
       
        return post != nil ? getSpotPostAnnotation(anno: anno, post: post!, group: group, cluster: false) : getSpotNameAnnotation(anno: anno, spotID: group.id, spotName: group.spotName, cluster: false)
    }
    
    func getSpotPostAnnotation(anno: MKAnnotation, post: MapPost, group: MapPostGroup, cluster: Bool) -> SpotPostAnnotationView {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "SpotPost") as? SpotPostAnnotationView else { return SpotPostAnnotationView() }
        annotationView.annotation = anno
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.updateImage(post: post, spotName: group.spotName, id: group.id)
        return annotationView
    }
    
    func getSpotNameAnnotation(anno: MKAnnotation, spotID: String, spotName: String, cluster: Bool) -> SpotNameAnnotationView {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "SpotName") as? SpotNameAnnotationView else { return SpotNameAnnotationView() }
        annotationView.annotation = anno
        annotationView.clusteringIdentifier = !cluster && shouldCluster ? MKMapViewDefaultClusterAnnotationViewReuseIdentifier : nil
        annotationView.setUp(spotID: spotID, spotName: spotName)
        return annotationView
    }
    
    func getPostClusterAnnotation(anno: MKClusterAnnotation) -> FriendPostAnnotationView {
        // set up friend posts view with multiple posts
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "FriendsPost") as? FriendPostAnnotationView else { return FriendPostAnnotationView() }
        annotationView.annotation = anno
        
        var posts: [MapPost] = []
        for memberAnno in anno.memberAnnotations {
            if let member = memberAnno as? PostAnnotation, let post = postsList.first(where: {$0.id == member.postID}) {
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
        /// sort post groups for display and get first post
        selectedPostGroup = sortPostGroup(selectedPostGroup)
        let firstPostGroup = selectedPostGroup.first!
        let postID = firstPostGroup.postIDs.isEmpty ? nil : firstPostGroup.postIDs.first!.id
        let post = postID == nil ? nil : selectedMap?.postsDictionary[postID!] /// need to sort
        
        return post != nil ? getSpotPostAnnotation(anno: anno, post: post!, group: firstPostGroup, cluster: true) : getSpotNameAnnotation(anno: anno, spotID: firstPostGroup.id, spotName: firstPostGroup.spotName, cluster: true)
    }
    
    func centerMapOnPosts(animated: Bool) {
        /// zoom out map to show all annotations in view
        let map = getSelectedMap()
        let coordinates = map == nil ? friendsPostsDictionary.map({$0.value}).sorted(by: {$0.timestamp.seconds > $1.timestamp.seconds}).map({CLLocationCoordinate2D(latitude: $0.postLat, longitude: $0.postLong)}) : map!.postGroup.map{$0.coordinate}
        
        var region = MKCoordinateRegion(coordinates: coordinates)
        if region.span.latitudeDelta == region.maxSpan || region.span.longitudeDelta == region.maxSpan {
            region.center = coordinates.first!
        }
        self.mapView.setRegion(region, animated: animated)
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
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        /// remove clustering if zoomed in to ground level
        if mapView.region.span.longitudeDelta < 0.002 {
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
}
///https://stackoverflow.com/questions/15421106/centering-mkmapview-on-spot-n-pixels-below-pin


// Supposed to exclude invalid geoQuery regions. Not sure how well it works
extension MKCoordinateRegion {
    var maxSpan: Double {
        get {
            return 200
        }
    }
    
    var IsValid: Bool {
        get {
            let latitudeCenter = self.center.latitude
            let latitudeNorth = self.center.latitude + self.span.latitudeDelta/2
            let latitudeSouth = self.center.latitude - self.span.latitudeDelta/2
            
            let longitudeCenter = self.center.longitude
            let longitudeWest = self.center.longitude - self.span.longitudeDelta/2
            let longitudeEast = self.center.longitude + self.span.longitudeDelta/2
            
            let topLeft = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeWest)
            let topCenter = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeCenter)
            let topRight = CLLocationCoordinate2D(latitude: latitudeNorth, longitude: longitudeEast)
            
            let centerLeft = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeWest)
            let centerCenter = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeCenter)
            let centerRight = CLLocationCoordinate2D(latitude: latitudeCenter, longitude: longitudeEast)
            
            let bottomLeft = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeWest)
            let bottomCenter = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeCenter)
            let bottomRight = CLLocationCoordinate2D(latitude: latitudeSouth, longitude: longitudeEast)
            
            return  CLLocationCoordinate2DIsValid(topLeft) &&
            CLLocationCoordinate2DIsValid(topCenter) &&
            CLLocationCoordinate2DIsValid(topRight) &&
            CLLocationCoordinate2DIsValid(centerLeft) &&
            CLLocationCoordinate2DIsValid(centerCenter) &&
            CLLocationCoordinate2DIsValid(centerRight) &&
            CLLocationCoordinate2DIsValid(bottomLeft) &&
            CLLocationCoordinate2DIsValid(bottomCenter) &&
            CLLocationCoordinate2DIsValid(bottomRight) ?
            true :
            false
        }
    }
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.init()
        
        if coordinates.isEmpty {
            self.init(center: UserDataModel.shared.currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
            return
        }
        
        var minLatitude: CLLocationDegrees = 90.0
        var maxLatitude: CLLocationDegrees = -90.0
        var minLongitude: CLLocationDegrees = 180.0
        var maxLongitude: CLLocationDegrees = -180.0
        
        for coordinate in coordinates {
            let lat = Double(coordinate.latitude)
            let long = Double(coordinate.longitude)
            if lat < minLatitude {
                minLatitude = lat
            }
            if long < minLongitude {
                minLongitude = long
            }
            if lat > maxLatitude {
                maxLatitude = lat
            }
            if long > maxLongitude {
                maxLongitude = long
            }
        }
        
        let span = MKCoordinateSpan(latitudeDelta: maxLatitude - minLatitude, longitudeDelta: maxLongitude - minLongitude)
        let center = CLLocationCoordinate2DMake((maxLatitude - span.latitudeDelta / 2), (maxLongitude - span.longitudeDelta / 2))
        
        let adjustedLatitude: Double = span.latitudeDelta == 0.0 ? 0.1 : span.latitudeDelta * 1.5 > maxSpan ? maxSpan : span.latitudeDelta * 1.5
        let adjustedLongitude: Double = span.longitudeDelta == 0.0 ? 0.1 : span.longitudeDelta * 1.5 > maxSpan ? maxSpan : span.longitudeDelta * 1.5
        let adjustedSpan = MKCoordinateSpan(latitudeDelta: adjustedLatitude, longitudeDelta: adjustedLongitude)
        self.init(center: center, span: adjustedSpan)
    }
    ///https://stackoverflow.com/questions/14374030/center-coordinate-of-a-set-of-cllocationscoordinate2d
}
