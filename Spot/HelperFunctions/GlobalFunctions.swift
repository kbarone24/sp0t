//
//  GlobalFunctions.swift
//  Spot
//
//  Created by kbarone on 4/7/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import CoreData
import CoreLocation
import Firebase
import FirebaseFunctions
import Foundation
import MapKit
import Mixpanel
import Photos
import UIKit
import GeoFire

extension UIViewController {
    func updateMapNameInPosts(mapID: String, newName: String) {
        let db = Firestore.firestore()
        DispatchQueue.global().async {
            db.collection("posts").whereField("mapID", isEqualTo: mapID).getDocuments { snap, _ in
                guard let snap = snap else { return }
                for postDoc in snap.documents {
                    postDoc.reference.updateData(["mapName": newName])
                }
            }
        }
    }

    func updateUsername(newUsername: String, oldUsername: String) {
        let db = Firestore.firestore()
        db.collection("maps").getDocuments { snap, _ in
            guard let snap = snap else { return }
            for doc in snap.documents {
                var posterUsernames = doc.get("posterUsernames") as? [String] ?? []
                for i in 0..<posterUsernames.count where posterUsernames[i] == oldUsername {
                    posterUsernames[i] = newUsername
                }
                doc.reference.updateData(["posterUsernames": posterUsernames])
            }
        }
        db.collection("users").whereField("username", isEqualTo: oldUsername).getDocuments { snap, _ in
            guard let snap = snap else { return }
            if let doc = snap.documents.first {
                let keywords = newUsername.getKeywordArray()
                doc.reference.updateData(["username": newUsername, "usernameKeywords": keywords])
            }
        }
        db.collection("usernames").whereField("username", isEqualTo: oldUsername).getDocuments { snap, _ in
            guard let snap = snap else { return }
            if let doc = snap.documents.first {
                print("got 3")
                doc.reference.updateData(["username": newUsername])
            }
        }

        db.collection("spots").whereField("posterUsername", isEqualTo: oldUsername).getDocuments { snap, _ in
            guard let snap = snap else { return }
            if let doc = snap.documents.first {
                print("got 4")
                doc.reference.updateData(["posterUsername": newUsername])
            }
        }
    }

    func locationIsEmpty(location: CLLocation) -> Bool {
        return location.coordinate.longitude == 0.0 && location.coordinate.latitude == 0.0
    }

    func animateWithKeyboard(
        notification: NSNotification,
        animations: ((_ keyboardFrame: CGRect) -> Void)?
    ) {
        // Extract the duration of the keyboard animation
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        let duration = notification.userInfo?[durationKey] as? Double ?? 0

        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue

        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo?[curveKey] as? Int ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveValue) ?? .easeIn

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue?.cgRectValue ?? .zero)

            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.view?.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }
    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
}

/// upload post functions
extension UIViewController {
    func uploadPostImage(images: [UIImage], postID: String, progressFill: UIView, fullWidth: CGFloat, completion: @escaping ((_ urls: [String], _ failed: Bool) -> Void)) {

        var failed = false
        var success = false

        if images.isEmpty { print("empty"); completion([], false); return } /// complete immediately for no  image post

        var URLs: [String] = []
        for _ in images {
            URLs.append("")
        }

        var index = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            /// no downloaded URLs means that this post isnt even close to uploading so trigger failed upload earlier to avoid making the user wait
            if progressFill.bounds.width != fullWidth && !URLs.contains(where: { $0 != "" }) && !failed {
                failed = true
                completion([], true)
                return
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            /// run failed upload on second try if it wasnt already run
            if progressFill.bounds.width != fullWidth && !failed && !success {
                failed = true
                completion([], true)
                return
            }
        }

        let interval = 0.7 / Double(images.count)
        var downloadCount: CGFloat = 0

        for image in images {

            let imageID = UUID().uuidString
            let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageID)")

            guard var imageData = image.jpegData(compressionQuality: 0.5) else { print("error 1"); completion([], true); return }

            if imageData.count > 1_000_000 {
                imageData = image.jpegData(compressionQuality: 0.3)!
            }

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            storageRef.putData(imageData, metadata: metadata) { _, error in

                if error != nil { if !failed { failed = true; completion([], true)}; return }
                storageRef.downloadURL { (url, _) in
                    if error != nil { if !failed { failed = true; completion([], true)}; return }
                    let urlString = url!.absoluteString

                    let i = images.lastIndex(where: { $0 == image })
                    URLs[i ?? 0] = urlString
                    downloadCount += 1

                    DispatchQueue.main.async {
                        let progress = downloadCount * interval
                        let frameWidth: CGFloat = min(((0.3 + progress) * fullWidth), fullWidth)
                        progressFill.snp.updateConstraints { $0.width.equalTo(frameWidth) }
                        UIView.animate(withDuration: 0.15) {
                            self.view.layoutIfNeeded()
                        }
                    }

                    index += 1

                    if failed { return } /// dont want to return anything after failed upload runs

                    if index == images.count {
                        DispatchQueue.main.async {
                            success = true
                            completion(URLs, false)
                            return
                        }
                    }
                }
            }
        }
    }

    func uploadPostToDB(newMap: Bool) {
        guard let post = UploadPostModel.shared.postObject else { return }
        var spot = UploadPostModel.shared.spotObject
        var map = UploadPostModel.shared.mapObject

        if UploadPostModel.shared.imageFromCamera { SpotPhotoAlbum.shared.save(image: post.postImage.first ?? UIImage()) }

        if spot != nil {
            spot!.imageURL = post.imageURLs.first ?? ""
            self.uploadSpot(post: post, spot: spot!, submitPublic: false)
        }
        if map != nil {
            if map!.imageURL == "" { map!.imageURL = post.imageURLs.first ?? "" }
            map!.postImageURLs.append(post.imageURLs.first ?? "")
            self.uploadMap(map: map!, newMap: newMap, post: post, spot: spot)
        }
        self.uploadPost(post: post, map: map, spot: spot, newMap: newMap)

        let visitorList = spot?.visitorList ?? []
        self.setUserValues(poster: UserDataModel.shared.uid, post: post, spotID: spot?.id ?? "", visitorList: visitorList, mapID: map?.id ?? "")

        Mixpanel.mainInstance().track(event: "SuccessfulPostUpload")
    }

    func uploadPost(post: MapPost, map: CustomMap?, spot: MapSpot?, newMap: Bool) {
        /// send local notification first
        guard let postID = post.id else { return }
        let caption = post.caption
        var notiPost = post
        notiPost.id = postID
        let commentObject = MapComment(
            id: UUID().uuidString, comment: caption, commenterID: post.posterID, taggedUsers: post.taggedUsers, timestamp: post.timestamp, userInfo: UserDataModel.shared.userInfo
        )
        notiPost.commentList = [commentObject]
        notiPost.captionHeight = caption.getCaptionHeight(fontSize: 14.5, maxCaption: 52)
        notiPost.userInfo = UserDataModel.shared.userInfo
        NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post": notiPost as Any, "map": map as Any, "spot": spot as Any, "newMap": newMap]))

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postID)
        do {
            var post = post
            post.g = GFUtils.geoHash(forLocation: post.coordinate)
            try postRef.setData(from: post)
            if !newMap { self.sendPostNotifications(post: post, map: map, spot: spot) } /// send new map notis for new map
            let commentRef = postRef.collection("comments").document(commentObject.id ?? "")

            do {
                try commentRef.setData(from: commentObject)
            } catch {
                print("failed uploading comment")
            }
        } catch {
            print("failed uploading post")
        }
    }

    func sendPostNotifications(post: MapPost, map: CustomMap?, spot: MapSpot?) {
        let functions = Functions.functions()
        let notiValues: [String: Any] = [
            "communityMap": map?.communityMap ?? false,
             "friendIDs": UserDataModel.shared.userInfo.friendIDs,
             "imageURLs": post.imageURLs,
             "mapID": map?.id ?? "",
             "mapMembers": map?.memberIDs ?? [],
             "mapName": map?.mapName ?? "",
             "postID": post.id ?? "",
             "posterID": UserDataModel.shared.uid,
             "posterUsername": UserDataModel.shared.userInfo.username,
             "privacyLevel": post.privacyLevel ?? "friends",
             "spotID": spot?.id ?? "",
             "spotName": spot?.spotName ?? "",
             "spotVisitors": spot?.visitorList ?? [],
            "taggedUserIDs": post.taggedUserIDs ?? []
        ]
        functions.httpsCallable("sendPostNotification").call(notiValues) { result, error in
            print(result?.data as Any, error as Any)
        }
    }

    func uploadSpot(post: MapPost, spot: MapSpot, submitPublic: Bool) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
        let db: Firestore = Firestore.firestore()

        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))

        switch UploadPostModel.shared.postType {
        case .newSpot, .postToPOI:

            let lowercaseName = spot.spotName.lowercased()
            let keywords = lowercaseName.getKeywordArray()
            let geoHash = GFUtils.geoHash(forLocation: spot.location.coordinate)

            let tagDictionary: [String: Any] = [:]

            var spotVisitors = [uid]
            spotVisitors.append(contentsOf: post.addedUsers ?? [])

            var posterDictionary: [String: Any] = [:]
            posterDictionary[post.id!] = spotVisitors

            /// too many extreneous variables for spots to set with codable
            let spotValues = ["city": post.city ?? "",
                              "spotName": spot.spotName,
                              "lowercaseName": lowercaseName,
                              "description": post.caption,
                              "createdBy": uid,
                              "posterUsername": UserDataModel.shared.userInfo.username,
                              "visitorList": spotVisitors,
                              "inviteList": spot.inviteList ?? [],
                              "privacyLevel": spot.privacyLevel,
                              "taggedUsers": post.taggedUsers ?? [],
                              "spotLat": spot.spotLat,
                              "spotLong": spot.spotLong,
                              "g" : geoHash,
                              "imageURL": post.imageURLs.first ?? "",
                              "phone": spot.phone ?? "",
                              "poiCategory": spot.poiCategory ?? "",
                              "postIDs": [post.id!],
                              "postMapIDs": [post.mapID ?? ""],
                              "postTimestamps": [timestamp],
                              "posterIDs": [uid],
                              "postPrivacies": [post.privacyLevel!],
                              "searchKeywords": keywords,
                              "tagDictionary": tagDictionary,
                              "posterDictionary": posterDictionary] as [String: Any]

            db.collection("spots").document(spot.id!).setData(spotValues, merge: true)

            if submitPublic { db.collection("submissions").document(spot.id!).setData(["spotID": spot.id!])}

            var notiSpot = spot
            notiSpot.checkInTime = Int64(interval)
            NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot": notiSpot])

            /// add city to list of cities if this is the first post there
            self.addToCityList(city: post.city ?? "")

            /// increment users spot score by 6
        default:

            /// run spot transactions
            var posters = post.addedUsers ?? []
            posters.append(uid)

            let functions = Functions.functions()
            functions.httpsCallable("runSpotTransactions").call([
                "spotID": spot.id ?? "",
                "postID": post.id ?? "",
                "postPrivacy": post.privacyLevel!,
                "postTag": post.tag ?? "",
                "posters": posters,
                "uid": uid,
                "mapID": post.mapID ?? ""]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }

    func uploadMap(map: CustomMap, newMap: Bool, post: MapPost, spot: MapSpot?) {
        let db: Firestore = Firestore.firestore()
        if newMap {
            let mapRef = db.collection("maps").document(map.id!)
            do {
                try mapRef.setData(from: map, merge: true)
            } catch {
                print("failed uploading map")
            }
        } else {
            /// update values with backend function
            let functions = Functions.functions()
            let postLocation = ["lat": post.postLat, "long": post.postLong]
            let spotLocation = ["lat": post.spotLat ?? 0.0, "long": post.spotLong ?? 0.0]
            var posters = [UserDataModel.shared.uid]
            if !(post.addedUsers?.isEmpty ?? true) { posters.append(contentsOf: post.addedUsers ?? []) }
            functions.httpsCallable("runMapTransactions").call(
                ["mapID": map.id!,
                 "uid": UserDataModel.shared.uid,
                 "poiCategory": spot?.poiCategory ?? "",
                 "postID": post.id!,
                 "postImageURL": post.imageURLs.first ?? "",
                 "postLocation": postLocation,
                 "posters": posters,
                 "posterUsername": UserDataModel.shared.userInfo.username,
                 "spotID": post.spotID ?? "",
                 "spotName": post.spotName ?? "",
                 "spotLocation": spotLocation]
            ) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
        db.collection("mapLocations").document(post.id!).setData(["mapID": map.id!, "postID": post.id!])
    }

    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String], mapID: String) {
        let tag = post.tag ?? ""
        let addedUsers = post.addedUsers ?? []

        var posters = [poster]
        posters.append(contentsOf: addedUsers)
        
        do {
            let friendsService = try ServiceContainer.shared.service(for: \.friendsService)
            // adjust user values for added users
            for poster in posters {
                /// increment addedUsers spotScore by 1
                var userValues = ["spotScore": FieldValue.increment(Int64(3))]
                if tag != "" { userValues["tagDictionary.\(tag)"] = FieldValue.increment(Int64(1)) }

                /// remove this user for topFriends increments
                var dictionaryFriends = posters
                dictionaryFriends.removeAll(where: { $0 == poster })
                /// increment top friends if added friends
                for user in dictionaryFriends {
                    friendsService.incrementTopFriends(friendID: user, increment: 5, completion: nil)
                }

                Firestore.firestore().collection("users").document(poster).updateData(userValues)
            }
            
        } catch {
            return
        }
    }

    func removeFriend(friendID: String) {
        UserDataModel.shared.userInfo.friendIDs.removeAll(where: { $0 == friendID })
        UserDataModel.shared.userInfo.friendsList.removeAll(where: { $0.id == friendID })
        UserDataModel.shared.userInfo.topFriends?.removeValue(forKey: friendID)
        UserDataModel.shared.deletedFriendIDs.append(friendID)

        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        removeFriendFromFriendsList(userID: uid, friendID: friendID)
        removeFriendFromFriendsList(userID: friendID, friendID: uid)

        /// firebase function broken
        DispatchQueue.global().async {
            self.removeFriendFromPosts(userID: uid, friendID: friendID)
            self.removeFriendFromPosts(userID: friendID, friendID: uid)

            self.removeFriendFromNotis(userID: uid, friendID: friendID)
            self.removeFriendFromNotis(userID: friendID, friendID: uid)
        }
    }

    func removeFriendFromFriendsList(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()

        db.collection("users").document(userID).updateData([
            "friendsList": FieldValue.arrayRemove([friendID]),
            "topFriends.\(friendID)": FieldValue.delete()
        ])
    }

    func removeFriendFromPosts(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: friendID).getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            for doc in docs {
                doc.reference.updateData(["friendsList": FieldValue.arrayRemove([userID])])
            }
        }
    }

    func removeFriendFromNotis(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()
        db.collection("users").document(userID).collection("notifications").whereField("senderID", isEqualTo: friendID).whereField("type", isEqualTo: "friendRequest").getDocuments { snap, _ in
            guard let docs = snap?.documents else { return }
            for doc in docs {
                doc.reference.delete()
            }
        }
    }

    func deletePostDraft(timestampID: Int64) {

        guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext =
        appDelegate.persistentContainer.viewContext
        let fetchRequest =
        NSFetchRequest<PostDraft>(entityName: "PostDraft")
        fetchRequest.predicate = NSPredicate(format: "timestamp == %d", timestampID)
        do {
            let drafts = try managedContext.fetch(fetchRequest)
            for draft in drafts {
                managedContext.delete(draft)
            }
            do {
                try managedContext.save()
            } catch let error as NSError {
                print("could not save. \(error)")
            }
        } catch let error as NSError {
            print("could not fetch. \(error)")
        }
    }

    func addToCityList(city: String) {
        let db = Firestore.firestore()
        let query = db.collection("cities").whereField("cityName", isEqualTo: city)

        query.getDocuments { [weak self] (cityDocs, _) in
            if cityDocs?.documents.count ?? 0 == 0 {
                city.getCoordinate { coordinate, error in
                    guard let coordinate = coordinate, error == nil else { return }
                    let id = UUID().uuidString
                    let g = GFUtils.geoHash(forLocation: coordinate)
                    db.collection("cities").document(id).setData(["cityName": city, "g": g])
                }
            }
        }
    }
}
