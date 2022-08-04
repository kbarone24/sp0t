//
//  MapPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 8/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import FirebaseUI

class SpotPostAnnotationView: MKAnnotationView {
    var id = ""
    lazy var imageManager = SDWebImageManager()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
        centerOffset = CGPoint(x: 0, y: -20)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(post: MapPost?, spotName: String, id: String) {
        self.id = id
        let nibView = loadNib(post: post, spotName: spotName)
        self.image = nibView.asImage()

        if post != nil {
            guard let url = URL(string: post!.imageURLs.first ?? "") else { image = nibView.asImage(); return }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard let self = self else { return }
                nibView.postImage.image = image
                self.image = nibView.asImage()
            }
        }
    }
    
    func loadNib(post: MapPost?, spotName: String) -> SpotPostView {
        let infoWindow = SpotPostView.instanceFromNib() as! SpotPostView
        infoWindow.clipsToBounds = false
        infoWindow.backgroundImage.image = post!.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = 57/2
        
        if spotName != "" {
            /// bordered text
            let attributes: [NSAttributedString.Key : Any] = [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3,
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 14.5)!
            ]
            infoWindow.spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
            infoWindow.spotLabel.sizeToFit()

        } else {
            /// no spot attached to this post
            infoWindow.spotLabel.isHidden = true
        }
        
        infoWindow.resizeView()
        return infoWindow
    }
}

class SpotPostAnnotation: MKPointAnnotation {
    var id = ""
    override init() {
        super.init()
    }
}
