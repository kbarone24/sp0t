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
        centerOffset = CGPoint(x: 0, y: 10)
        displayPriority = .defaultHigh
        alpha = 1.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(spotID: String, spotName: String, priority: Float) {
        self.id = spotID
        self.spotName = spotName
        self.displayPriority = .init(rawValue: priority)
        let infoWindow = SpotNameView.instanceFromNib() as! SpotNameView
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.strokeColor: UIColor.white,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.strokeWidth: -3,
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 14)!
        ]
        infoWindow.spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
        infoWindow.spotLabel.sizeToFit()
        infoWindow.resizeView()

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