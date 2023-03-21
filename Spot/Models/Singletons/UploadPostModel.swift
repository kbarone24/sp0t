//
//  UploadImageModel.swift
//  Spot
//
//  Created by Kenny Barone on 8/12/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Firebase
import FirebaseFirestore
import Mixpanel
import Photos
import UIKit

final class UploadPostModel {
    var assetsFull: PHFetchResult<PHAsset>?
    var selectedObjects: [ImageObject] = []
    var imageObjects: [(image: ImageObject, selected: Bool)] = []
    var imageFromCamera = false
    var videoFromCamera = false
    var cancelOnDismiss = false // stop assets fetch on dismiss
    var galleryOpen = false // don't sort imageObjects when gallery visible

    var postObject: MapPost?
    var spotObject: MapSpot?
    var mapObject: CustomMap?

    lazy var postType: PostType = .none

    lazy var nearbySpots: [MapSpot] = []
    lazy var taggedUserProfiles: [UserProfile] = []

    lazy var locationAccess: Bool = false
    var cameraAccess: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    var galleryAccess: PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    var cameraEnabled: Bool {
        return cameraAccess == .authorized && locationAccess
    }

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
        cancelOnDismiss = false
        let coordinate = UserDataModel.shared.currentLocation.coordinate

        self.postObject = MapPost(
            posterUsername: UserDataModel.shared.userInfo.username,
            caption: "",
            privacyLevel: "public",
            longitude: coordinate.longitude,
            latitude: coordinate.latitude,
            timestamp: Timestamp(date: Date())
        )

        setPostCity() // set with every location change to avoid async lag on upload
        spotObject = nil
        mapObject = nil
    }

    func setSpotValues(spot: MapSpot?) {
        spotObject = spot
        if spot != nil { spotObject?.selected = true }
        postType = spot == nil ? .none : spot?.founderID ?? "" == "" ? .postToPOI : .postToSpot

        postObject?.createdBy = spot?.founderID ?? ""
        postObject?.spotID = spot?.id ?? ""
        postObject?.spotLat = spot?.spotLat ?? 0.0
        postObject?.spotLong = spot?.spotLong ?? 0.0
        postObject?.spotName = spot?.spotName ?? ""
        postObject?.spotPrivacy = spot?.privacyLevel ?? ""
        postObject?.spotPOICategory = spot?.poiCategory ?? ""

        // if post with no location, use spot location
        if !(postObject?.setImageLocation ?? false), let spot {
            postObject?.postLat = spot.spotLat
            postObject?.postLong = spot.spotLong
            setPostCity()
        }
    }

    func setMapValues(map: CustomMap?) {
        mapObject = map
        postObject?.mapID = map?.id ?? ""
        postObject?.mapName = map?.mapName ?? ""
        postObject?.privacyLevel = map?.secret ?? false ? "invite" : "public"
        postObject?.hideFromFeed = map?.secret ?? false
    }

    func setPostCity() {
        let location = CLLocation(latitude: postObject?.postLat ?? 0, longitude: postObject?.postLong ?? 0)
        
        guard let locationService = try? ServiceContainer.shared.service(for: \.locationService) else {
            return
        }
        
        Task {
            guard let city = try? await locationService.getCityFromLocation(location: location, zoomLevel: 0) else {
                return
            }
            
            self.postObject?.city = city
        }
    }

    func setTaggedUsers() {
        // store to remove if user posts to private map
        let taggedUsers = postObject?.caption.getTaggedUsers() ?? []
        self.taggedUserProfiles = taggedUsers

        let usernames = taggedUsers.map({ $0.username })
        postObject?.taggedUsers = usernames
        postObject?.addedUsers = taggedUsers.map({ $0.id ?? "" })
        postObject?.taggedUserIDs = taggedUsers.map({ $0.id ?? "" })
    }
    
    func setFinalPostValues() {
        var postFriends = (postObject?.hideFromFeed ?? false) ? [] : UserDataModel.shared.userInfo.friendIDs
        if let mapObject { postObject?.inviteList = mapObject.likers }

        // if map selected && mymap selected, add friendsList
        if !postFriends.contains(UserDataModel.shared.uid) && !(postObject?.hideFromFeed ?? false) { postFriends.append(UserDataModel.shared.uid) }
        postObject?.friendsList = postFriends
        postObject?.privacyLevel = mapObject != nil && (mapObject?.secret ?? false) ? "invite" : "public"
        postObject?.timestamp = Timestamp(date: Date())
        postObject?.userInfo = UserDataModel.shared.userInfo
        postObject?.selectedImageIndex = 0
        postObject?.posterUsername = UserDataModel.shared.userInfo.username
        
        guard postObject?.privacyLevel == "invite" else {
            return
        }
        
        for user in taggedUserProfiles where (postObject?.inviteList?.contains(where: { $0 == user.id ?? "" }) ?? false) {
            postObject?.taggedUsers?.removeAll(where: { $0 == user.username })
            postObject?.taggedUserIDs?.removeAll(where: { $0 == user.id ?? "" })
            postObject?.addedUsers?.removeAll(where: { $0 == user.id ?? "" })
        }
    }

    func setFinalMapValues() {
        mapObject?.updatePostLevelValues(post: postObject)
        if let spotObject {
            mapObject?.updateSpotLevelValues(spot: spotObject)
        }
    }

    func saveToDrafts(videoData: Data?) {
        guard let post = postObject else { return }
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
        postObject.inviteList = post.inviteList ?? []
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

        if let videoData {
            postObject.videoData = videoData
        }

        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    func fetchAssets(completion: @escaping(_ complete: Bool) -> Void) {
        // fetch all assets for showing when user opens photo gallery
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.fetchLimit = 10_000

        guard let userLibrary = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject else { return }

        let assetsFull = PHAsset.fetchAssets(in: userLibrary, options: fetchOptions)
        let indexSet = assetsFull.count > 10_000 ? IndexSet(0...9_999) : IndexSet(0..<assetsFull.count)
        self.assetsFull = assetsFull

        DispatchQueue.global().async {
            assetsFull.enumerateObjects(at: indexSet, options: NSEnumerationOptions()) { [weak self] (object, _, stop) in
                guard let self = self else { return }
                if self.cancelOnDismiss { stop.pointee = true }

                var location = CLLocation()
                if let l = object.location { location = l }

                var creationDate = Date()
                if let d = object.creationDate {
                    creationDate = d
                }

                let imageObj = (
                    ImageObject(
                        id: UUID().uuidString,
                        asset: object,
                        rawLocation: location,
                        stillImage: UIImage(),
                        animationImages: [],
                        animationIndex: 0,
                        directionUp: true,
                        gifMode: false,
                        creationDate: creationDate,
                        fromCamera: false
                    ),
                    false
                )

                UploadPostModel.shared.imageObjects.append(imageObj)

                if self.imageObjects.count == assetsFull.count {
                    DispatchQueue.global().async {
                        UploadPostModel.shared.imageObjects.sort(by: { !$0.selected && !$1.selected ? $0.0.creationDate > $1.0.creationDate : $0.selected && !$1.selected })
                    }
                    completion(true)
                    return
                }
            }
        }
    }
    
    func destroy() {
        selectedObjects.removeAll()
        imageObjects.removeAll()
        nearbySpots.removeAll()
        taggedUserProfiles.removeAll()
        assetsFull = nil

        postObject = nil
        spotObject = nil
        mapObject = nil
        imageFromCamera = false
        cancelOnDismiss = false
    }
}
