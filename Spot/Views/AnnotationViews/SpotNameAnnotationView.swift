//
//  SpotNameAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class SpotNameAnnotationView: MKAnnotationView {
    var id = ""
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .rectangle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(spotID: String, spotName: String) {
        let infoWindow = SpotNameView.instanceFromNib() as! SpotNameView
        let attributes: [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.strokeColor: UIColor.white,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.strokeWidth: -3,
            NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 14.5)!
        ]
        infoWindow.spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
        infoWindow.spotLabel.sizeToFit()
        infoWindow.resizeView()

        image = infoWindow.asImage()
    }
}
