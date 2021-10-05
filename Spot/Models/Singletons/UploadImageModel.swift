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
    lazy var nearbySpots: [MapSpot] = []
    lazy var friendObjects: [UserProfile] = [] 
    
    var cameraAccess: AVAuthorizationStatus = .notDetermined
    var micAccess: AVAudioSession.RecordPermission = .undetermined
    var galleryAccess: PHAuthorizationStatus = .notDetermined
    
    var tappedLocation: CLLocation!
    static let shared = UploadImageModel()
    
    init() {
        cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
        micAccess = AVAudioSession.sharedInstance().recordPermission
        galleryAccess = PHPhotoLibrary.authorizationStatus()
        tappedLocation = CLLocation()
    }
    
    func selectObject(imageObject: ImageObject, selected: Bool) {
        
        if let i = imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            imageObjects[i].selected = selected
        } 
        
        if selected { selectedObjects.append(imageObject) } else { selectedObjects.removeAll(where: {$0.id == imageObject.id}) }
    }
    
    func allAuths() -> Bool {
        return UploadImageModel.shared.cameraAccess == .authorized && UploadImageModel.shared.micAccess == .granted && UploadImageModel.shared.galleryAccess == .authorized 
    }
    
    func destroy() {
        nearbySpots.removeAll()
        selectedObjects.removeAll()
        imageObjects.removeAll()
        friendObjects.removeAll()
        assetsFull = nil
    }
}
