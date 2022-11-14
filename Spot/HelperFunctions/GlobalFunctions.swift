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
import Geofirestore
import MapKit
import Mixpanel
import Photos
import UIKit

extension UIViewController {
    func isFriends(id: String) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if id == uid || (UserDataModel.shared.userInfo.friendIDs.contains(where: { $0 == id }) && !(UserDataModel.shared.adminIDs.contains(id))) { return true }
        return false
    }

    func hasPOILevelAccess(creatorID: String, privacyLevel: String, inviteList: [String]) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        if UserDataModel.shared.adminIDs.contains(where: { $0 == creatorID }) {
            if uid != creatorID {
                return false
            }
        }
        if privacyLevel == "friends" {
            if !UserDataModel.shared.userInfo.friendIDs.contains(where: { $0 == creatorID }) {
                if uid != creatorID {
                    return false
                }
            }
        } else if privacyLevel == "invite" {
            if !inviteList.contains(where: { $0 == uid }) {
                return false
            }
        }
        return true
    }

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
            self.uploadMap(map: map!, newMap: newMap, post: post)
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
        NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post": notiPost as Any, "map": map as Any, "spot": spot as Any]))

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postID)
        do {
            try postRef.setData(from: post)
            self.setPostLocations(postLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), postID: postID)
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
                               "imageURL": post.imageURLs.first ?? "",
                               "phone": spot.phone ?? "",
                               "poiCategory": spot.poiCategory ?? "",
                               "postIDs": [post.id!],
                               "postTimestamps": [timestamp],
                               "posterIDs": [uid],
                               "postPrivacies": [post.privacyLevel!],
                               "searchKeywords": keywords,
                               "tagDictionary": tagDictionary,
                               "posterDictionary": posterDictionary] as [String: Any]

            db.collection("spots").document(spot.id!).setData(spotValues, merge: true)

            if submitPublic { db.collection("submissions").document(spot.id!).setData(["spotID": spot.id!])}
            self.setSpotLocations(spotLocation: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), spotID: spot.id!)

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
            functions.httpsCallable("runSpotTransactions").call(["spotID": spot.id!, "postID": post.id!, "uid": uid, "postPrivacy": post.privacyLevel!, "postTag": post.tag ?? "", "posters": posters]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }

    func uploadMap(map: CustomMap, newMap: Bool, post: MapPost) {
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
        setMapLocations(mapLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), documentID: post.id!)
    }

    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String], mapID: String) {
        let tag = post.tag ?? ""
        let addedUsers = post.addedUsers ?? []

        var posters = [poster]
        posters.append(contentsOf: addedUsers)

        let db: Firestore = Firestore.firestore()
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
                incrementTopFriends(friendID: user, increment: 5)
            }

            db.collection("users").document(poster).updateData(userValues)
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

    func setPostLocations(postLocation: CLLocationCoordinate2D, postID: String) {
        let location = CLLocation(latitude: postLocation.latitude, longitude: postLocation.longitude)
        GeoFirestore(collectionRef: Firestore.firestore().collection("posts")).setLocation(location: location, forDocumentWithID: postID) { (error) in
            if error != nil {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }

    func setSpotLocations(spotLocation: CLLocationCoordinate2D, spotID: String) {
        let location = CLLocation(latitude: spotLocation.latitude, longitude: spotLocation.longitude)
        GeoFirestore(collectionRef: Firestore.firestore().collection("spots")).setLocation(location: location, forDocumentWithID: spotID) { (error) in
            if error != nil {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }

    func setMapLocations(mapLocation: CLLocationCoordinate2D, documentID: String) {
        let location = CLLocation(latitude: mapLocation.latitude, longitude: mapLocation.longitude)
        GeoFirestore(collectionRef: Firestore.firestore().collection("mapLocations")).setLocation(location: location, forDocumentWithID: documentID) { (error) in
            if error != nil {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }

    func addToCityList(city: String) {
        let db = Firestore.firestore()
        let query = db.collection("cities").whereField("cityName", isEqualTo: city)

        query.getDocuments { [weak self] (cityDocs, _) in
            guard let self = self else { return }
            if cityDocs?.documents.count ?? 0 == 0 {
                city.getCoordinate { coordinate, error in
                    guard let coordinate = coordinate, error == nil else { return }
                    let id = UUID().uuidString
                    db.collection("cities").document(id).setData(["cityName": city])
                    GeoFirestore(collectionRef: db.collection("cities")).setLocation(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), forDocumentWithID: id) { (_) in
                        print(city, "Location:", coordinate)
                    }
                }
            }
        }
    }
}


// THIS IS NOT GOOD
// TODO: Each returned value should be in a separate extension of it's file type.
// Example `extension MapPost`
// Extending NSObject is overkill

extension NSObject {
    func getImageHeight(aspectRatio: CGFloat, maxAspect: CGFloat) -> CGFloat {
        var imageAspect = min(aspectRatio, maxAspect)
        imageAspect = getRoundedAspectRatio(aspect: imageAspect)
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }

    func getRoundedAspectRatio(aspect: CGFloat) -> CGFloat {
        var imageAspect = aspect
        if imageAspect > 1.1 && imageAspect < 1.45 { imageAspect = 1.333 } /// stretch iPhone vertical
        else if imageAspect > 1.45 { imageAspect = UserDataModel.shared.maxAspect } /// round to max aspect
        return imageAspect
    }

    func getComments(postID: String, completion: @escaping (_ comments: [MapComment]) -> Void) {
        if postID == "" { completion([]); return }
        let db = Firestore.firestore()
        var commentList: [MapComment] = []

        DispatchQueue.global().async {
            db.collection("posts").document(postID).collection("comments").order(by: "timestamp", descending: true).getDocuments { [weak self] (commentSnap, _) in
                guard let commentSnap else { completion(commentList); return }
                if commentSnap.documents.isEmpty { completion(commentList); return }
                guard let self = self else { return }

                for doc in commentSnap.documents {
                    do {
                        let commentInf = try doc.data(as: MapComment.self)
                        guard var commentInfo = commentInf else { continue }
                        if commentInfo.commenterID.isBlocked() { continue }

                        self.getUserInfo(userID: commentInfo.commenterID) { user in
                            commentInfo.userInfo = user
                            if !commentList.contains(where: { $0.id == doc.documentID }) {
                                commentList.append(commentInfo)
                                commentList.sort(by: { $0.seconds < $1.seconds })
                            }
                        }
                    } catch { continue }
                }
                completion(commentList)
            }
        }
    }

    func getPost(postID: String, completion: @escaping (_ post: MapPost) -> Void) {
        let db = Firestore.firestore()
        var emptyPost = MapPost(
            spotID: "",
            spotName: "",
            mapID: "",
            mapName: ""
        )
        emptyPost.id = ""

        DispatchQueue.global().async {
            db.collection("posts").document(postID).getDocument { [weak self] doc, _ in
                guard let self = self else { return }
                do {
                    let unwrappedInfo = try doc?.data(as: MapPost.self)
                    guard var postInfo = unwrappedInfo else { completion(emptyPost); return }

                    self.setPostDetails(post: postInfo) { post in
                        completion(post)
                        return
                    }
                } catch { completion(emptyPost); return }
            }
        }
    }

    func getUserInfo(userID: String, completion: @escaping (_ user: UserProfile) -> Void) {
        let emptyProfile = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
        if userID == "" { completion(emptyProfile); return }

        let db: Firestore = Firestore.firestore()
        if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.id == userID }) {
            completion(user)
            return

        } else if userID == UserDataModel.shared.uid {
            completion(UserDataModel.shared.userInfo)
            return

        } else {
            DispatchQueue.global().async {
                db.collection("users").document(userID).getDocument { (doc, _) in
                    guard let doc = doc else { return }
                    do {
                        let userInfo = try doc.data(as: UserProfile.self)
                        guard var info = userInfo else { completion(emptyProfile); return }
                        info.id = doc.documentID
                        completion(info)
                        return
                    } catch { completion(emptyProfile); return }
                }
            }
        }
    }

    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void) {
        if post.id ?? "" == "" { completion(post); return }
        var postInfo = post

        let caption = postInfo.caption
        postInfo.captionHeight = caption.getCaptionHeight(fontSize: 14.5, maxCaption: 52)
        // detail group tracks comments and added users fetches
        let detailGroup = DispatchGroup()
        detailGroup.enter()
        detailGroup.enter()
        getUserInfo(userID: postInfo.posterID) { user in
            postInfo.userInfo = user
            detailGroup.leave()
        }
        getComments(postID: postInfo.id ?? "") { comments in
            postInfo.commentList = comments
            detailGroup.leave()
        }

        detailGroup.notify(queue: .global()) { [weak self] in
            guard self != nil else { return }
            completion(postInfo)
            return
        }
    }

    func getUserFromUsername(username: String, completion: @escaping (_ user: UserProfile?) -> Void) {
        let db = Firestore.firestore()
        if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == username }) {
            completion(user)
            return
        } else {
            DispatchQueue.global().async {
                db.collection("users").whereField("username", isEqualTo: username).getDocuments { snap, _ in
                    guard let doc = snap?.documents.first else { completion(nil); return }
                    do {
                        let unwrappedInfo = try doc.data(as: UserProfile.self)
                        guard let userInfo = unwrappedInfo else { completion(nil); return }
                        completion(userInfo)
                        return
                    } catch {
                        completion(nil)
                        return
                    }
                }
            }
        }
    }

    func getSpot(spotID: String, completion: @escaping (_ spot: MapSpot?) -> Void) {
        let db = Firestore.firestore()
        let spotRef = db.collection("spots").document(spotID)

        DispatchQueue.global().async {
            spotRef.getDocument { (doc, _) in
                do {
                    let unwrappedInfo = try doc?.data(as: MapSpot.self)
                    guard var spotInfo = unwrappedInfo else { completion(nil); return }

                    spotInfo.id = spotID
                    spotInfo.spotDescription = "" /// remove spotdescription, no use for it here, will either be replaced with POI description or username
                    for visitor in spotInfo.visitorList {
                        if UserDataModel.shared.userInfo.friendIDs.contains(visitor) { spotInfo.friendVisitors += 1 }
                    }

                    completion(spotInfo)
                    return

                } catch {
                    completion(nil)
                    return
                }
            }
        }
    }

    func getMap(mapID: String, completion: @escaping (_ map: CustomMap?) -> Void) {
        let db = Firestore.firestore()
        let mapRef = db.collection("maps").document(mapID)

        DispatchQueue.global().async {
            mapRef.getDocument { (doc, _) in
                do {
                    let unwrappedInfo = try doc?.data(as: CustomMap.self)
                    guard let mapInfo = unwrappedInfo else { completion(nil); return }
                    completion(mapInfo)
                    return
                } catch {
                    completion(nil)
                    return
                }
            }
        }
    }

    func addFriend(receiverID: String) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore = Firestore.firestore()
        let ref = db.collection("users").document(receiverID).collection("notifications").document(UserDataModel.shared.uid) // using UID for friend rquest should make it so user cant send a double friend request

        let time = Date()

        let values = ["senderID": uid,
                      "type": "friendRequest",
                      "senderUsername": UserDataModel.shared.userInfo.username,
                      "timestamp": time,
                      "status": "pending",
                      "seen": false

        ] as [String: Any]
        ref.setData(values)

        db.collection("users").document(uid).updateData(["pendingFriendRequests": FieldValue.arrayUnion([receiverID])])
    }

    func acceptFriendRequest(friend: UserProfile, notificationID: String) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        addFriendToFriendsList(userID: uid, friendID: friend.id!)
        addFriendToFriendsList(userID: friend.id!, friendID: uid)
        sendFriendRequestNotis(friendID: friend.id!, notificationID: notificationID)

        /// adjust individual posts "friendsList" docs
        DispatchQueue.global().async {
            self.adjustPostFriendsList(userID: uid, friendID: friend.id!, completion: { _ in
                /// send notification to home to reload posts
                NotificationCenter.default.post(Notification(name: Notification.Name("FriendsListAdd")))
            })
            self.adjustPostFriendsList(userID: friend.id!, friendID: uid, completion: nil)
        }
    }

    func removeFriendRequest(friendID: String, notificationID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        db.collection("users").document(friendID).updateData(["pendingFriendRequests": FieldValue.arrayRemove([uid])])
        db.collection("users").document(uid).collection("notifications").document(notificationID).delete()
    }

    func revokeFriendRequest(friendID: String, notificationID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        db.collection("users").document(uid).updateData(["pendingFriendRequests": FieldValue.arrayRemove([friendID])])
        db.collection("users").document(friendID).collection("notifications").document(notificationID).delete()
    }

    func addFriendToFriendsList(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()

        db.collection("users").document(userID).updateData([
            "friendsList": FieldValue.arrayUnion([friendID]),
            "pendingFriendRequests": FieldValue.arrayRemove([friendID]),
            "topFriends.\(friendID)": 0
        ])
    }

    func sendFriendRequestNotis(friendID: String, notificationID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        let timestamp = Timestamp(date: Date())
        db.collection("users").document(uid).collection("notifications").document(notificationID).updateData(["status": "accepted", "timestamp": timestamp])

        db.collection("users").document(friendID).collection("notifications").document(UUID().uuidString).setData([
            "status": "accepted",
            "timestamp": timestamp,
            "senderID": uid,
            "senderUsername": UserDataModel.shared.userInfo.username,
            "type": "friendRequest",
            "seen": false
        ])
    }

    func adjustPostFriendsList(userID: String, friendID: String, completion: ((Bool) -> Void)?) {
        let db: Firestore = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: friendID).order(by: "timestamp", descending: true).getDocuments { snap, _ in
            guard let snap = snap else { return }
            for doc in snap.documents {
                let hideFromFeed = doc.get("hideFromFeed") as? Bool ?? false
                let privacyLevel = doc.get("privacyLevel") as? String ?? "friends"
                if !hideFromFeed && privacyLevel != "invite" {
                    doc.reference.updateData(["friendsList": FieldValue.arrayUnion([userID])])
                }
            }
            completion?(true)
        }
    }

    func getAttString(caption: String, taggedFriends: [String], font: UIFont, maxWidth: CGFloat) -> ((NSMutableAttributedString, [(rect: CGRect, username: String)])) {
        let attString = NSMutableAttributedString(string: caption)
        attString.addAttribute(NSAttributedString.Key.font, value: font, range: NSRange(0...attString.length - 1))

        var freshRect: [(rect: CGRect, username: String)] = []
        var tags: [(username: String, range: NSRange)] = []

        let words = caption.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            let username = String(word.dropFirst())
            if word.hasPrefix("@") && taggedFriends.contains(where: { $0 == username }) {
                /// get first index of this word
                let atIndexes = caption.indices(of: String(word))
                let currentIndex = atIndexes[0]
                /// make tag rect out of the username + @
                let tag = (username: String(word.dropFirst()), range: NSRange(location: currentIndex, length: word.count))
                if !tags.contains(where: { $0 == tag }) {
                    tags.append(tag)
                    let range = NSRange(location: currentIndex, length: word.count)
                    /// bolded range out of username + @
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: font.pointSize) as Any, range: range)
                }
            }
        }

        for tag in tags {
            var rect = (rect: getRect(str: attString, range: tag.range, maxWidth: maxWidth), username: tag.username)
            rect.0 = CGRect(x: rect.0.minX, y: rect.0.minY, width: rect.0.width, height: rect.0.height)

            if (!freshRect.contains(where: { $0 == rect })) {
                freshRect.append(rect)
            }
        }
        return ((attString, freshRect))
    }

    func getRect(str: NSAttributedString, range: NSRange, maxWidth: CGFloat) -> CGRect {
        let textStorage = NSTextStorage(attributedString: str)
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        let pointer = UnsafeMutablePointer<NSRange>.allocate(capacity: 1)
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: pointer)
        var rect = layoutManager.boundingRect(forGlyphRange: pointer.move(), in: textContainer)
        rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        return rect
    }

    func incrementTopFriends(friendID: String, increment: Int64) {
        let db: Firestore = Firestore.firestore()
        if UserDataModel.shared.userInfo.friendIDs.contains(friendID) {
            db.collection("users").document(UserDataModel.shared.uid).updateData(["topFriends.\(friendID)": FieldValue.increment(increment)])
            db.collection("users").document(friendID).updateData(["topFriends.\(UserDataModel.shared.uid)": FieldValue.increment(increment)])
        }
    }

    func getStatusHeight() -> CGFloat {
        let window = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        return statusHeight
    }

    func getImageLayoutValues(imageAspect: CGFloat) -> (imageHeight: CGFloat, bottomConstraint: CGFloat) {
        let statusHeight = getStatusHeight()
        let maxHeight = UserDataModel.shared.maxAspect * UIScreen.main.bounds.width
        let minY: CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + maxHeight
        let midY = maxY - 86
        let currentHeight = getImageHeight(aspectRatio: imageAspect, maxAspect: UserDataModel.shared.maxAspect)
        let imageBottom: CGFloat = imageAspect > 1.45 ? maxY : imageAspect > 1.1 ? midY : (minY + maxY + currentHeight) / 2 - 15
        let bottomConstraint = UIScreen.main.bounds.height - imageBottom
        return (currentHeight, bottomConstraint)
    }

    func updatePostInviteLists(mapID: String, inviteList: [String]) {
        let db = Firestore.firestore()
        DispatchQueue.global().async {
            db.collection("posts").whereField("mapID", isEqualTo: mapID).whereField("hideFromFeed", isEqualTo: true).getDocuments { snap, _ in
                guard let snap = snap else { return }
                for doc in snap.documents {
                    doc.reference.updateData(["inviteList": inviteList])
                }
            }
        }
    }
}
