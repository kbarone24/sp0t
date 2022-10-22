//
//  CameraFailedUploadsExt.swift
//  Spot
//
//  Created by Kenny Barone on 7/19/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import CoreData
import Firebase
import Foundation
import Mixpanel

extension AVCameraController {

    func getFailedUploads() {

        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        let managedContext =
        appDelegate.persistentContainer.viewContext
        let postsRequest =
        NSFetchRequest<PostDraft>(entityName: "PostDraft")

        postsRequest.relationshipKeyPathsForPrefetching = ["images"]
        postsRequest.returnsObjectsAsFaults = false
        postsRequest.predicate = NSPredicate(format: "uid == %@", self.uid)
        let timeSort = NSSortDescriptor(key: "timestamp", ascending: false)
        postsRequest.sortDescriptors = [timeSort]

        DispatchQueue.global().async { [weak self] in
            do {
                let failedPosts = try managedContext.fetch(postsRequest)
                guard let post = failedPosts.first,
                      self?.spotObject == nil
                else {
                    return
                }

                /// test for corrupted draft or old draft (pre 1.0)
                let timestampID = post.timestamp

                if post.images == nil {
                    self?.deletePostDraft(timestampID: timestampID)
                }

                guard let images = post.images as? Set<ImageModel> else {
                    return
                }

                let firstImageData = images.first?.imageData

                if firstImageData == nil || post.addedUsers == nil {
                    self?.deletePostDraft(timestampID: timestampID)

                } else {
                    self?.postDraft = post
                    let postImage = UIImage(data: firstImageData! as Data) ?? UIImage()

                    DispatchQueue.main.async {
                        self?.failedPostView = FailedPostView {
                            $0.coverImage.image = postImage
                            self?.view.addSubview($0)
                        }

                        self?.failedPostView!.snp.makeConstraints {
                            $0.edges.equalToSuperview()
                        }
                    }

                    return
                }

            } catch let error as NSError {
                print("Could not fetch. \(error), \(error.userInfo)")
            }
        }
    }

    func deletePostDraft() {
        Mixpanel.mainInstance().track(event: "CameraDeletePostDraft", properties: nil)
        deletePostDraft(timestampID: postDraft!.timestamp)

        failedPostView!.removeFromSuperview()
        failedPostView = nil
    }

    func uploadPostDraft() {
        guard let postDraft = postDraft,
              let model = postDraft.images as? Set<ImageModel> else {
            return
        }

        let mod = model.sorted(by: { $0.position < $1.position })
        var uploadImages: [UIImage] = []

        for i in 0...mod.count - 1 {
            let im = mod[i]
            let imageData = im.imageData
            uploadImages.append(UIImage(data: imageData!) ?? UIImage())
        }

        let actualTimestamp = Timestamp(seconds: postDraft.timestamp, nanoseconds: 0)
        var aspectRatios: [CGFloat] = []

        postDraft.aspectRatios?
            .compactMap { $0 }
            .forEach {
                aspectRatios.append(CGFloat($0))
            }

        var post = MapPost(
            id: UUID().uuidString,
            posterID: uid,
            postDraft: postDraft,
            mapInfo: nil,
            actualTimestamp: actualTimestamp,
            uploadImages: uploadImages,
            imageURLs: [],
            aspectRatios: aspectRatios,
            imageLocations: [],
            likers: []
        )

        var spot = MapSpot(post: post, postDraft: postDraft, imageURL: "")

        UploadPostModel.shared.postType = postDraft.newSpot ? .newSpot : postDraft.postToPOI ? .postToPOI : spot.id != "" ? .postToSpot : .none

        DispatchQueue.global(qos: .userInitiated).async {
            self.getMap(mapID: post.mapID ?? "") { map, failed in
                var map = map
                self.uploadPostImage(post.postImage, postID: post.id!, progressFill: self.failedPostView!.progressFill, fullWidth: UIScreen.main.bounds.width - 100) { [weak self] imageURLs, failed in
                    guard let self = self else { return }

                    if imageURLs.isEmpty && failed {
                        Mixpanel.mainInstance().track(event: "FailedPostUpload")
                        self.showFailAlert()
                        return
                    }

                    post.imageURLs = imageURLs
                    post.timestamp = Firebase.Timestamp(date: Date())

                    let newMap = post.mapID ?? "" != "" && map.id ?? "" == ""
                    if newMap {
                        map = CustomMap(id: post.mapID!, founderID: self.uid, imageURL: imageURLs.first!, likers: [self.uid], mapName: post.mapName ?? "", memberIDs: [self.uid], posterDictionary: [post.id!: [self.uid]], posterIDs: [self.uid], posterUsernames: [UserDataModel.shared.userInfo.username], postIDs: [post.id!], postImageURLs: post.imageURLs, postLocations: [["lat": post.postLat, "long": post.postLong]], postSpotIDs: [], postTimestamps: [post.timestamp], secret: false, spotIDs: [], spotNames: [], spotLocations: [], memberProfiles: [UserDataModel.shared.userInfo], coverImage: uploadImages.first!)
                        let lowercaseName = (post.mapName ?? "").lowercased()
                        map.lowercaseName = lowercaseName
                        map.searchKeywords = lowercaseName.getKeywordArray()
                        /// add added users
                        if !(post.addedUsers?.isEmpty ?? true) { map.memberIDs.append(contentsOf: post.addedUsers!); map.likers.append(contentsOf: post.addedUsers!); map.memberProfiles!.append(contentsOf: post.addedUserProfiles!); map.posterDictionary[post.id!]?.append(contentsOf: post.addedUsers!) }
                        if spot.id != "" {
                            map.postSpotIDs.append(spot.id!)
                            map.spotIDs.append(spot.id!)
                            map.spotNames.append(spot.spotName)
                            map.spotLocations.append(["lat": spot.spotLat, "long": spot.spotLong])
                        }
                    }

                    if spot.id != "" {
                        spot.imageURL = imageURLs.first ?? ""
                        self.uploadSpot(post: post, spot: spot, submitPublic: false)
                    }

                    if map.id ?? "" != "" {
                        if map.imageURL == "" { map.imageURL = imageURLs.first ?? "" }
                        self.uploadMap(map: map, newMap: newMap, post: post)
                    }

                    self.uploadPost(post: post, map: map, spot: spot, newMap: newMap)
                    let visitorList = spot.visitorList
                    self.setUserValues(poster: self.uid, post: post, spotID: spot.id ?? "", visitorList: visitorList, mapID: map.id ?? "")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.showSuccessAlert()
                    }
                }
            }
        }
    }

    func showSuccessAlert() {
        deletePostDraft()
        let alert = UIAlertController(
            title: "Post successfully uploaded!",
            message: "",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        present(alert, animated: true, completion: nil)
    }

    func showFailAlert() {
        let alert = UIAlertController(
            title: "Upload failed",
            message: "Post saved to your drafts",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelTap()
            }
        )
        present(alert, animated: true, completion: nil)
    }

    func getMap(mapID: String, completion: @escaping (_ map: CustomMap, _ failed: Bool) -> Void) {

        let emptyMap = CustomMap(
            founderID: "",
            imageURL: "",
            likers: [],
            mapName: "",
            memberIDs: [],
            posterIDs: [],
            posterUsernames: [],
            postIDs: [],
            postImageURLs: [],
            secret: false,
            spotIDs: []
        )

        if mapID.isEmpty {
            completion(emptyMap, false)
            return
        }

        let db = Firestore.firestore()
        let mapRef = db.collection("maps").document(mapID)

        mapRef.getDocument { (doc, _) in
            do {
                let unwrappedInfo = try doc?.data(as: CustomMap.self)
                guard var mapInfo = unwrappedInfo else { completion(emptyMap, true); return }
                mapInfo.id = mapID
                completion(mapInfo, false)
                return
            } catch {
                completion(emptyMap, true)
                return
            }
        }
    }
}
