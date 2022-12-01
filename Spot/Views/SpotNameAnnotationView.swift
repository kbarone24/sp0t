//
//  SpotNameAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import MapKit
import UIKit

class SpotNameAnnotationView: MKAnnotationView {
    var id = ""
    var spotName = ""
    unowned var mapView: MKMapView?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .rectangle
        clusteringIdentifier = nil
        displayPriority = .defaultHigh
        alpha = 1.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(spotID: String, spotName: String, poiCategory: POICategory?, priority: Float) {
        self.id = spotID
        self.spotName = spotName
        self.displayPriority = .init(rawValue: priority)
        guard let infoWindow = SpotNameView.instanceFromNib() as? SpotNameView else { return }
        infoWindow.setUp(spotName: spotName, poiCategory: poiCategory)
        image = infoWindow.asImage()
    }

    func addTap() {
        /// prevent map lag on selection
        let tap = UITapGestureRecognizer()
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        addGestureRecognizer(tap)
    }

}

extension SpotNameAnnotationView: UIGestureRecognizerDelegate {

    func toggleZoom() {
        mapView?.isZoomEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.mapView?.isZoomEnabled = true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        toggleZoom()
        return false
    }
}
