//
//  StandardPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos
import MapKit
import FirebaseUI

class MapPickerAnnotationView: MKAnnotationView {
    
    var galleryImage: UIImage!
    var asset: PHAsset!
    var spotID = ""
    
    var imageManager: SDWebImageManager!
    var galleryManager: PHCachingImageManager!
    var requestID: Int32 = 0
    var imageObject: ImageObject!
    
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".CustomAnnotationView"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = MapPickerAnnotationView.preferredClusteringIdentifier
        collisionMode = .rectangle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        willSet {
            clusteringIdentifier = MapPickerAnnotationView.preferredClusteringIdentifier
        }
    }
        
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        galleryManager = PHCachingImageManager()
        let nibView = loadPostNib()
           
        DispatchQueue.global(qos: .default).async {
            
            if self.imageObject == nil { return }
            self.loadGalleryAnnotationImage(object: self.imageObject) { [weak self] (image) in
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isHidden = false
                    if image == UIImage() { return }
                    
                    nibView.galleryImage.image = image
                    nibView.count.isHidden = true
                    
                    let nibImage = nibView.asImage()
                    self.image = nibImage
                }
                
            }
        }
    }
    
    func updateImage(post: MapPost) {
                
        imageManager = SDWebImageManager()
        let nibView = loadPostNib()
        
        loadPostAnnotationImage(post: post) { [weak self] (image) in
            guard let self = self else { return }
            
            nibView.galleryImage.image = image
            nibView.count.isHidden = true
            let nibImage = nibView.asImage()
            self.image = nibImage
            self.isEnabled = true
        }
    }
    
    func updateImage(object: ImageObject) {
        
        self.imageObject = object
        self.image = UIImage(named: "InfoWindowBackground")
        self.isHidden = true
    }
    
    func loadPostNib() -> MarkerInfoWindow {
        
        let infoWindow = MarkerInfoWindow.instanceFromNib() as! MarkerInfoWindow
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.layer.cornerRadius = 3
        infoWindow.galleryImage.clipsToBounds = true
        
        infoWindow.count.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        infoWindow.count.textColor = .black
        let attText = NSAttributedString(string: (infoWindow.count.text)!, attributes: [NSAttributedString.Key.kern: 0.8])
        infoWindow.count.attributedText = attText
        infoWindow.count.textAlignment = .center
        infoWindow.count.clipsToBounds = true
        
        return infoWindow
    }
    
    func loadGalleryAnnotationImage(object: ImageObject, completion: @escaping (_ image: UIImage) -> Void) {
        let baseSize = CGSize(width: 49, height: 34)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        requestID = galleryManager.requestImage(for: object.asset, targetSize: baseSize, contentMode: .aspectFill, options: options) { (result, info) in
            if result != nil {
                completion(result!)
            } else { completion(UIImage()) }
        }
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
        if imageManager == nil { imageManager = SDWebImageManager() }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func cancelImage() {
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID) }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if galleryManager != nil { galleryManager.cancelImageRequest(self.requestID); galleryManager = nil }
        if galleryImage != nil { galleryImage = UIImage() }
        if image != nil { image = nil }
    }
}

