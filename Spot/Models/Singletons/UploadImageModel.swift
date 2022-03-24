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
    var selectedObjects: [ImageObject] = []
    var imageObjects: [(image: ImageObject, selected: Bool)] = []
    var scrollObjects: [ImageObject] = []
    
    var nearbySpots: [MapSpot] = []
    var friendObjects: [UserProfile] = []
    
    var selectedTag = ""
    var sortedTags: [Tag] = []
    
    var cameraAccess: AVAuthorizationStatus = .notDetermined
    var galleryAccess: PHAuthorizationStatus = .notDetermined
    
    var tappedLocation: CLLocation!
    static let shared = UploadImageModel()
    
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
    
    func resortSpots(coordinate: CLLocationCoordinate2D) {
        
        for i in 0...nearbySpots.count - 1 {
            
            let spot = UploadImageModel.shared.nearbySpots[i]
            let spotLocation = CLLocation(latitude: spot.spotLat, longitude: spot.spotLong)
            let postLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            nearbySpots[i].spotScore = spot.getSpotRank(location: postLocation)
            nearbySpots[i].distance = postLocation.distance(from: spotLocation)            
        }
        
        nearbySpots.removeAll(where: {$0.distance > 20000})
        nearbySpots.sort(by: { !$0.selected! && !$1.selected! ? $0.spotScore > $1.spotScore : $0.selected! && !$1.selected! })
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
        return UploadImageModel.shared.cameraAccess == .authorized &&  UploadImageModel.shared.galleryAccess == .authorized 
    }
    
    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        scrollObjects.removeAll()
        nearbySpots.removeAll()
        friendObjects.removeAll()
        selectedTag = ""
        assetsFull = nil
        tappedLocation = CLLocation()
    }
}
