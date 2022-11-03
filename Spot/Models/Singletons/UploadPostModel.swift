//
//  UploadImageModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/12/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import Photos
import UIKit

final class UploadPostModel {
    var assetsFull: PHFetchResult<PHAsset>!
    var selectedObjects: [ImageObject] = []
    var imageObjects: [(image: ImageObject, selected: Bool)] = []
    var imageFromCamera = false

    var postObject: MapPost!
    var spotObject: MapSpot?
    var mapObject: CustomMap?

    var postType: PostType = .none

    var nearbySpots: [MapSpot] = []
    var friendObjects: [UserProfile] = []

    var cameraAccess: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    var galleryAccess: PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var locationAccess: Bool = false

    static let shared = UploadPostModel()

    enum PostType {
        case none
        case postToPOI
        case postToSpot
        case newSpot
    }

    func selectObject(imageObject: ImageObject, selected: Bool) {
        Mixpanel.mainInstance().track(event: "GallerySelectImage", properties: ["selected": selected])
        if let i = imageObjects.firstIndex(where: { $0.image.id == imageObject.id }) {
            imageObjects[i].selected = selected
            if !selected { imageObjects[i].image.animationImages.removeAll(); imageObjects[i].image.gifMode = false }
        }

        if selected { selectedObjects.append(imageObject) } else {
            selectedObjects.removeAll(where: { $0.id == imageObject.id })
        }
    }

    func createSharedInstance() {
        let coordinate = UserDataModel.shared.currentLocation.coordinate

        self.postObject = MapPost(
            posterUsername: UserDataModel.shared.userInfo.username,
            caption: "",
            privacyLevel: "friends",
            longitude: coordinate.longitude,
            latitude: coordinate.latitude,
            timestamp: Timestamp(date: Date())
        )

        setPostCity() /// set with every location change to avoid async lag on upload
        spotObject = nil
        mapObject = nil
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

        /// if post with no location, use spot location
        if !postObject.setImageLocation && spot != nil {
            postObject.postLat = spot!.spotLat
            postObject.postLong = spot!.spotLong
            setPostCity()
        }
    }

    func setMapValues(map: CustomMap?) {
        mapObject = map
        postObject.mapID = map?.id ?? ""
        postObject.mapName = map?.mapName ?? ""
    }

    func setPostCity() {
        reverseGeocodeFromCoordinate { [weak self] (city) in
            guard let self = self else { return }
            guard self.postObject != nil else { return }
            self.postObject.city = city
        }
    }

    func setTaggedUsers() {
        let taggedUsers = getTaggedUsers(text: postObject.caption)
        let usernames = taggedUsers.map({ $0.username })
        postObject.taggedUsers = usernames
        postObject.addedUsers = taggedUsers.map({ $0.id! })
        postObject.taggedUserIDs = taggedUsers.map({ $0.id! })
    }

    func getTaggedUsers(text: String) -> [UserProfile] {
        var selectedUsers: [UserProfile] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for w in words {
            if w.count == 0 { continue }
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == username }) {
                    selectedUsers.append(f)
                }
            }
        }
        return selectedUsers
    }

    func reverseGeocodeFromCoordinate(completion: @escaping (_ address: String) -> Void) {

        var addressString = ""
        let location = CLLocation(latitude: postObject.postLat, longitude: postObject.postLong)

        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, _ in // 6

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
        var postFriends = postObject.hideFromFeed! ? [] : UserDataModel.shared.userInfo.friendIDs
        /// if map selected && mymap selected, add friendsList
        if mapObject != nil { postObject.inviteList = mapObject!.likers }
        if !postFriends.contains(UserDataModel.shared.uid) && !postObject.hideFromFeed! { postFriends.append(UserDataModel.shared.uid) }
        postObject.friendsList = postFriends
        postObject.privacyLevel = mapObject != nil && mapObject!.secret ? "invite" : mapObject != nil && (mapObject!.communityMap ?? false) ? "public" : "friends"
        postObject.timestamp = Firebase.Timestamp(date: Date())
    }

    func setFinalMapValues() {
        if spotObject != nil {
            mapObject!.updateSpotLevelValues(spot: spotObject!)
        }
        mapObject!.updatePostLevelValues(post: postObject!)
    }

    func saveToDrafts() {
        let post = postObject!
        let spot = spotObject
        let map = mapObject

        let selectedImages = post.postImage
        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else { return }

        let managedContext =
        appDelegate.persistentContainer.viewContext

        var imageObjects: [ImageModel] = []

        var index: Int16 = 0
        for image in selectedImages {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.5)
            im.position = index
            imageObjects.append(im)
            index += 1
        }

        var aspectRatios: [Float] = []
        for aspect in post.aspectRatios ?? [] { aspectRatios.append(Float(aspect)) }
        let postObject = PostDraft(context: managedContext)
        postObject.addedUsers = post.addedUsers
        postObject.aspectRatios = aspectRatios
        postObject.caption = post.caption
        postObject.city = post.city ?? ""
        postObject.createdBy = post.createdBy
        postObject.frameIndexes = post.frameIndexes ?? []
        postObject.friendsList = post.friendsList
        postObject.hideFromFeed = post.hideFromFeed ?? false
        postObject.images = NSSet(array: imageObjects)
        postObject.inviteList = spot?.inviteList ?? []
        postObject.mapID = post.mapID
        postObject.mapName = post.mapName
        postObject.postLat = post.postLat
        postObject.postLong = post.postLong
        postObject.privacyLevel = post.privacyLevel
        postObject.spotID = spot?.id ?? ""
        postObject.spotLat = spot?.spotLat ?? 0.0
        postObject.spotLong = spot?.spotLong ?? 0.0
        postObject.spotName = spot?.spotName ?? ""
        postObject.spotPrivacy = spot?.privacyLevel ?? ""
        postObject.taggedUsers = post.taggedUsers
        postObject.taggedUserIDs = post.taggedUserIDs
        postObject.uid = UserDataModel.shared.uid

        postObject.visitorList = spot?.visitorList ?? []
        postObject.newSpot = postType == .newSpot
        postObject.postToPOI = postType == .postToPOI
        postObject.poiCategory = spot?.poiCategory ?? ""
        postObject.phone = spot?.phone ?? ""

        postObject.mapMemberIDs = map?.memberIDs ?? []
        postObject.mapSecret = map?.secret ?? false

        let timestamp = Timestamp()
        let seconds = timestamp.seconds
        postObject.timestamp = seconds
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    func allAuths() -> Bool {
        return cameraAccess == .authorized && (galleryAccess == .authorized || galleryAccess == .limited) && locationAccess
    }

    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        nearbySpots.removeAll()
        friendObjects.removeAll()
        assetsFull = nil

        postObject = nil
        spotObject = nil
        mapObject = nil
        imageFromCamera = false
    }
}
