//
//  CustomPointAnnotation.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Photos

class CustomPointAnnotation: MKPointAnnotation {
    
  //  lazy var imageURL: String = ""
    lazy var asset: PHAsset = PHAsset()
    var hidden = false
    var assetID: String = ""
    var postID: String = ""
    
    override init() {
        super.init()
    }
}

extension UIView {
    
    // render nib view as an image to use with annotation view
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

class MapPickerTap: UITapGestureRecognizer {
    var coordinates = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
}
