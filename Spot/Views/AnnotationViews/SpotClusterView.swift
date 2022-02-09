//
//  SpotClusterView.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import MapKit

class SpotClusterView: MKAnnotationView {
    var topSpotID = ""
    
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".SpotClusterView"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        self.canShowCallout = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // update spot banner with the top spot in the cluster
    func updateImage(annotations: [CustomSpotAnnotation]) {
        
        let nibView = loadNib()
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            var topSpot: CustomSpotAnnotation!
            
            for member in clusterAnnotation.memberAnnotations {
                if let spot = annotations.first(where: {$0.spotInfo.spotLat == member.coordinate.latitude && $0.spotInfo.spotLong == member.coordinate.longitude}) {
                    if topSpot == nil {
                        topSpot = spot
                    } else if spot.rank > topSpot.rank {
                        topSpot = spot
                    }
                }
            }
            
            if topSpot != nil {
                nibView.spotNameLabel.text = topSpot.spotInfo.spotName
                let temp = nibView.spotNameLabel
                temp?.sizeToFit()
                nibView.resizeBanner(width: temp?.frame.width ?? 0)
                let nibImage = nibView.asImage()
                self.image = nibImage
                self.topSpotID = topSpot.spotInfo.id ?? ""
            } else {
                self.image = UIImage(named: "RainbowSpotIcon")
            }
        }
    }
    
    func loadNib() -> MapTarget {
        let infoWindow = MapTarget.instanceFromNib() as! MapTarget
        infoWindow.clipsToBounds = true
        infoWindow.spotNameLabel.font = UIFont(name: "SFCompactText-Regular", size: 13)
        infoWindow.spotNameLabel.numberOfLines = 1
        infoWindow.spotNameLabel.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        
        return infoWindow
    }
}
