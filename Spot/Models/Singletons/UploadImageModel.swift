//
//  UploadImageModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/12/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Photos

class UploadImageModel {
    
    var assetsFull: PHFetchResult<PHAsset>!
    lazy var selectedObjects: [ImageObject] = []
    lazy var imageObjects: [(image: ImageObject, selected: Bool)] = []
    lazy var scrollObjects: [ImageObject] = []
    
    lazy var nearbySpots: [MapSpot] = []
    lazy var friendObjects: [UserProfile] = []
    
    var cameraAccess: AVAuthorizationStatus = .notDetermined
    var galleryAccess: PHAuthorizationStatus = .notDetermined
    
    var tappedLocation: CLLocation!
    static let shared = UploadImageModel()
    
    init() {
        cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
        galleryAccess = PHPhotoLibrary.authorizationStatus()
        tappedLocation = CLLocation()
    }
    
    func selectObject(imageObject: ImageObject, selected: Bool) {
        
        if let i = imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            imageObjects[i].selected = selected
        } 
        
        if selected { selectedObjects.append(imageObject) } else { selectedObjects.removeAll(where: {$0.id == imageObject.id}) }
    }
    
    func resortSpots(coordinate: CLLocationCoordinate2D) {
        
        for i in 0...nearbySpots.count - 1 {
            
            let spot = UploadImageModel.shared.nearbySpots[i]
            let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
            let postLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            nearbySpots[i].spotScore = spot.getSpotRank(location: postLocation)
            nearbySpots[i].distance = postLocation.distance(from: spotLocation)            
        }
        
        nearbySpots.removeAll(where: {$0.distance > 30000})
        nearbySpots.sort(by: { !$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected! })
    }

    
    func allAuths() -> Bool {
        return UploadImageModel.shared.cameraAccess == .authorized &&  UploadImageModel.shared.galleryAccess == .authorized 
    }
    
    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        scrollObjects.removeAll()
        nearbySpots.removeAll()
        friendObjects.removeAll()
        assetsFull = nil
    }
}
