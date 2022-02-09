//
//  SinglePostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import FirebaseUI

class SinglePostAnnotationView: MKAnnotationView {
    
    lazy var id: String = ""
    lazy var imageManager = SDWebImageManager()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    func updateImage(post: MapPost) {
        
        let nibView = loadNib()
        id = post.id ?? ""
        guard let url = URL(string: post.imageURLs.first ?? "") else { image = nibView.asImage(); return }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 50), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
            guard let self = self else { return }
            
            nibView.postImage.image = image
            self.image = nibView.asImage()
        }
    }
    
    func loadNib() -> SinglePostWindow {
        let infoWindow = SinglePostWindow.instanceFromNib() as! SinglePostWindow
        infoWindow.clipsToBounds = true
        infoWindow.postImage.contentMode = .scaleAspectFill
        infoWindow.postImage.clipsToBounds = true
        infoWindow.postImage.layer.cornerRadius = 8
        return infoWindow
    }
    
    override func prepareForReuse() {
        imageManager.cancelAll()
        image = nil
    }
}
