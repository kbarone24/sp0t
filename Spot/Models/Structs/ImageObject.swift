//
//  ImageObject.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Photos

struct ImageObject {
    let id: String
    let asset: PHAsset
    let rawLocation: CLLocation
    var stillImage: UIImage
    var animationImages: [UIImage]
    var animationIndex: Int
    var directionUp: Bool
    var gifMode: Bool
    let creationDate: Date
    var fromCamera: Bool
}

