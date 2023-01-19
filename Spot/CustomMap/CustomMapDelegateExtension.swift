//
//  CustomMapDelegateExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit
import UIKit

extension CustomMapController: MKMapViewDelegate {
    @objc func notifyPostOpen(_ notification: NSNotification) {
        // update post annotation as seen
        guard let post = notification.userInfo?.first?.value as? MapPost else { return }
        guard let mapVC = mapController else { return }

        self.mapData?.updateSeen(postID: post.id ?? "")

        if let coordinate = mapData?.postsDictionary[post.id ?? ""]?.coordinate,
            let annotation = mapVC.mapView.annotations.first(where: { $0.coordinate.isEqualTo(coordinate: coordinate) }) {
            DispatchQueue.main.async {
                mapVC.mapView.removeAnnotation(annotation)
                mapVC.mapView.addAnnotation(annotation)
            }
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let mapView = mapView as? SpotMapView else { return MKAnnotationView() }

        if let anno = annotation as? SpotAnnotation {
            // set up spot post view with 1 post
            return mapView.getSpotAnnotation(anno: anno, selectedMap: mapData)

        } else if let anno = annotation as? MKClusterAnnotation {
            if anno.memberAnnotations.contains(where: { $0 is SpotAnnotation }) {
                return mapView.getSpotClusterAnnotation(anno: anno, selectedMap: mapData)
            }
        }
        return MKAnnotationView()
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        if centeredMap && containerDrawerView?.status == .middle { closeDrawer() }
        guard let mapView = mapView as? SpotMapView else { return }
        // gets called too much -> just use gesture recognizer
        if mapView.region.span.longitudeDelta < 0.001_3 {
            if mapView.shouldCluster {
                mapView.shouldCluster = false
                let annotations = mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    mapView.addAnnotations(annotations)
                }
            }
        } else {
            if !mapView.shouldCluster {
                mapView.shouldCluster = true
                let annotations = mapView.annotations
                DispatchQueue.main.async {
                    mapView.removeAllAnnos()
                    mapView.addAnnotations(annotations)
                }
            }
        }
    }

    func setInitialRegion() {
        let coordinates = postsList.map({ $0.coordinate })
        let region = MKCoordinateRegion(coordinates: coordinates, overview: true)
        mapController?.mapView.setRegion(region, animated: false)
        mapController?.mapView.setOffsetRegion(region: region, offset: -200, animated: false)
        centeredMap = true
    }

    func closeDrawer() {
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .bottom) }
    }
}

extension CustomMapController: UIGestureRecognizerDelegate {
    @objc func onPan(_ recognizer: UIPanGestureRecognizer) {
        // Finger swipes up y translation < 0
        // Finger swipes down y translation > 0
        let yTranslation = recognizer.translation(in: recognizer.view).y
     //   guard containerDrawerView?.slideView.frame.minY ?? 0 == 0 else { return }

        // Enter full screen then enable collection view scrolling and determine if need drawer view swipe to next state feature according to user finger swipe direction
        // Status is top and content is top
        if containerDrawerView == nil { return }
        if let topY = topYContentOffset {
                if containerDrawerView?.status == .top && collectionView.contentOffset.y <= topY {
                // Reset drawer view varaiables when user finger swipes down
                if yTranslation > 0 {
                    containerDrawerView?.canDrag = true
                    barBackButton.isHidden = true
                    containerDrawerView?.swipeToNextState = true
                }
            }

            // Preventing the drawer view to be dragged when it's status is top but content is not on top and user finger is swiping up
            if
                containerDrawerView?.slideView.frame.minY == 0 &&
                collectionView.contentOffset.y > topY &&
                yTranslation < 0
            {
                containerDrawerView?.canDrag = false
                containerDrawerView?.swipeToNextState = false
            //    containerDrawerView?.slideView.frame.origin.y = 0
            }
        }

        // Need to prevent content in collection view being scrolled when the status of drawer view is top but frame.minY is not 0
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension CustomMapController: SpotMapViewDelegate {
    func openSpotFromSpotName(view: SpotNameAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }

    func openPostFromSpotPost(view: SpotPostAnnotationView) {
        var posts: [MapPost] = []
        for id in view.postIDs {
            if let post = mapData?.postsDictionary[id] { posts.append(post) }
        }
        DispatchQueue.main.async { self.openPost(posts: posts, row: 0) }
    }

    func openSpotFromSpotPost(view: SpotPostAnnotationView) {
        openSpot(spotID: view.id, spotName: view.spotName)
    }

    func centerMapOnPostsInCluster(view: SpotPostAnnotationView) {
        closeDrawer()

        var coordinates: [CLLocationCoordinate2D] = []
        for id in view.postIDs {
            if let post = mapData?.postsDictionary[id] { coordinates.append(post.coordinate) }
        }
        let region = MKCoordinateRegion(coordinates: coordinates, overview: false)
        DispatchQueue.main.async {
            self.mapController?.mapView.setRegion(region, animated: true)
        }
    }
}
