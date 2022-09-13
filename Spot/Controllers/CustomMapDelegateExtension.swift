//
//  CustomMapDelegateExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit

extension CustomMapController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mapView = mapView as? SpotMapView else { return MKAnnotationView() }
        
        if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.contains(where: {$0 is PostAnnotation}) {
                let posts = getPostsFor(cluster: anno)
                return mapView.getPostClusterAnnotation(anno: anno, posts: posts)
            } else if anno.memberAnnotations.contains(where: {$0 is SpotPostAnnotation}) {
                return mapView.getSpotClusterAnnotation(anno: anno, selectedMap: mapData)
            }
        } else if let anno = annotation as? PostAnnotation {
            guard let post = mapData!.postsDictionary[anno.postID] else { return MKAnnotationView() }
            return mapView.getPostAnnotation(anno: anno, post: post)
            
        } else if let anno = annotation as? SpotPostAnnotation {
            /// set up spot post view with 1 post
            return mapView.getSpotAnnotation(anno: anno, selectedMap: mapData)
            
        }
        return MKAnnotationView()
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        // gets called too much -> just use gesture recognizer
        if centeredMap { closeDrawer() }
        centeredMap = false
    }
    
    func getPostsFor(cluster: MKClusterAnnotation) -> [MapPost] {
        var posts: [MapPost] = []
        for memberAnno in cluster.memberAnnotations {
            if let member = memberAnno as? PostAnnotation, let post = mapData!.postsDictionary[member.postID] {
                posts.append(post)
            }
        }
        return mapController!.mapView.sortPosts(posts)
    }
    
    func setInitialRegion() {
        let coordinates = postsList.map({$0.coordinate})
        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapController?.mapView.setRegion(region, animated: false)
        mapController?.mapView.setOffsetRegion(region: region, offset: -200, animated: false)
        centeredMap = true
    }
    
    func closeDrawer() {
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .Bottom) }
        /* if refresh == .refreshEnabled {
            refresh = .activelyRefreshing
            /// should refresh only if large change from previous search region
            DispatchQueue.global(qos: .userInitiated).async { self.getNearbyPosts() }
        } */
    }
}

extension CustomMapController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Finger swipes up y translation < 0
        // Finger swipes down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y

        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user finger swipe direction
        // Status is top and content is top
        if containerDrawerView == nil { return }
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            collectionView.contentOffset.y <= topYContentOffset!
        {
            // Reset drawer view varaiables when user finger swipes down
            if yTranslation > 0 {
                containerDrawerView?.canDrag = true
                barBackButton.isHidden = true
                containerDrawerView?.swipeToNextState = true
            }
        }

        // Preventing the drawer view to be dragged when it's status is top but content is not on top and user finger is swiping up
        if
            topYContentOffset != nil &&
            containerDrawerView?.status == .Top &&
            collectionView.contentOffset.y > topYContentOffset! &&
            yTranslation < 0
        {
            containerDrawerView?.canDrag = false
            containerDrawerView?.swipeToNextState = false
            containerDrawerView?.slideView.frame.origin.y = 0
        }

        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension CustomMapController: SpotMapViewDelegate {
    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append(mapData!.postsDictionary[id]!) }
        DispatchQueue.main.async { self.openPost(posts: posts, row: 0) }
    }
    
    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }
        
    func openPostFromFriendsPost(view: FriendPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs { posts.append(mapData!.postsDictionary[id]!) }
        DispatchQueue.main.async { self.openPost(posts: posts, row: 0) }
    }
    
    func centerMapOnPostsInCluster(view: FriendPostAnnotationView) {
        closeDrawer()

        var coordinates: [CLLocationCoordinate2D] = []
        for id in view.postIDs {
            if let post = mapData!.postsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false)
        DispatchQueue.main.async {
            self.mapController?.mapView.setRegion(region, animated: true)
        }
    }
}
