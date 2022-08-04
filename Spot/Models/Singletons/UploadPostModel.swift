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
import Mixpanel

class UploadPostModel {
    
    var assetsFull: PHFetchResult<PHAsset>!
    var selectedObjects: [ImageObject] = []
    var imageObjects: [(image: ImageObject, selected: Bool)] = []
    
    var postObject: MapPost!
    var spotObject: MapSpot?
    var mapObject: CustomMap?
    
    var postType: PostType = .none
    
    var nearbySpots: [MapSpot] = []
    var friendObjects: [UserProfile] = []
    
    var cameraAccess: AVAuthorizationStatus = .notDetermined
    var galleryAccess: PHAuthorizationStatus = .notDetermined
    
    var tappedLocation: CLLocation!
    static let shared = UploadPostModel()
    
    enum PostType {
        case none
        case postToPOI
        case postToSpot
        case newSpot
    }

    init() {
        cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
        galleryAccess = PHPhotoLibrary.authorizationStatus()
        tappedLocation = CLLocation()
    }
    
    func selectObject(imageObject: ImageObject, selected: Bool) {
        Mixpanel.mainInstance().track(event: "GallerySelectImage", properties: ["selected": selected])
        if let i = imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            imageObjects[i].selected = selected
            if !selected { imageObjects[i].image.animationImages.removeAll(); imageObjects[i].image.gifMode = false }
        } 
        
        if selected { selectedObjects.append(imageObject) } else {
            selectedObjects.removeAll(where: {$0.id == imageObject.id})
        }
    }
    
    func setSpotValues(spot: MapSpot?) {
        spotObject = spot
        if spot != nil { spotObject!.selected = true }
        postType = spot == nil ? .none : spot!.founderID == "" ? .postToPOI : .postToSpot
        
        postObject.createdBy = spot?.founderID ?? ""
        postObject.spotID = spot?.id ?? ""
        postObject.spotLat = spot?.spotLat ?? 0.0
        postObject.spotLong = spot?.spotLong ?? 0.0
        postObject.spotName = spot?.spotName ?? ""
        postObject.spotPrivacy = spot?.privacyLevel ?? ""
    }
    
    func resortSpots(coordinate: CLLocationCoordinate2D) {
        
        for i in 0...nearbySpots.count - 1 {
            
            let spot = nearbySpots[i]
            let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
            let postLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            nearbySpots[i].spotScore = spot.getSpotRank(location: postLocation)
            nearbySpots[i].distance = postLocation.distance(from: spotLocation)            
        }
        
        nearbySpots.removeAll(where: {$0.distance > 20000})
        nearbySpots.sort(by: { !$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected! })
    }
    
    func setPostCity() {
        reverseGeocodeFromCoordinate() { [weak self] (city) in
            guard let self = self else { return }
            self.postObject.city = city
        }
    }
    
    func setTaggedUsers() {
        var selectedUsers: [UserProfile] = []
        let words = postObject.caption.components(separatedBy: .whitespacesAndNewlines)
        
        for w in words {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append(f)
                }
            }
        }
        let usernames = selectedUsers.map({$0.username})
        postObject.taggedUsers = usernames
        postObject.addedUsers = selectedUsers.map({$0.id!})
        postObject.taggedUserIDs = selectedUsers.map({$0.id!})
    }
    
    func reverseGeocodeFromCoordinate(completion: @escaping (_ address: String) -> Void) {
        
        var addressString = ""
        let location = CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)
        
        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, error in // 6
            
            if self == nil { completion(""); return }
            
            guard let placemark = placemarks?.first else {
                print("placemark broke")
                return
            }
            
            if placemark.locality != nil {
                if addressString != "" {
                    addressString = addressString + ", "
                }
                addressString = addressString + placemark.locality!
            }
            
            if placemark.country != nil {
                if placemark.country! == "United States" {
                    if placemark.administrativeArea != nil {
                        if addressString != "" {
                            addressString = addressString + ", "
                        }
                        addressString = addressString + placemark.administrativeArea!
                        completion(addressString)
                    } else {
                        completion(addressString)
                    }
                } else {
                    if addressString != "" {
                        addressString = addressString + ", "
                    }
                    addressString = addressString + placemark.country!
                    completion(addressString)
                }
            } else {
                completion(addressString)
            }
        }
    }
    
    func setFinalPostValues() {
        var taggedProfiles: [UserProfile] = []

        let word = UploadPostModel.shared.postObject.caption.split(separator: " ")
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    UploadPostModel.shared.postObject.taggedUsers!.append(username)
                    UploadPostModel.shared.postObject.taggedUserIDs!.append(f.id!)
                    taggedProfiles.append(f)
                }
            }
        }
        
        var postFriends = postObject.privacyLevel == "invite" ? spotObject!.inviteList!.filter(UserDataModel.shared.friendIDs.contains) : UserDataModel.shared.friendIDs
        let uid = UserDataModel.shared.uid
        if !postFriends.contains(uid) { postFriends.append(uid) }
        postObject.friendsList = postFriends
        postObject.privacyLevel = spotObject != nil && spotObject?.privacyLevel == "friends" ? "friends" : "public"
    }

    func setFinalMapValues() {
        mapObject!.postIDs.append(postObject.id!)
        mapObject!.postLocations.append(["lat": postObject.postLat, "long": postObject.postLong])
        if spotObject != nil {
            if !mapObject!.spotIDs.contains(spotObject!.id!) {
                mapObject!.spotIDs.append(spotObject!.id!)
                mapObject!.spotNames.append(spotObject!.spotName)
                mapObject!.spotLocations.append(["lat": spotObject!.spotLat, "long": spotObject!.spotLong])

            }
        }

        let uid = UserDataModel.shared.uid
        var posters = [uid]
        if !(postObject.addedUsers?.isEmpty ?? true) { posters.append(contentsOf: postObject.addedUsers!) }
        mapObject!.posterDictionary[postObject.id!] = posters
        mapObject!.posterIDs.append(uid)
        mapObject!.posterUsernames.append(UserDataModel.shared.userInfo.username)
        for poster in posters {
            if !mapObject!.memberIDs.contains(poster) { mapObject!.memberIDs.append(poster) }
        }
    }

    func allAuths() -> Bool {
        return cameraAccess == .authorized &&  (galleryAccess == .authorized || galleryAccess == .limited)
    }
    
    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        nearbySpots.removeAll()
        friendObjects.removeAll()
        assetsFull = nil
        tappedLocation = CLLocation()
        
        postObject = nil
        spotObject = nil
        mapObject = nil
    }
}
