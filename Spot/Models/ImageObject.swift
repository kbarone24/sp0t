//
//  ImageObject.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Foundation
import Photos
import UIKit

struct ImageObject {
    let id: String
    let asset: PHAsset
    let coordinate: CLLocationCoordinate2D
    var stillImage: UIImage
    let creationDate: Date
    var fromCamera: Bool

    init(image: UIImage, coordinate: CLLocationCoordinate2D, fromCamera: Bool) {
        id = UUID().uuidString
        asset = PHAsset()
        self.coordinate = coordinate
        stillImage = image
        creationDate = Date()
        self.fromCamera = fromCamera
    }

    init(id: String, asset: PHAsset, coordinate: CLLocationCoordinate2D, stillImage: UIImage, creationDate: Date, fromCamera: Bool) {
        self.id = id
        self.asset = asset
        self.coordinate = coordinate
        self.stillImage = stillImage
        self.creationDate = creationDate
        self.fromCamera = fromCamera
    }
}

struct VideoObject {
    let id: String
    let asset: PHAsset
    let thumbnailImage: UIImage
    let videoData: Data?
    let videoPath: URL
    let coordinate: CLLocationCoordinate2D
    let creationDate: Date
    var fromCamera: Bool

    init(url: URL, coordinate: CLLocationCoordinate2D, fromCamera: Bool) {
        id = UUID().uuidString
        asset = PHAsset()
        thumbnailImage = url.getThumbnail()
        videoData = nil
        videoPath = url
        self.coordinate = coordinate
        creationDate = Date()
        self.fromCamera = fromCamera
    }

    init(id: String, asset: PHAsset, thumbnailImage: UIImage, videoData: Data?, videoPath: URL, coordinate: CLLocationCoordinate2D, creationDate: Date, fromCamera: Bool) {
        self.id = id
        self.asset = asset
        self.thumbnailImage = thumbnailImage
        self.videoData = videoData
        self.videoPath = videoPath
        self.coordinate = coordinate
        self.creationDate = creationDate
        self.fromCamera = fromCamera
    }
}
