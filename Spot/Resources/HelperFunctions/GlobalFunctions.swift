//
//  GlobalFunctions.swift
//  Spot
//
//  Created by kbarone on 4/7/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Photos
import Firebase
import Geofirestore
import MapKit
import FirebaseFunctions
import CoreData

extension UIViewController {
    
    func isValidUsername(username: String) -> Bool {
        let regEx = "^[a-zA-Z0-9_.]*$"
        let pred = NSPredicate(format:"SELF MATCHES %@", regEx)
        return pred.evaluate(with: username) && username.count > 1
    }
    
    func isValidEmail(email:String?) -> Bool {
        guard email != nil else { return false }
        let regEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let pred = NSPredicate(format:"SELF MATCHES %@", regEx)
        return pred.evaluate(with: email)
    }
    
    func getTagUserString(text: String, cursorPosition: Int) -> (text: String, containsAt: Bool) {
    
        let atIndices = text.indices(of: "@")
        var wordIndices = text.indices(of: " ")
        wordIndices.append(contentsOf: text.indices(of: "\n")) /// add new lines
        if !wordIndices.contains(0) { wordIndices.insert(0, at: 0) } /// first word not included
        wordIndices.sort(by: {$0 < $1})
        
        for atIndex in atIndices {
            
            if cursorPosition > atIndex {
                
                var i = 0
                for w in wordIndices {
                    
                    /// cursor is > current word, < next word, @ is 1 more than current word , < next word OR last word in string
                    if (w <= cursorPosition && (i == wordIndices.count - 1 || cursorPosition <= wordIndices[i + 1])) && ((atIndex == 0 && i == 0 || atIndex == w + 1) && (i == wordIndices.count - 1 || cursorPosition <= wordIndices[i + 1])) {
                        
                        let start = text.index(text.startIndex, offsetBy: w)
                        let end = text.index(text.startIndex, offsetBy: cursorPosition)
                        let range = start..<end
                        let currentWord = text[range].replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "@", with: "").replacingOccurrences(of: "\n", with: "") ///  remove space and @ from word
                        return (currentWord, true)
                    } else { i += 1; continue }
                }
            }
        }
        return ("", false)
    }
    
    func isFriends(id: String) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if id == uid || (UserDataModel.shared.userInfo.friendIDs.contains(where: {$0 == id}) && !(UserDataModel.shared.adminIDs.contains(id))) { return true }
        return false
    }
    
    func hasPOILevelAccess(creatorID: String, privacyLevel: String, inviteList: [String]) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
        if UserDataModel.shared.adminIDs.contains(where: {$0 == creatorID}) {
            if uid != creatorID {
                return false
            }
        }
        if privacyLevel == "friends" {
            if !UserDataModel.shared.userInfo.friendIDs.contains(where: {$0 == creatorID}) {
                if uid != creatorID {
                    return false
                }
            }
        } else if privacyLevel == "invite" {
            if !inviteList.contains(where: {$0 == uid}) {
                return false
            }
        }
        return true
    }
    
    func hasPostAccess(post: MapPost) -> Bool {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if uid == post.posterID { return true }
        if UserDataModel.shared.adminIDs.contains(where: {$0 == post.posterID}) { return false }
        
        if post.privacyLevel == "friends" {
            if !UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) { return false }
        } else if post.privacyLevel == "invite" {
            if !(post.inviteList?.contains(uid) ?? false) { return false }
        }
        
        return true
    }
    
    func setPostLocations(postLocation: CLLocationCoordinate2D, postID: String) {
        
        let location = CLLocation(latitude: postLocation.latitude, longitude: postLocation.longitude)
        
        GeoFirestore(collectionRef: Firestore.firestore().collection("posts")).setLocation(location: location, forDocumentWithID: postID) { (error) in
            if (error != nil) {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }
    
    func setSpotLocations(spotLocation: CLLocationCoordinate2D, spotID: String) {
        
        let location = CLLocation(latitude: spotLocation.latitude, longitude: spotLocation.longitude)
        
        GeoFirestore(collectionRef: Firestore.firestore().collection("spots")).setLocation(location: location, forDocumentWithID: spotID) { (error) in
            if (error != nil) {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }
    
    func setMapLocations(mapLocation: CLLocationCoordinate2D, documentID: String) {
        let location = CLLocation(latitude: mapLocation.latitude, longitude: mapLocation.longitude)
        
        GeoFirestore(collectionRef: Firestore.firestore().collection("mapLocations")).setLocation(location: location, forDocumentWithID: documentID) { (error) in
            if (error != nil) {
                print("An error occured: \(String(describing: error))")
            } else {
                print("Saved location successfully!")
            }
        }
    }
    
    func addToCityList(city: String) {
        /// this should be a backend func but didnt feel like doing all the geocoding nonsense
        let db = Firestore.firestore()
        let query = db.collection("cities").whereField("cityName", isEqualTo: city)
        
        query.getDocuments { [weak self] (cityDocs, err) in
            
            guard let self = self else { return }
            if cityDocs?.documents.count ?? 0 == 0 {
                
                self.getCoordinateFrom(address: city) { coordinate, error in
                    
                    guard let coordinate = coordinate, error == nil else { return }

                    let id = UUID().uuidString
                    db.collection("cities").document(id).setData(["cityName" : city])
                    GeoFirestore(collectionRef: db.collection("cities")).setLocation(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), forDocumentWithID: id) { (error) in
                        print(city, "Location:", coordinate)
                    }
                }
            }
        }
    }
    
    // move to backend func
    func updateUserTags(oldUsername: String, newUsername: String) {
        
        let db = Firestore.firestore()
        db.collection("posts").whereField("taggedUsers", arrayContains: oldUsername).getDocuments { [weak self] snap, err in
            
            guard let self = self else { return }
            if err != nil || snap?.documents.count == 0 { return }
            
            for doc in snap!.documents {
                guard var taggedUsers = doc.get("taggedUsers") as? [String] else { continue }
                guard let caption = doc.get("caption") as? String else { continue }
                taggedUsers.removeAll(where: {$0 == oldUsername})
                taggedUsers.append(newUsername)
                let newCaption = self.getNewCaption(oldUsername: oldUsername, newUsername: newUsername, caption: caption)
                doc.reference.updateData(["taggedUsers" : taggedUsers, "caption": newCaption])
            }
        }
        
        db.collection("spots").whereField("taggedUsers", arrayContains: oldUsername).getDocuments { [weak self] snap, err in
            
            guard let self = self else { return }
            if err != nil || snap?.documents.count == 0 { return }
            
            for doc in snap!.documents {
                guard var taggedUsers = doc.get("taggedUsers") as? [String] else { continue }
                guard let description = doc.get("description") as? String else { continue }
                taggedUsers.removeAll(where: {$0 == oldUsername})
                taggedUsers.append(newUsername)
                let newDescription = self.getNewCaption(oldUsername: oldUsername, newUsername: newUsername, caption: description)
                doc.reference.updateData(["taggedUsers" : taggedUsers, "description": newDescription])
            }
        }
    }
            
    /*
    */
    func getNewCaption(oldUsername: String, newUsername: String, caption: String) -> String {
        
        var newCaption = caption
        let words = newCaption.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let username = String(word.dropFirst())
            if word.hasPrefix("@") && username == oldUsername {
                let atIndexes = newCaption.indices(of: String(username))
                let firstIndex = atIndexes[0]
                let nsrange = NSMakeRange(firstIndex, username.count)
                guard let range = Range(nsrange, in: newCaption) else { continue }
                newCaption.removeSubrange(range)
                newCaption.insert(contentsOf: newUsername, at: newCaption.index(newCaption.startIndex, offsetBy: firstIndex))
            }
        }
        
        return newCaption
    }
    
    func getCoordinateFrom(address: String, completion: @escaping(_ coordinate: CLLocationCoordinate2D?, _ error: Error?) -> () ) {
        CLGeocoder().geocodeAddressString(address) { completion($0?.first?.location?.coordinate, $1) }
    }
    
    func ResizeImage(with image: UIImage?, scaledToFill size: CGSize) -> UIImage? {
        
        let scale: CGFloat = max(size.width / (image?.size.width ?? 0.0), size.height / (image?.size.height ?? 0.0))
        let width: CGFloat = round((image?.size.width ?? 0.0) * scale)
        let height: CGFloat =  round((image?.size.height ?? 0.0) * scale)
        let imageRect = CGRect(x: (size.width - width) / 2.0 - 1.0, y: (size.height - height) / 2.0 - 1.5, width: width + 2.0, height: height + 3.0)
        
        /// if image rect size > image size, make them the same?
        
        let clipSize = CGSize(width: floor(size.width), height: floor(size.height)) /// fix rounding error for images taken from camera
        UIGraphicsBeginImageContextWithOptions(clipSize, false, 0.0)
        
        image?.draw(in: imageRect)

        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
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
        let duration = notification.userInfo![durationKey] as! Double
        
        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo![frameKey] as! NSValue
        
        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo![curveKey] as! Int
        let curve = UIView.AnimationCurve(rawValue: curveValue)!

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue.cgRectValue)
            
            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.view?.layoutIfNeeded()
        }
        
        // Start the animation
        animator.startAnimation()
    }
}
// https://www.advancedswift.com/animate-with-ios-keyboard-swift/

/// upload post functions
extension UIViewController {
    
    func uploadPostImage(_ images: [UIImage], postID: String, progressFill: UIView, fullWidth: CGFloat, completion: @escaping ((_ urls: [String], _ failed: Bool) -> ())){
        
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
            if progressFill.bounds.width != fullWidth && !URLs.contains(where: {$0 != ""}) && !failed {
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
        
        let interval = 0.7/Double(images.count)
        var downloadCount: CGFloat = 0
        
        for image in images {
            
            let imageID = UUID().uuidString
            let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageID)")
            
            guard var imageData = image.jpegData(compressionQuality: 0.5) else { print("error 1"); completion([], true); return }
            
            if imageData.count > 1000000 {
                imageData = image.jpegData(compressionQuality: 0.3)!
            }
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
        
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                
                if error != nil { if !failed { failed = true; completion([], true)}; return }
                storageRef.downloadURL { (url, err) in
                    if error != nil { if !failed { failed = true; completion([], true)}; return }
                    let urlString = url!.absoluteString
                    
                    let i = images.lastIndex(where: {$0 == image})
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

    func uploadPost(post: MapPost, map: CustomMap?) {
        /// send local notification first
        var notiPost = post
        notiPost.id = post.id!
        let commentObject = MapComment(id: UUID().uuidString, comment: post.caption, commenterID: post.posterID, taggedUsers: post.taggedUsers, timestamp: post.timestamp, userInfo: UserDataModel.shared.userInfo)
        notiPost.commentList = [commentObject]
        notiPost = setSecondaryPostValues(post: notiPost)
        notiPost.userInfo = UserDataModel.shared.userInfo
        NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post" : notiPost as Any, "map": map as Any]))

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(post.id!)
        do {
            try postRef.setData(from: post)
            self.setPostLocations(postLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), postID: post.id!)
            
            let commentRef = postRef.collection("comments").document(commentObject.id!)

            do {
                try commentRef.setData(from: commentObject)
            } catch {
                print("failed uploading comment")
            }
        } catch {
            print("failed uploading post")
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
            let spotValues =  ["city" : post.city ?? "",
                               "spotName" : spot.spotName,
                               "lowercaseName": lowercaseName,
                               "description": post.caption,
                               "createdBy": uid,
                               "posterUsername" : UserDataModel.shared.userInfo.username,
                               "visitorList": spotVisitors,
                               "inviteList" : spot.inviteList ?? [],
                               "privacyLevel": spot.privacyLevel,
                               "taggedUsers": post.taggedUsers ?? [],
                               "spotLat": spot.spotLat,
                               "spotLong" : spot.spotLong,
                               "imageURL" : post.imageURLs.first ?? "",
                               "phone" : spot.phone ?? "",
                               "poiCategory" : spot.poiCategory ?? "",
                               "postIDs": [post.id!],
                               "postTimestamps": [timestamp],
                               "posterIDs": [uid],
                               "postPrivacies": [post.privacyLevel!],
                               "searchKeywords": keywords,
                               "tagDictionary": tagDictionary,
                               "posterDictionary": posterDictionary] as [String : Any]
            
            db.collection("spots").document(spot.id!).setData(spotValues, merge: true)
                        
            if submitPublic { db.collection("submissions").document(spot.id!).setData(["spotID" : spot.id!])}
            self.setSpotLocations(spotLocation: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), spotID: spot.id!)
            
            var notiSpot = spot
            notiSpot.checkInTime = Int64(interval)
            NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot" : notiSpot])
            
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
            var uploadMap = map
            uploadMap.postTimestamps.append(post.timestamp)
            do {
                try mapRef.setData(from: uploadMap, merge: true)
            } catch {
                print("failed uploading map")
            }
        } else {
            /// update values with backend function
            let functions = Functions.functions()
            let postLocation = ["lat": post.postLat, "long": post.postLong]
            let spotLocation = ["lat": post.spotLat ?? 0.0, "long": post.spotLong ?? 0.0]
            var posters = [UserDataModel.shared.uid]
            if !(post.addedUsers?.isEmpty ?? true) { posters.append(contentsOf: post.addedUsers!) }
            print("spot id", post.spotID)
            functions.httpsCallable("runMapTransactions").call(["mapID": map.id!, "uid": UserDataModel.shared.uid, "postID": post.id!, "postImageURL": post.imageURLs.first ?? "", "postLocation": postLocation, "posters": posters, "posterUsername": UserDataModel.shared.userInfo.username, "spotID": post.spotID ?? "", "spotName": post.spotName ?? "", "spotLocation": spotLocation]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
        let documentID = UUID().uuidString
        db.collection("mapLocations").document(documentID).setData(["mapID": map.id!, "postID": post.id!])
        setMapLocations(mapLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), documentID: documentID)
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
            var userValues = ["spotScore" : FieldValue.increment(Int64(3))]
            if tag != "" { userValues["tagDictionary.\(tag)"] = FieldValue.increment(Int64(1)) }
            
            /// remove this user for topFriends increments
            var dictionaryFriends = posters
            dictionaryFriends.removeAll(where: {$0 == poster})
            /// increment top friends if added friends
            for user in dictionaryFriends {
                incrementTopFriends(friendID: user, increment: 5)
            }
            
            db.collection("users").document(poster).updateData(userValues)
        }
    }
        
    func removeFriend(friendID: String) {
        print("remove friend")
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let functions = Functions.functions()
        
        removeFriendFromFriendsList(userID: uid, friendID: friendID)
        removeFriendFromFriendsList(userID: friendID, friendID: uid)

        functions.httpsCallable("removeFriend").call(["userID": uid, "friendID": friendID]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
    
    func removeFriendFromFriendsList(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()
        
        db.collection("users").document(userID).updateData([
            "friendsList" : FieldValue.arrayRemove([friendID]),
            "topFriends.\(friendID)" : FieldValue.delete()
        ])
    }

    
    func getQueriedUsers(userList: [UserProfile], searchText: String) -> [UserProfile] {
        var queriedUsers: [UserProfile] = []
        let usernameList = userList.map({$0.username})
        let nameList = userList.map({$0.name})
        
        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })
        
        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })
        
        for username in filteredUsernames {
            if let user = userList.first(where: {$0.username == username}) { queriedUsers.append(user) }
        }
        
        for name in filteredNames {
            if let user = userList.first(where: {$0.name == name}) {
                if !queriedUsers.contains(where: {$0.id == user.id}) { queriedUsers.append(user) }
            }
        }
        return queriedUsers
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
        }
        catch let error as NSError {
            print("could not fetch. \(error)")
        }
    }
}


extension CLPlacemark {
    
    func addressFormatter(number: Bool) -> String {
        
        var addressString = ""

        /// add number if locationPicker
        if number && subThoroughfare != nil {
            addressString = addressString + subThoroughfare! + " "
        }

        if thoroughfare != nil {
            addressString = addressString + thoroughfare!
        }

        if locality != nil {
            if addressString != "" {
                addressString = addressString + ", "
            }
            addressString = addressString + locality!
        }
        
        if country != nil {
            
            /// add state name for US
            if country! == "United States" {
                if administrativeArea != nil {
                    
                    if addressString != "" { addressString = addressString + ", " }
                    addressString = addressString + administrativeArea!
                }
            }
            
            if addressString != "" { addressString = addressString + ", " }
            addressString = addressString + country!
        }
        
        return addressString
    }
}

extension CLLocationDistance {
    
    func getLocationString() -> String {
        let feet = inFeet()
        if feet > 528 {
            let miles = inMiles()
            let milesString = String(format: "%.2f", miles)
            return milesString + " mi"
        } else {
            let feetString = String(Int(feet))
            return feetString + " ft"
        }
    }
    
    func inFeet() -> CLLocationDistance {
        return self * 3.28084
    }
    
    func inMiles() -> CLLocationDistance {
        return self * 0.00062137
    }
}

extension NSObject {
    
    func getTaggedUsers(text: String) -> [UserProfile] {
        var selectedUsers: [UserProfile] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for w in words {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.userInfo.friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append(f)
                }
            }
        }
        return selectedUsers
    }
    
    func setSecondaryPostValues(post: MapPost) -> MapPost {
        var newPost = post
        /// round to nearest line height
        newPost.captionHeight = self.getCaptionHeight(caption: post.caption, fontSize: 14.5, maxCaption: 51.9)
        return newPost
    }
    
    func getCaptionHeight(caption: String, fontSize: CGFloat, maxCaption: CGFloat) -> CGFloat {
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 80, height: UIScreen.main.bounds.height))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCompactText-Medium", size: fontSize)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()

        return maxCaption != 0 ? min(maxCaption, tempLabel.frame.height.rounded(.up)) : tempLabel.frame.height
    }
    
    func getImageHeight(aspectRatios: [CGFloat], maxAspect: CGFloat) -> CGFloat {
        var imageAspect =  min((aspectRatios.max() ?? 0.033) - 0.033, maxAspect)
        imageAspect = getRoundedAspectRatio(aspect: imageAspect)
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }
    
    func getImageHeight(aspectRatio: CGFloat, maxAspect: CGFloat) -> CGFloat {
        var imageAspect =  min(aspectRatio, maxAspect)
        imageAspect = getRoundedAspectRatio(aspect: imageAspect)
        let imageHeight = UIScreen.main.bounds.width * imageAspect
        return imageHeight
    }
    
    func getRoundedAspectRatio(aspect: CGFloat) -> CGFloat {
        var imageAspect = aspect
        if imageAspect > 1.1 && imageAspect < 1.45 { imageAspect = 1.45 } /// stretch iPhone vertical
        if imageAspect > 1.45 { imageAspect = UserDataModel.shared.maxAspect } /// round to max aspect
        return imageAspect
    }
    
    func getComments(postID: String, completion: @escaping (_ comments: [MapComment]) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        var commentList: [MapComment] = []
        
        DispatchQueue.global().async {
            db.collection("posts").document(postID).collection("comments").order(by: "timestamp", descending: true).getDocuments { [weak self] (commentSnap, err) in
                
                if err != nil { completion(commentList); return }
                if commentSnap!.documents.count == 0 { completion(commentList); return }
                guard let self = self else { return }

                var index = 0
                for doc in commentSnap!.documents {
                    do {
                        let commentInf = try doc.data(as: MapComment.self)
                        guard var commentInfo = commentInf else { index += 1; if index == commentSnap!.documents.count { completion(commentList) }; continue }
                                            
                        self.getUserInfo(userID: commentInfo.commenterID) { user in
                            commentInfo.userInfo = user
                            if !commentList.contains(where: {$0.id == doc.documentID}) {
                                commentList.append(commentInfo)
                                commentList.sort(by: {$0.seconds < $1.seconds})
                            }
                            
                            index += 1; if index == commentSnap!.documents.count { completion(commentList) }
                        }
                        
                    } catch { index += 1; if index == commentSnap!.documents.count { completion(commentList) }; continue }
                }
            }
        }
    }
    
    func getPost(postID: String, completion: @escaping (_ post: MapPost) -> Void) {
        let db: Firestore! = Firestore.firestore()
        let emptyPost = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp())
        
        DispatchQueue.global().async {
            db.collection("posts").document(postID).getDocument { [weak self] doc, err in
                guard let self = self else { return }
                if err != nil { completion(emptyPost); return }
                
                do {
                    let unwrappedInfo = try doc?.data(as: MapPost.self)
                    guard var postInfo = unwrappedInfo else { completion(emptyPost); return }
                    
                    var count = 0
                    self.getUserInfo(userID: postInfo.posterID) { user in
                        postInfo.userInfo = user
                        count += 1
                        if count == 2 { completion(postInfo); return }
                    }
                    
                    self.getComments(postID: postID) { comments in
                        postInfo.commentList = comments
                        count += 1
                        if count == 2 { completion(postInfo); return }
                    }
                    
                } catch { completion(emptyPost); return }
            }
        }
    }

    func getUserInfo(userID: String, completion: @escaping (_ user: UserProfile) -> Void) {
        
        let db: Firestore! = Firestore.firestore()
        
        if let user = UserDataModel.shared.userInfo.friendsList.first(where: {$0.id == userID}) {
            completion(user)
            return
            
        } else if userID == UserDataModel.shared.uid {
            completion(UserDataModel.shared.userInfo)
            return
            
        } else {
            let emptyProfile = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: "")
            DispatchQueue.global().async {
                db.collection("users").document(userID).getDocument { (doc, err) in
                    if err != nil { return }
                    do {
                        let userInfo = try doc!.data(as: UserProfile.self)
                        guard var info = userInfo else { completion(emptyProfile); return }
                        info.id = doc!.documentID
                        completion(info)
                        return
                    } catch { completion(emptyProfile); return }
                }
            }
        }
    }
    
    func setPostDetails(post: MapPost, completion: @escaping (_ post: MapPost) -> Void) {
        var postInfo = setSecondaryPostValues(post: post)
        /// detail group tracks comments and added users fetches
        let detailGroup = DispatchGroup()
        detailGroup.enter()
        getUserInfo(userID: postInfo.posterID) { user in
            postInfo.userInfo = user
            detailGroup.leave()
        }
        
        detailGroup.enter()
        self.getComments(postID: postInfo.id!) { comments in
            postInfo.commentList = comments
            detailGroup.leave()
        }
        
        detailGroup.enter()
        /// taggedUserGroup tracks tagged user fetch
        let taggedUserGroup = DispatchGroup()
        for userID in postInfo.taggedUserIDs ?? [] {
            taggedUserGroup.enter()
            self.getUserInfo(userID: userID) { user in
                postInfo.addedUserProfiles!.append(user)
                taggedUserGroup.leave()
            }
        }
        
        taggedUserGroup.notify(queue: .global()) {
            detailGroup.leave()
        }
        detailGroup.notify(queue: .global()) {
            completion(postInfo)
            return
        }
    }
    
    func getUserFromUsername(username: String, completion: @escaping (_ user: UserProfile?) -> Void) {
        let db: Firestore! = Firestore.firestore()
        if let user = UserDataModel.shared.userInfo.friendsList.first(where: {$0.username == username}) {
            completion(user)
            return
        } else {
            DispatchQueue.global().async {
                db.collection("users").whereField("username", isEqualTo: username).getDocuments { snap, err in
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
        let db: Firestore! = Firestore.firestore()
        let spotRef = db.collection("spots").document(spotID)
        
        DispatchQueue.global().async {
            spotRef.getDocument { (doc, err) in
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
        let db: Firestore! = Firestore.firestore()
        let mapRef = db.collection("maps").document(mapID)
        
        DispatchQueue.global().async {
            mapRef.getDocument { (doc, err) in
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

    func addFriend(senderProfile: UserProfile, receiverID: String) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore = Firestore.firestore()
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(receiverID).collection("notifications").document(notiID)
        
        let time = Date()
        
        let values = ["senderID" : uid,
                      "type" : "friendRequest",
                      "senderUsername" : UserDataModel.shared.userInfo.username,
                      "timestamp" : time,
                      "status" : "pending",
                      "seen" : false
                      
        ] as [String : Any]
        ref.setData(values)
        
        db.collection("users").document(uid).updateData(["pendingFriendRequests" : FieldValue.arrayUnion([receiverID])])
    }

    func acceptFriendRequest(friendID: String, notificationID: String) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let functions = Functions.functions()
                
        addFriendToFriendsList(userID: uid, friendID: friendID)
        addFriendToFriendsList(userID: friendID, friendID: uid)
        sendFriendRequestNotis(friendID: friendID, notificationID: notificationID)
        
        functions.httpsCallable("acceptFriendRequest").call(["userID": uid, "friendID": friendID, "username": UserDataModel.shared.userInfo.username]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
    
    func removeFriendRequest(friendID: String, notificationID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        db.collection("users").document(friendID).updateData(["pendingFriendRequests" : FieldValue.arrayRemove([uid])])
        db.collection("users").document(uid).collection("notifications").document(notificationID).delete()
    }
    
    func addFriendToFriendsList(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()
        
        db.collection("users").document(userID).updateData([
            "friendsList" : FieldValue.arrayUnion([friendID]),
            "pendingFriendRequests" : FieldValue.arrayRemove([friendID]),
            "topFriends.\(friendID)" : 0
        ])
    }
    
    func sendFriendRequestNotis(friendID: String, notificationID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        let timestamp = Timestamp(date: Date())
        db.collection("users").document(uid).collection("notifications").document(notificationID).updateData(["status" : "accepted", "timestamp": timestamp])
        
        db.collection("users").document(friendID).collection("notifications").document(UUID().uuidString).setData([
            "status": "accepted",
            "timestamp": timestamp,
            "senderID": uid,
            "senderUsername": UserDataModel.shared.userInfo.username,
            "type": "friendRequest",
            "seen": false
        ])
    }
    
    func adjustPostFriendsList(userID: String, friendID: String) {
        let db: Firestore = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: friendID).order(by: "timestamp", descending: true).getDocuments { snap, err in
            guard let snap = snap else { return }
            for doc in snap.documents {
                let hideFromFeed = doc.get("hideFromFeed") as? Bool ?? false
                let privacyLevel = doc.get("privacyLevel") as? String ?? "friends"
                if !hideFromFeed && privacyLevel != "invite" {
                    doc.reference.updateData(["friendsList" : FieldValue.arrayUnion([userID])])
                }
            }
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
            if word.hasPrefix("@") && taggedFriends.contains(where: {$0 == username}) {
                /// get first index of this word
                let atIndexes = caption.indices(of: String(word))
                let currentIndex = atIndexes[0]
                /// make tag rect out of the username + @
                let tag = (username: String(word.dropFirst()), range: NSMakeRange(currentIndex, word.count))
                if !tags.contains(where: {$0 == tag}) {
                    tags.append(tag)
                    let range = NSMakeRange(currentIndex, word.count)
                    /// bolded range out of username + @
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: font.pointSize) as Any, range: range)
                }
            }
        }
        
        for tag in tags {
            var rect = (rect: getRect(str: attString, range: tag.range, maxWidth: maxWidth ), username: tag.username)
            rect.0 = CGRect(x: rect.0.minX, y: rect.0.minY, width: rect.0.width, height: rect.0.height)
            
            if (!freshRect.contains(where: {$0 == rect})) {
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
        textContainer.lineFragmentPadding = 10
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
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        return statusHeight
    }
    
    func getImageLayoutValues(imageAspect: CGFloat) -> (imageHeight: CGFloat, bottomConstraint: CGFloat) {
        let statusHeight = getStatusHeight()
        let maxHeight = UserDataModel.shared.maxAspect * UIScreen.main.bounds.width
        let minY : CGFloat = UIScreen.main.bounds.height > 800 ? statusHeight : 2
        let maxY = minY + maxHeight
        let currentHeight = getImageHeight(aspectRatio: imageAspect, maxAspect: UserDataModel.shared.maxAspect)
        let imageBottom: CGFloat = imageAspect > 1.1 ? maxY : (minY + maxY + currentHeight)/2 - 15
        let bottomConstraint = UIScreen.main.bounds.height - imageBottom
        return (currentHeight, bottomConstraint)
    }
}

extension String {

    func indices(of string: String) -> [Int] {
        var indices = [Int]()
        var searchStartIndex = self.startIndex

        while searchStartIndex < self.endIndex,
            let range = self.range(of: string, range: searchStartIndex..<self.endIndex),
            !range.isEmpty
        {
            let index = distance(from: self.startIndex, to: range.lowerBound)
            indices.append(index)
            searchStartIndex = range.upperBound
        }

        return indices
    }
    
    func getKeywordArray() -> [String] {
        
        var keywords: [String] = []
        
        keywords.append(contentsOf: getKeywordsFrom(index: 0))
        let atIndexes = indices(of: " ")
        
        for index in atIndexes {
            if index == count - 1 { continue }
            keywords.append(contentsOf: getKeywordsFrom(index: index + 1))
        }
        
        return keywords
    }
    
    func getKeywordsFrom(index: Int) -> [String] {
        
        var keywords: [String] = []
        if index > count { return keywords }
        let subString = suffix(count - index)
        
        var word = ""
        for sub in subString {
            word = word + String(sub)
            keywords.append(word)
        }
        
        return keywords
    }

    func formatNumber() -> String {
        var newNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined() /// remove dashes and spaces
        newNumber = String(newNumber.suffix(10)) /// match based on last 10 digits to eliminate country codes and formatting
        return newNumber
    }
    
    func spacesTrimmed() -> String {
        var newString = self
        while newString.last?.isWhitespace ?? false { newString = String(newString.dropLast(1))}
        while newString.first?.isWhitespace ?? false { newString = String(newString.dropFirst(1))}
        return newString
    }
}

extension UIColor{
    /** An easy way to get the color by providing the hexstring */
    public convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    /** Return UIColor lighter */
    public func lighter(by percentage: CGFloat = 50.0) -> UIColor? {
        return self.adjust(by: abs(percentage) )
    }
    /** Return UIColor darker */
    public func darker(by percentage: CGFloat = 50.0) -> UIColor? {
        return self.adjust(by: -1 * abs(percentage) )
    }
    
    public func adjust(by percentage: CGFloat = 50.0) -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: min(red + percentage/100, 1.0),
                           green: min(green + percentage/100, 1.0),
                           blue: min(blue + percentage/100, 1.0),
                           alpha: alpha)
        } else {
            return nil
        }
    }
    
    /** Return contrast UIColor */
    public func contrast() -> UIColor? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: 1 - red, green: 1 - green, blue: 1 - blue, alpha: alpha)
        }
        else {
            return nil
        }
    }
}

extension UIScrollView {
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesBegan(touches, with: event)
    }
    
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesMoved(touches, with: event)
    }
    
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesEnded(touches, with: event)
    }
    
}

extension UIImageView {
    
    func animateGIF(directionUp: Bool, counter: Int) {
        
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { self.stopPostAnimation(); return }
        
        var newDirection = directionUp
        var newCount = counter
        
        if let postImage = self as? PostImageView { postImage.animationIndex = newCount; postImage.activeAnimation = true }
        /// for smooth animations on likes / other table reloads
        
        if directionUp {
            if counter == animationImages!.count - 1 {
                newDirection = false
                newCount = animationImages!.count - 2
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }

        let duration: TimeInterval = 0.049
        
        UIView.transition(with: self, duration: duration, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
                            guard let self = self else { return }
            if self.animationImages?.isEmpty ?? true || counter >= self.animationImages?.count ?? 0 { self.stopPostAnimation(); return }
                            self.image = self.animationImages![counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.005) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount)
        }
    }
    
    func stopPostAnimation() {
        if let postImage = self as? PostImageView { postImage.animationIndex = 0; postImage.activeAnimation = false }
    }
    
    func animate5FrameAlive(directionUp: Bool, counter: Int) {
    
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { return }

        var newDirection = directionUp
        var newCount = counter
        
        if directionUp {
            if counter == 4 {
                newDirection = false
                newCount = 3
            } else {
                newCount += 1
            }
        } else {
            if counter == 0 {
                newDirection = true
                newCount = 1
            } else {
                newCount -= 1
            }
        }
        
        UIView.transition(with: self, duration: 0.08, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
            guard let self = self else { return }
                            if self.animationImages?.isEmpty ?? true { return }
                            if counter >= self.animationImages?.count ?? 0 { return }
                            self.image = self.animationImages![counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
            guard let self = self else { return }
            self.animate5FrameAlive(directionUp: newDirection, counter: newCount)
        }
    }

    
    
    func roundCornersForAspectFit(radius: CGFloat)
    {
        if let image = image {
            //calculate drawingRect
            let boundsScale = bounds.size.width / bounds.size.height
            let imageScale = image.size.width / image.size.height
            
            var drawingRect : CGRect = bounds
            
            if boundsScale > imageScale {
                drawingRect.size.width =  drawingRect.size.height * imageScale
                drawingRect.origin.x = (bounds.size.width - drawingRect.size.width) / 2
                
            } else {
                drawingRect.size.height = drawingRect.size.width / imageScale
                drawingRect.origin.y = (bounds.size.height - drawingRect.size.height) / 2
            }
            let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: radius)
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            layer.mask = mask
        }
    }
}

extension UINavigationBar {
    
    func addShadow() {
        /// gray line at bottom of nav bar
        if let _ = layer.sublayers?.first(where: {$0.name == "bottomLine"}) { return }
        
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0.0, y: bounds.height - 1, width: bounds.width, height: 1.0)
        bottomLine.backgroundColor = UIColor(red: 0.121, green: 0.121, blue: 0.121, alpha: 1).cgColor
        bottomLine.shouldRasterize = true
        bottomLine.name = "bottomLine"
        layer.addSublayer(bottomLine)
        
        /// mask to show under nav bar
        layer.masksToBounds = false
        layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.37).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 6
        layer.position = center
        layer.shouldRasterize = true
    }
    
    func removeShadow() {
        if let sub = layer.sublayers?.first(where: {$0.name == "bottomLine"}) { sub.removeFromSuperlayer() }
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 0)
    }
    
    func addGradientBackground(alpha: CGFloat) {
        /// gradient nav bar background
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0.0
        let navBarHeight = statusHeight + bounds.height

        let gradient = CAGradientLayer()
        let sizeLength: CGFloat = UIScreen.main.bounds.size.height * 2
        let defaultNavigationBarFrame = CGRect(x: 0, y: 0, width: sizeLength, height: navBarHeight)
        
        gradient.frame = defaultNavigationBarFrame
        gradient.colors = [UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: alpha).cgColor, UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: alpha).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = self.image(fromLayer: gradient)
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(self.image(fromLayer: gradient), for: .default)
        }
    }
    
    func addBlackBackground() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .black
            appearance.titleTextAttributes[.foregroundColor] = UIColor.white
            appearance.titleTextAttributes[.font] = UIFont(name: "SFCompactText-Heavy", size: 19)!
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(color: UIColor.black), for: .default)
        }
    }
    
    func addWhiteBackground() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .white
            appearance.titleTextAttributes[.foregroundColor] = UIColor.black
            appearance.titleTextAttributes[.font] = UIFont(name: "SFCompactText-Heavy", size: 19)!
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(color: UIColor.white), for: .default)
        }
    }
    
    func removeBackgroundImage() {
                
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = UIImage()
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(), for: .default)
        }
    }
    
    func image(fromLayer layer: CALayer) -> UIImage {
        UIGraphicsBeginImageContext(layer.frame.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return outputImage!
    }
}

extension UINavigationItem {
    func addBlackBackground() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundImage = UIImage()
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
    
    func removeBackgroundImage() {
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundImage = UIImage()
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        }
    }
}

extension UITextView {
    
    // convert to nsRange in order to get correct cursor position with emojis
    func getCursorPosition() -> Int {
        var cursorPosition = 0
        if let selectedRange = selectedTextRange {
            let utfPosition = offset(from: beginningOfDocument, to: selectedRange.end)
            let positionRange = NSRange(location: 0, length: utfPosition)
            let stringOffset = Range(positionRange, in: text!)!
            let indexPosition = stringOffset.upperBound
            cursorPosition = text.distance(from: text.startIndex, to: indexPosition)
        }
        return cursorPosition
    }
    
    // run when user taps a username to tag
    func addUsernameAtCursor(username: String) {
        var tagText = text ?? ""
        let cursorPosition = getCursorPosition()
        
        var wordIndices = text.indices(of: " ")
        wordIndices.append(contentsOf: text.indices(of: "\n")) /// add new lines
        if !wordIndices.contains(0) { wordIndices.insert(0, at: 0) } /// first word not included
        wordIndices.sort(by: {$0 < $1})
        
        var currentWordIndex = 0; var nextWordIndex = 0; var i = 0
        /// get current word
        for index in wordIndices {
            if index < cursorPosition {
                if i == wordIndices.count - 1 { currentWordIndex = index; nextWordIndex = text.count }
                else if cursorPosition <= wordIndices[i + 1] { currentWordIndex = index; nextWordIndex = wordIndices[i + 1] }
                i += 1
            }
        }
        
        let suffix = text.suffix(text.count - currentWordIndex) /// get end of string to figure out where @ is
        
        /// from index represents the text for this string after the @
        guard let atIndex = String(suffix).indices(of: "@").first else { return }
        let start = currentWordIndex + atIndex + 1
        let fromIndex = text.index(text.startIndex, offsetBy: start)
        
        /// word length = number of characters typed of the username so far
        let wordLength = nextWordIndex - currentWordIndex - 2
        /// remove any characters after the @

        /// patch fix for emojis not working at the end of strings -> start from end of string and work backwards
        if nextWordIndex == tagText.count {
            while tagText.last != "@" { tagText.removeLast() }
            tagText.append(contentsOf: username)
            
        } else {
            /// standard removal process with string.index -> string.index is fucked up if using emojis bc it uses utf16 characters so this might fail if you try to insert in the middle of a string with an emoji coming before it in that string but this is an edge case
            if wordLength > 0 {for _ in 0...wordLength - 1 { tagText.remove(at: fromIndex) } }
            /// insert username after @
            tagText.insert(contentsOf: username, at: fromIndex) //// append username
        }
        text = tagText
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount:CGFloat){
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.leftView = paddingView
        self.leftViewMode = .always
    }
    func setRightPaddingPoints(_ amount:CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.size.height))
        self.rightView = paddingView
        self.rightViewMode = .always
    }
}

extension UIAlertAction {
    public var titleTextColor: UIColor? {
        get {
            return self.value(forKey: "titleTextColor") as? UIColor
        } set {
            self.setValue(newValue, forKey: "titleTextColor")
        }
    }
}

class PaddedTextField: UITextField {
    
    let padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 5)
    
    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
}

extension UIView {
    
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

    
    func getTimestamp(postTime: Firebase.Timestamp) -> String {
        let seconds = postTime.seconds
        let current = Date().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds
        
        if timeSincePost < 604800 {
            // return time since post
            
            if (timeSincePost <= 86400) {
                if (timeSincePost <= 3600) {
                    if (timeSincePost <= 60) {
                        return "\(timeSincePost)s"
                    } else {
                        let minutes = timeSincePost / 60
                        return "\(minutes)m"
                    }
                } else {
                    let hours = timeSincePost / 3600
                    return "\(hours)h"
                }
            } else {
                let days = timeSincePost / 86400
                return "\(days)d"
            }
        }
        
        else {
            // return date
            let timeInterval = TimeInterval(integerLiteral: seconds)
            let date = Date(timeIntervalSince1970: timeInterval)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/dd/yy"
            let dateString = dateFormatter.string(from: date)
            return dateString
        }
    }
}

extension UILabel {
    
    func addTrailing(with trailingText: String, moreText: String, moreTextFont: UIFont, moreTextColor: UIColor) {
        
        let readMoreText: String = trailingText + moreText
        if self.visibleTextLength == 0 { return }
        
        let lengthForVisibleString: Int = self.visibleTextLength
        
        if let myText = self.text {
                                    
            let mutableString = NSString(string: myText) /// use mutable string for length for correct length calculations
            
            let trimmedString: String? = mutableString.replacingCharacters(in: NSRange(location: lengthForVisibleString, length: mutableString.length - lengthForVisibleString), with: "")
            let readMoreLength: Int = (readMoreText.count)
            let safeTrimmedString = NSString(string: trimmedString ?? "")
            if safeTrimmedString.length <= readMoreLength { return }
            
            // "safeTrimmedString.count - readMoreLength" should never be less then the readMoreLength because it'll be a negative value and will crash
            let trimmedForReadMore: String = (safeTrimmedString as NSString).replacingCharacters(in: NSRange(location: safeTrimmedString.length - readMoreLength, length: readMoreLength), with: "") + trailingText
                        
            let answerAttributed = NSMutableAttributedString(string: trimmedForReadMore, attributes: [NSAttributedString.Key.font: self.font as Any])
            let readMoreAttributed = NSMutableAttributedString(string: moreText, attributes: [NSAttributedString.Key.font: moreTextFont, NSAttributedString.Key.foregroundColor: moreTextColor])
            answerAttributed.append(readMoreAttributed)
            self.attributedText = answerAttributed
        }
    }
    
    var visibleTextLength: Int {
        
        let font: UIFont = self.font
        let mode: NSLineBreakMode = self.lineBreakMode
        let labelWidth: CGFloat = self.frame.size.width
        let labelHeight: CGFloat = self.frame.size.height
        let sizeConstraint = CGSize(width: labelWidth, height: CGFloat.greatestFiniteMagnitude)
        
        if let myText = self.text {
            
            let attributes: [AnyHashable: Any] = [NSAttributedString.Key.font: font]
            let attributedText = NSAttributedString(string: myText, attributes: attributes as? [NSAttributedString.Key : Any])
            let boundingRect: CGRect = attributedText.boundingRect(with: sizeConstraint, options: .usesLineFragmentOrigin, context: nil)
            
            if boundingRect.size.height > labelHeight {
                var index: Int = 0
                var prev: Int = 0
                let characterSet = CharacterSet.whitespacesAndNewlines
                repeat {
                    prev = index
                    if mode == NSLineBreakMode.byCharWrapping {
                        index += 1
                    } else {
                        index = (myText as NSString).rangeOfCharacter(from: characterSet, options: [], range: NSRange(location: index + 1, length: myText.count - index - 1)).location
                    }
                } while index != NSNotFound && index < myText.count && (myText as NSString).substring(to: index).boundingRect(with: sizeConstraint, options: .usesLineFragmentOrigin, attributes: attributes as? [NSAttributedString.Key : Any], context: nil).size.height <= labelHeight
                return prev
            }
        }
        
        if self.text == nil {
            return 0
        } else {
            return self.text!.count
        }
    }
    
    var maxNumberOfLines: Int {
        let maxSize = CGSize(width: frame.size.width, height: CGFloat(MAXFLOAT))
        let text = (self.text ?? "") as NSString
        let textHeight = text.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, attributes: [.font: font as Any], context: nil).height
        let lineHeight = font.lineHeight
        return Int(ceil(textHeight / lineHeight))
    }
    
    
    func toTimeString(timestamp: Firebase.Timestamp) {
        let seconds = timestamp.seconds
        let current = NSDate().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds
        
        if (timeSincePost <= 86400) {
            if (timeSincePost <= 3600) {
                if (timeSincePost <= 60) {
                    text = "\(timeSincePost)s"
                } else {
                    let minutes = timeSincePost / 60
                    text = "\(minutes)m"
                }
            } else {
                let hours = timeSincePost / 3600
                text = "\(hours)h"
            }
        } else {
            let days = timeSincePost / 86400
            text = "\(days)d"
        }
    }
}
///https://stackoverflow.com/questions/32309247/add-read-more-to-the-end-of-uilabel

extension MKPointOfInterestCategory {
    
    func toString() -> String {
        
        /// convert POI type into readable string
        var text = rawValue
        var counter = 13
        while counter > 0 { text = String(text.dropFirst()); counter -= 1 }
        
        /// insert space in POI type if necessary
        counter = 0
        var uppercaseIndex = 0
        for letter in text {if letter.isUppercase && counter != 0 { uppercaseIndex = counter }; counter += 1}
        if uppercaseIndex != 0 { text.insert(" ", at: text.index(text.startIndex, offsetBy: uppercaseIndex)) }

        return text
    }
}

public extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter{ seen.insert($0).inserted }
    }
}
/// https://stackoverflow.com/questions/25738817/removing-duplicate-elements-from-an-array-in-swift
