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
    let rawLocation: CLLocation
    var stillImage: UIImage
    let creationDate: Date
    var fromCamera: Bool

    init(image: UIImage, fromCamera: Bool) {
        id = UUID().uuidString
        asset = PHAsset()
        rawLocation = UserDataModel.shared.currentLocation
        stillImage = image
        creationDate = Date()
        self.fromCamera = fromCamera
    }

    init(id: String, asset: PHAsset, rawLocation: CLLocation, stillImage: UIImage, creationDate: Date, fromCamera: Bool) {
        self.id = id
        self.asset = asset
        self.rawLocation = rawLocation
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
    let rawLocation: CLLocation
    let creationDate: Date
    var fromCamera: Bool

    init(url: URL, fromCamera: Bool) {
        id = UUID().uuidString
        asset = PHAsset()
        thumbnailImage = url.getThumbnail()
        videoData = nil
        videoPath = url
        rawLocation = UserDataModel.shared.currentLocation
        creationDate = Date()
        self.fromCamera = fromCamera
    }

    init(id: String, asset: PHAsset, thumbnailImage: UIImage, videoData: Data?, videoPath: URL, rawLocation: CLLocation, creationDate: Date, fromCamera: Bool) {
        self.id = id
        self.asset = asset
        self.thumbnailImage = thumbnailImage
        self.videoData = videoData
        self.videoPath = videoPath
        self.rawLocation = rawLocation
        self.creationDate = creationDate
        self.fromCamera = fromCamera
    }
}
