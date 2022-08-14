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
    var postIDs: [String] = []
    
    lazy var imageManager = SDWebImageManager()
    unowned var mapView: MKMapView?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
        centerOffset = CGPoint(x: 0, y: -20)
        addTap()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(posts: [MapPost], spotName: String, id: String) {
        self.id = id
        postIDs = posts.map({$0.id!})
        let post = posts.first
        
        if post != nil {
            let nibView = loadNib(post: post!, spotName: spotName)
            self.image = nibView.asImage()

            guard let url = URL(string: post!.imageURLs.first ?? "") else { image = nibView.asImage(); return }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard let self = self else { return }
                nibView.postImage.image = image
                self.image = nibView.asImage()
            }
        }
    }
    
    func loadNib(post: MapPost, spotName: String) -> SpotPostView {
        let infoWindow = SpotPostView.instanceFromNib() as! SpotPostView
        infoWindow.clipsToBounds = false
        infoWindow.backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = 57/2
        
        infoWindow.imageMask.layer.cornerRadius = 57/2
        infoWindow.imageMask.isHidden = !post.seen
        infoWindow.replayIcon.isHidden = !post.seen
        
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
            infoWindow.spotIcon.isHidden = true
        }
        
        infoWindow.resizeView()
        return infoWindow
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

extension SpotPostAnnotationView: UIGestureRecognizerDelegate {

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

class SpotPostAnnotation: MKPointAnnotation {
    var id = ""
    override init() {
        super.init()
    }
}
