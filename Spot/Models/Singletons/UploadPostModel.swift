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
    
    var selectedTag = ""
    var sortedTags: [Tag] = []
    
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
        sortedTags = tags().shuffled()
    }
    
    func selectObject(imageObject: ImageObject, selected: Bool) {
        
        if let i = imageObjects.firstIndex(where: {$0.image.id == imageObject.id}) {
            imageObjects[i].selected = selected
            if !selected { imageObjects[i].image.animationImages.removeAll(); imageObjects[i].image.gifMode = false }
        } 
        
        if selected { selectedObjects.append(imageObject) } else {
            selectedObjects.removeAll(where: {$0.id == imageObject.id})
        }
    }
    
    func setSpotValues() {
        let spot = spotObject!
        postObject.createdBy = spot.founderID
        postObject.privacyLevel = spot.privacyLevel
        postObject.spotLat = spot.spotLat
        postObject.spotLong = spot.spotLong
        postObject.spotName = spot.spotName
        postObject.spotPrivacy = spot.privacyLevel
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
        if spotObject != nil && !mapObject!.spotIDs.contains(spotObject!.id!) { mapObject!.spotIDs.append(spotObject!.id!) }
        mapObject!.postLocations.append(["lat": postObject.postLat, "long": postObject.postLong])
        
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

    let tags = {
            /// Activity
           [Tag(name: "Music"),
            Tag(name: "Art"),
            Tag(name: "Active"),
            Tag(name: "Boat"),
            Tag(name: "Fish"),
            Tag(name: "Surf"),

            Tag(name: "Boogie"),
            Tag(name: "History"),
            Tag(name: "Bike"),
            Tag(name: "Skate"),
            Tag(name: "Basketball"),
            Tag(name: "Golf"),

            Tag(name: "Cards"),
            Tag(name: "Shop"),
            Tag(name: "Camp"),
            Tag(name: "View"),
            Tag(name: "Tennis"),
            Tag(name: "Swim"),

            Tag(name: "Carnival"),
            Tag(name: "Garden"),
            Tag(name: "Books"),
            Tag(name: "Ski"),
            Tag(name: "Billiards"),
            Tag(name: "Race"),
            
            /// Eat & Drink
            Tag(name: "Cocktail"),
            Tag(name: "Drink"),
            Tag(name: "Coffee"),
            Tag(name: "Donut"),
            Tag(name: "Cream"),
            Tag(name: "Cake"),

            Tag(name: "Liquor"),
            Tag(name: "Wine"),
            Tag(name: "Tea"),
            Tag(name: "Eat"),
            Tag(name: "Pizza"),
            Tag(name: "Taco"),

            Tag(name: "Bread"),
            Tag(name: "Cook"),
            Tag(name: "Egg"),
            Tag(name: "Fries"),
            Tag(name: "Burger"),
            Tag(name: "Glizzy"),

            Tag(name: "Carrot"),
            Tag(name: "Honey"),
            Tag(name: "Meat"),
            Tag(name: "Salad"),
            Tag(name: "Strawberry"),
            Tag(name: "Sushi"),
            
            /// Life
            Tag(name: "Alien"),
            Tag(name: "Castle"),
            Tag(name: "Suitcase"),
            Tag(name: "Train"),
            Tag(name: "Plane"),
            Tag(name: "Car"),

            Tag(name: "Weird"),
            Tag(name: "Home"),
            Tag(name: "Skyscraper"),
            Tag(name: "Bodega"),
            Tag(name: "Toilet"),
            Tag(name: "Gas"),
            
            Tag(name: "Cig"),
            Tag(name: "Smoke"),
            Tag(name: "Pills"),
            Tag(name: "Money"),
            Tag(name: "Chill"),
            Tag(name: "Siren"),
            
            Tag(name: "NSFW"),
            Tag(name: "Casino"),
            Tag(name: "Heels"),
            Tag(name: "Pirate"),
            Tag(name: "Danger"),
            Tag(name: "Reaper"),

            /// nature
            Tag(name: "Flower"),
            Tag(name: "Log"),
            Tag(name: "Park"),
            Tag(name: "Dog"),
            Tag(name: "Cat"),
            Tag(name: "Cow"),
            
            Tag(name: "Umbrella"),
            Tag(name: "Leaf"),
            Tag(name: "Nature"),
            Tag(name: "Bug"),
            Tag(name: "Bird"),
            Tag(name: "Bear"),

            Tag(name: "Rainbow"),
            Tag(name: "Moon"),
            Tag(name: "Snow"),
            Tag(name: "Monkey"),
            Tag(name: "Snake"),
            Tag(name: "Whale"),
            
            Tag(name: "Cactus"),
            Tag(name: "Mountain"),
            Tag(name: "Sunset"),
            Tag(name: "Tropical"),
            Tag(name: "Star"),
            Tag(name: "Cityset")
        ]
    }
    
    func allAuths() -> Bool {
        return cameraAccess == .authorized &&  (galleryAccess == .authorized || galleryAccess == .limited)
    }
    
    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        nearbySpots.removeAll()
        friendObjects.removeAll()
        selectedTag = ""
        assetsFull = nil
        tappedLocation = CLLocation()
        
        postObject = nil
        spotObject = nil
        mapObject = nil
    }
}
