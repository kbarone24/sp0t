//
//  PostClusterView.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import FirebaseUI
import Photos

class PostClusterView: MKAnnotationView {
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".CustomClusterView"
    
    var topPostID = ""
    var imageManager: SDWebImageManager!
    var nibImage: UIImage!
    
    var galleryManager: PHCachingImageManager!
    var requestID: Int32 = 0
    lazy var imageObjects: [ImageObject] = []
    
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .rectangle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        
        super.prepareForDisplay()
        
        /// return when not using in map picker
        if topPostID != "" { return }
        let nibView = loadNib()
        
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let anno0 = clusterAnnotation.memberAnnotations.first
            if let obj = imageObjects.last(where: {$0.rawLocation.coordinate.latitude == anno0!.coordinate.latitude && $0.rawLocation.coordinate.longitude == anno0!.coordinate.longitude}) {
                DispatchQueue.global(qos: .default).async {
                    
                    self.loadGalleryAnnotationImage(object: obj) { (image) in
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            nibView.galleryImage.image = image
                            nibView.count.text = String(clusterAnnotation.memberAnnotations.count)
                            nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                            let nibImage = nibView.asImage()
                            self.image = nibImage
                            self.isHidden = false
                        }
                    }
                }
                
            } else {
                self.isHidden = false
                nibView.galleryImage.image = UIImage()
                nibView.count.text = String(clusterAnnotation.memberAnnotations.count)
                nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                let nibImage = nibView.asImage()
                self.image = nibImage
            }
            
        } else {
            self.isHidden = false
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
        }
    }
        
    func updateImage(imageObjects: [ImageObject]) {
        
        /// set cluster to blank image to ensure clusters are spaced apart correctly
        self.imageObjects = imageObjects
        self.image = UIImage(named: "InfoWindowBackground")
        self.isHidden = true
    }
    
    func updateImage(posts: [MapPost], count: Int) {
        let nibView = loadNib()
        
        if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let anno0 = clusterAnnotation.memberAnnotations.first
            if let topPost = posts.first(where: {$0.postLat == anno0!.coordinate.latitude && $0.postLong == anno0!.coordinate.longitude}) {
                
                self.topPostID = topPost.id ?? ""
                loadPostAnnotationImage(post: topPost) { [weak self] (image) in
                    guard let self = self else { return }

                    nibView.galleryImage.image = image
                    
                    nibView.count.text = String(count)
                    nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                    let nibImage = nibView.asImage()
                    self.image = nibImage
                }
            } else {
                nibView.count.text = String(count)
                nibView.count.backgroundColor = UIColor(patternImage: UIImage(named: "InfoWindowCountBackground")!)
                nibView.galleryImage.image = UIImage()
                let nibImage = nibView.asImage()
                self.image = nibImage
            }
        } else {
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
        }
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        imageManager = SDWebImageManager()
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
    
        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func loadGalleryAnnotationImage(object: ImageObject, completion: @escaping (_ image: UIImage) -> Void) {
        
        galleryManager = PHCachingImageManager()
        let baseSize = CGSize(width: 49, height: 34)

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        requestID = self.galleryManager.requestImage(for: object.asset, targetSize: baseSize, contentMode: .aspectFill, options: options) { [weak self] (result, info) in
            guard self != nil else { return }
            if result != nil {
                completion(result!)
            } else { completion(UIImage()) }
        }
    }
    
    func cancelImage() {
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID) }
    }
    
    func loadNib() -> MarkerInfoWindow {
        let infoWindow = MarkerInfoWindow.instanceFromNib() as! MarkerInfoWindow
        
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.layer.cornerRadius = 3
        infoWindow.galleryImage.clipsToBounds = true
        
        infoWindow.count.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        infoWindow.count.textColor = .black
        infoWindow.count.textAlignment = .center
        infoWindow.count.clipsToBounds = true
        let attText = NSAttributedString(string: (infoWindow.count.text)!, attributes: [NSAttributedString.Key.kern: -0.2])
        infoWindow.count.attributedText = attText
        
        infoWindow.bringSubviewToFront(infoWindow.count)
        
        return infoWindow
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID); galleryManager = nil }
        if image != nil { image = UIImage() }
    }
}
