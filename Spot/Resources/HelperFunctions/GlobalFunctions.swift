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
import MapboxMaps

extension UIViewController {
    //reverse geocode should a string based on lat/long input and amount of detail that it wants to return
    func reverseGeocodeFromCoordinate(numberOfFields: Int, location: CLLocation, completion: @escaping (_ address: String) -> Void) {
        var addressString = ""
        
        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) {  placemarks, error in // 6
            
            guard let placemark = placemarks?.first else {
                print("placemark broke")
                return
            }
            
            if numberOfFields > 3 {
                if placemark.subThoroughfare != nil {
                    addressString = addressString + placemark.subThoroughfare! + " "
                }
            }
            
            if numberOfFields > 2 {
                if placemark.thoroughfare != nil {
                    addressString = addressString + placemark.thoroughfare!
                }
            }
            
            if numberOfFields > 1 && placemark.locality != nil {
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
    
    func getTopMostViewController() -> UIViewController? {
        let currentWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        
        var topMostViewController = currentWindow?.rootViewController
        
        while let presentedViewController = topMostViewController?.presentedViewController {
            topMostViewController = presentedViewController
        }
        
        return topMostViewController
    }
    
    func getCommentHeight(comment: String) -> CGFloat {
        let temp = UILabel(frame: CGRect(x: 54, y: 0, width: UIScreen.main.bounds.width - 68, height: 18))
        temp.text = comment
        temp.font = UIFont(name: "SFCompactText-Regular", size: 13.5)
        temp.numberOfLines = 0
        temp.lineBreakMode = .byWordWrapping
        temp.sizeToFit()
        let commentHeight: CGFloat = temp.bounds.height < 16 ? 16 : temp.bounds.height
        return commentHeight
    }
    
    func addRemoveTagTable(text: String, cursorPosition: Int, tableParent: MapViewController.TagTableParent) {
    
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
                        
                        if let currentVC = self as? PostViewController {
                            currentVC.mapVC.addTable(text: String(currentWord), parent: tableParent)
                        } else if let currentVC = self as? UploadPostController {
                            currentVC.mapVC.addTable(text: String(currentWord), parent: tableParent)
                        }
                        return
                    } else { i += 1; continue }
                }
            }
        }
        
        if let currentVC = self as? PostViewController {
            currentVC.mapVC.removeTable()
        } else if let currentVC = self as? UploadPostController {
            currentVC.mapVC.removeTable()
        }
    }
    
    // run when user taps a username to tag
    func addTaggedUserTo(text: String, username: String, cursorPosition: Int) -> String {
        
        var tagText = text
        
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
        guard let atIndex = String(suffix).indices(of: "@").first else { return "" }
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

        return tagText
    }

    /// get map rank used for clustering on map -> solely a popularity ranking
    func getMapRank(spot: MapSpot) -> CGFloat {
        
        var score: Float = 0
        for visitor in spot.visitorList {
            score = score + 1
            if isFriends(id: visitor) {
                score = score + 1
            }
        }
        
        if spot.postIDs.count == 0 { return(CGFloat(score)) }
        for i in 0 ... spot.postIDs.count - 1 {
            
            var postScore: Float = 2
            
            /// increment for each friend post
            if spot.posterIDs.count <= i { return CGFloat(score) }
            if isFriends(id: spot.posterIDs[i]) { postScore = postScore + 2 }

            let timestamp = spot.postTimestamps[i]
            let postTime = Float(timestamp.seconds)
            
            let current = NSDate().timeIntervalSince1970
            let currentTime = Float(current)
            let timeSincePost = currentTime - postTime
            
            /// add multiplier for recent posts
            var factor = min(1 + (1000000 / timeSincePost), 5)
            let multiplier = pow(1.5, factor)
            factor = multiplier
            
            postScore = postScore * factor
            score = score + postScore
        }
        
        return CGFloat(score)
    }
    
    
    func isFriends(id: String) -> Bool {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if id == uid || (UserDataModel.shared.friendIDs.contains(where: {$0 == id}) && !(UserDataModel.shared.adminIDs.contains(id))) { return true }
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
            if !UserDataModel.shared.friendIDs.contains(where: {$0 == creatorID}){
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
    
    func hasSpotAccess(spot: MapSpot) -> Bool {
                
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

        if UserDataModel.shared.adminIDs.contains(where: {$0 == spot.founderID}) {
            if uid != spot.founderID {
                return false
            }
        }
        
        if spot.privacyLevel == "friends" {
            if UserDataModel.shared.friendIDs.contains(where: {$0 == spot.founderID}) || uid == spot.founderID {
                return true
            }
            
        } else if spot.privacyLevel == "invite" {
            if spot.inviteList!.contains(where: {$0 == uid}) {
                return true
            }
            
        } else {
            for posterID in spot.posterIDs {
                if UserDataModel.shared.friendIDs.contains(posterID) || UserDataModel.shared.uid == posterID { return true }
            }
            for postPrivacy in spot.postPrivacies {
                if postPrivacy == "public" { return true }
            }
        }
        
        return false
    }
        
    func hasPostAccess(post: MapPost) -> Bool {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if uid == post.posterID { return true }
        if UserDataModel.shared.adminIDs.contains(where: {$0 == post.posterID}) { return false }
        
        if post.privacyLevel == "friends" {
            if !UserDataModel.shared.friendIDs.contains(post.posterID) { return false }
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
    
    func setSecondaryPostValues(post: MapPost) -> MapPost {
        
        var newPost = post
        newPost.seconds = newPost.timestamp.seconds
        
        let window = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        let statusHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 40.0
        let navBarHeight = statusHeight +
                    (self.navigationController?.navigationBar.frame.height ?? 44.0)
        let smallScreen = UserDataModel.shared.screenSize == 0

        let superMax: CGFloat = 1.3
        let maxAspect =  min((newPost.aspectRatios?.max() ?? 0.033) - 0.033, superMax)
        let imageHeight = UIScreen.main.bounds.width * maxAspect
        let noImage = imageHeight == 0

        newPost.imageHeight = UIScreen.main.bounds.width * maxAspect
        /// 55/90 = bottom spacing for button bar, 55.5 on big screens = topview indent above image
        let fixedAreas: CGFloat = smallScreen || noImage ? navBarHeight + 55 : navBarHeight + 55.5 + 90
        let textHeight: CGFloat = UIScreen.main.bounds.height - fixedAreas - imageHeight
        
        var maxCaption = textHeight - 22 /// subtract timestamp height and spacing
        /// min 2 comments showing for small screen, 1 comment for large screen
        let minComments = smallScreen ? 1 : 2
        maxCaption -=  CGFloat(min(max(0, post.commentList.count - 1), minComments) * 20)
        
        /// round to nearest line height
        let captionMultiplier: CGFloat = noImage ? 29 : 18
        maxCaption = (captionMultiplier * (maxCaption / captionMultiplier)).rounded(.down)
        newPost.captionHeight = self.getCaptionHeight(caption: newPost.caption, noImage: noImage, maxCaption: maxCaption, truncated: true)
        
        let commentsHeight = textHeight - newPost.captionHeight
        newPost.commentList = getFeedCommentsHeight(height: commentsHeight, commentsList: newPost.commentList)
        for comment in newPost.commentList { newPost.commentsHeight += comment.feedHeight }
        
        newPost.cellHeight = imageHeight + textHeight + fixedAreas
        return newPost
    }
    
    func getCaptionHeight(caption: String, noImage: Bool, maxCaption: CGFloat, truncated: Bool) -> CGFloat {
                
        let fontSize: CGFloat = noImage ? 24 : 14.2
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 16, height: 20))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCompactText-Regular", size: fontSize)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        
        return truncated ? min(maxCaption, tempLabel.frame.height.rounded(.up)) : tempLabel.frame.height
    }
    
    func getFeedCommentsHeight(height: CGFloat, commentsList: [MapComment]) -> ([MapComment]) {
        
        if commentsList.count < 1 { return commentsList }

        var spaceRemaining = height
        var newComments = commentsList

        for i in 0...commentsList.count - 1 {
            let height = getFeedCommentHeight(comment: commentsList[i])
            /// save room for the second comment  if i==0
            if (i == 0 && height <= spaceRemaining - 20) || (i != 0 && height <= spaceRemaining) {
                newComments[i].feedHeight = height
                spaceRemaining -= height
            } else {
                newComments[i].feedHeight = 20
            }
        }

        return newComments
    }
    
    func getFeedCommentHeight(comment: MapComment) -> CGFloat {
        
        let username = UIButton(frame: CGRect(x: 8, y: 1, width: 150, height: 18))
        username.setTitle(comment.userInfo?.username ?? "", for: .normal)
        username.titleLabel?.font = UIFont(name: "SFCompactText-Semibold", size: 13.25)
        username.sizeToFit()
        username.frame = CGRect(x: 3, y: 1, width: username.frame.width + 10, height: 18)
        
        let commentLabel = UILabel(frame: CGRect(x: username.frame.maxX, y: 2.5, width: UIScreen.main.bounds.width - username.frame.maxX - 8, height: UIScreen.main.bounds.height))
        commentLabel.text = comment.comment
        commentLabel.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        commentLabel.lineBreakMode = .byWordWrapping
        commentLabel.numberOfLines = 0
        commentLabel.sizeToFit()
        
        return commentLabel.frame.height + 5
    }
    
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
    
    func getDateTimestamp(seconds: Int64) -> String {

        let timeInterval = TimeInterval(integerLiteral: seconds)
        let date = Date(timeIntervalSince1970: timeInterval)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
    
    func locationIsEmpty(location: CLLocation) -> Bool {
        return location.coordinate.longitude == 0.0 && location.coordinate.latitude == 0.0
    }
}

/// upload post functions
extension UIViewController {
    
    func uploadPost(post: MapPost) {
        
        let interval = Date().timeIntervalSince1970
        let postTimestamp = Date(timeIntervalSince1970: TimeInterval(interval))
        
        let postValues = ["caption" : post.caption,
                          "posterID": post.posterID,
                          "likers": [],
                          "actualTimestamp": post.actualTimestamp as Any,
                          "timestamp": postTimestamp,
                          "taggedUsers": post.taggedUsers!,
                          "taggedUserIDs": post.taggedUserIDs,
                          "isFirst": post.isFirst!,
                          "postLat": post.postLat,
                          "postLong": post.postLong,
                          "privacyLevel": post.privacyLevel!,
                          "imageURLs" : post.imageURLs,
                          "frameIndexes" : post.frameIndexes!,
                          "aspectRatios" : post.aspectRatios!,
                          "createdBy": post.createdBy!,
                          "city" : post.city!,
                          "inviteList" : post.inviteList!,
                          "friendsList" : post.friendsList,
                          "spotName" : post.spotName!,
                          "spotNames" : [post.spotName!],
                          "spotID" : post.spotID!,
                          "spotIDs" : [post.spotID!],
                          "spotIndexes" : [0], /// preloading DB for multiple sp0t upload
                          "spotLat": post.spotLat!,
                          "spotLong": post.spotLong!,
                          "spotPrivacy" : post.spotPrivacy!,
                          "hideFromFeed": post.hideFromFeed!,
                          "addedUsers" : post.addedUsers!,
                          "tag" : post.tag!,
                          "tags" : [post.tag!], /// prepare for switch to multiple tags
                          "posterUsername" : UserDataModel.shared.userInfo.username,
                          "imageLocations" : post.imageLocations!
        ] as [String : Any]

        let commentValues = ["addedUsers" : post.addedUsers ?? [],
                             "comment" : post.caption,
                             "commenterID" : post.posterID,
                             "commenterIDList": [],
                             "commenterUsername" : UserDataModel.shared.userInfo.username,
                             "imageURL": post.imageURLs.first ?? "",
                             "likers" : [],
                             "posterID": post.posterID,
                             "posterUsername": UserDataModel.shared.userInfo.username,
                             "timestamp" : postTimestamp,
                             "taggedUsers": post.taggedUsers!,
                             "taggedUserIDs" : []] as [String : Any]
        let commentID = UUID().uuidString
        
        var notiPost = post
        let commentObject = MapComment(id: commentID, comment: post.caption, commenterID: post.posterID, timestamp: Timestamp(date: postTimestamp as Date), userInfo: UserDataModel.shared.userInfo, taggedUsers: post.taggedUsers, commentHeight: self.getCommentHeight(comment: post.caption), seconds: Int64(interval))
        notiPost.commentList = [commentObject]
        
        
        NotificationCenter.default.post(Notification(name: Notification.Name("NewPost"), object: nil, userInfo: ["post" : notiPost as Any]))
        
        let db = Firestore.firestore()
        db.collection("posts").document(post.id!).setData(postValues)
        db.collection("posts").document(post.id!).collection("comments").document(commentID).setData(commentValues, merge:true)
        
        setPostLocations(postLocation: CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong), postID: post.id!)
    }
    
    func uploadPostImage(_ images: [UIImage], postID: String, progressFill: UIView, completion: @escaping ((_ urls: [String], _ failed: Bool) -> ())){
        
        var failed = false
        
        let fullWidth: CGFloat = UIScreen.main.bounds.width - 100
        if images.isEmpty { completion([], false); return } /// complete immediately for no  image post
        
        var URLs: [String] = []
        for _ in images {
            URLs.append("")
        }

        var index = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            /// no downloaded URLs means that this post isnt even close to uploading so trigger failed upload earlier to avoid making the user wait
            if progressFill.bounds.width != fullWidth && !URLs.contains(where: {$0 != ""}) && !failed {
                print("run failed 1")
                failed = true
                completion([], true)
                return
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            /// run failed upload on second try if it wasnt already run
            if progressFill.bounds.width != fullWidth && !failed {
                print("run failed 2")
                failed = true
                completion([], true)
                return
            }
        }
        
        var progress = 0.7/Double(images.count)

        
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
                    
                    DispatchQueue.main.async {
                        let frameWidth: CGFloat = min(((0.3 + progress) * UIScreen.main.bounds.width - 100), UIScreen.main.bounds.width - 101)
                        UIView.animate(withDuration: 0.2) {
                            progressFill.frame = CGRect(x: progressFill.frame.minX, y: progressFill.frame.minY, width: frameWidth, height: progressFill.frame.height)
                        }
                    }
                    
                    progress = progress * Double(index + 1)
                    
                    index += 1
                    
                    if failed { return } /// dont want to return anything after failed upload runs

                    if index == images.count {
                        DispatchQueue.main.async {
                            completion(URLs, false)
                            return
                        }
                    }
                }
            }
        }
    }
    
    func uploadSpot(post: MapPost, spot: MapSpot, postType: UploadPostController.PostType, submitPublic: Bool) {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
        let db: Firestore = Firestore.firestore()
        
        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))

        switch postType {
        case .newSpot, .postToPOI:
            
            let lowercaseName = spot.spotName.lowercased()
            let keywords = lowercaseName.getKeywordArray()
            
            var tagDictionary: [String: Any] = [:]
            if post.tag ?? "" != "" {
                tagDictionary.updateValue(1, forKey: post.tag!)
            }
            
            var spotVisitors = [uid]
            spotVisitors.append(contentsOf: post.addedUsers ?? [])
            
            var posterDictionary: [String: Any] = [:]
            posterDictionary[post.id!] = spotVisitors
            
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
                        
            /// visitorList empty here since new spot
            setUserValues(poster: uid, post: post, spotID: spot.id!, visitorList: [])
                        
            if submitPublic { db.collection("submissions").document(spot.id!).setData(["spotID" : spot.id!])}
            self.setSpotLocations(spotLocation: CLLocationCoordinate2D(latitude: spot.spotLat, longitude: spot.spotLong), spotID: spot.id!)
            
            var notiSpot = spot
            notiSpot.checkInTime = Int64(interval)
            NotificationCenter.default.post(name: NSNotification.Name("NewSpot"), object: nil, userInfo: ["spot" : notiSpot])
            
            /// add city to list of cities if this is the first post there
            self.addToCityList(city: post.city ?? "")
            
            /// increment users spot score by 6
        default:
            
            setUserValues(poster: uid, post: post, spotID: spot.id!, visitorList: spot.visitorList)
            
            /// run spot transactions
            var posters = post.addedUsers ?? []
            posters.append(uid)

            let functions = Functions.functions()
            functions.httpsCallable("runSpotTransactions").call(["spotID": spot.id!, "postID": post.id!, "uid": uid, "postPrivacy": post.privacyLevel!, "postTag": post.tag ?? "", "posters": posters]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    func setUserValues(poster: String, post: MapPost, spotID: String, visitorList: [String]) {
        
        let tag = post.tag ?? ""
        let addedUsers = post.addedUsers ?? []
        
        var posters = [poster]
        posters.append(contentsOf: addedUsers)
        
        let db: Firestore = Firestore.firestore()
        
        // adjust user values for added users
        for poster in posters {
            
            if visitorList.contains(where: {$0 == poster}) {
                db.collection("users").document(poster).collection("spotsList").document(spotID).updateData(["postsList" : FieldValue.arrayUnion([post.id!])])
            } else {
                db.collection("users").document(poster).collection("spotsList").document(spotID).setData(["spotID" : spotID, "checkInTime" : post.timestamp, "postsList" : [post.id!], "city": post.city!], merge:true)
            }

            /// increment addedUsers spotScore by 1
            var userValues = ["spotScore" : FieldValue.increment(Int64(3))]
            if tag != "" { userValues["tagDictionary.\(tag)"] = FieldValue.increment(Int64(1)) }
            
            /// remove this user for topFriends increments
            var dictionaryFriends = posters
            dictionaryFriends.removeAll(where: {$0 == poster})
            for user in dictionaryFriends { userValues["topFriends.\(user)"] = FieldValue.increment(Int64(1)) } /// increment top friends if added friends
            
            db.collection("users").document(poster).updateData(userValues)
        }
    }
}

extension MapView {
    func spotInBounds(spotCoordinates: CLLocationCoordinate2D) -> Bool {
        let boundingBox = mapboxMap.coordinateBounds(for: bounds)
        return boundingBox.containsLatitude(forLatitude: spotCoordinates.latitude) && boundingBox.containsLongitude(forLongitude: spotCoordinates.longitude)
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

extension UITableViewCell {
    
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
    
    func acceptFriendRequest(friendID: String) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let functions = Functions.functions()
        functions.httpsCallable("acceptFriendRequest").call(["userID": uid, "friendID": friendID, "username": UserDataModel.shared.userInfo.username]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
            
    func removeFriendRequest(friendID: String, uid: String) {
        let functions = Functions.functions()
        functions.httpsCallable("acceptFriendRequest").call(["uid": uid, "friendID": friendID]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
        
    func getAttString(caption: String, taggedFriends: [String], fontSize: CGFloat) -> ((NSMutableAttributedString, [(rect: CGRect, username: String)])) {
        
        let attString = NSMutableAttributedString(string: caption)
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
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCompactText-Semibold", size: fontSize) as Any, range: range)
                }
            }
        }
        
        for tag in tags {
            var rect = (rect: getRect(str: attString, range: tag.range, maxWidth: UIScreen.main.bounds.width - 72), username: tag.username)
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
        textContainer.lineFragmentPadding = 5
        let pointer = UnsafeMutablePointer<NSRange>.allocate(capacity: 1)
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: pointer)
        return layoutManager.boundingRect(forGlyphRange: pointer.move(), in: textContainer)
    }
    
    func getDateTimestamp(postTime: Firebase.Timestamp) -> String {

        let timeInterval = TimeInterval(integerLiteral: postTime.seconds)
        let date = Date(timeIntervalSince1970: timeInterval)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        return dateString
    }

    func reverseGeocodeFromCoordinate(numberOfFields: Int, location: CLLocation, completion: @escaping (_ address: String) -> Void) {
        var addressString = ""
        
        let locale = Locale(identifier: "en")
        CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale) { [weak self] placemarks, error in // 6
            
            if self == nil { completion(""); return }
            
            guard let placemark = placemarks?.first else {
                print("placemark broke")
                return
            }
            
            if numberOfFields > 3 {
                if placemark.subThoroughfare != nil {
                    addressString = addressString + placemark.subThoroughfare! + " "
                }
            }
            if numberOfFields > 2 {
                if placemark.thoroughfare != nil {
                    addressString = addressString + placemark.thoroughfare!
                }
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
    
    func sendAcceptPublicNotification(spot: MapSpot) {
        
        let db: Firestore! = Firestore.firestore()

        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        let notiID = UUID().uuidString
        let notificationRef = db.collection("users").document(spot.founderID).collection("notifications")
        let acceptRef = notificationRef.document(notiID)
        
        acceptRef.setData(["seen" : false, "timestamp" : time, "senderID": "T4KMLe3XlQaPBJvtZVArqXQvaNT2", "type": "publicSpotAccepted", "spotID": spot.id!, "postID": spot.postIDs.first!, "imageURL": spot.imageURL] as [String: Any])
        db.collection("submissions").document(spot.id!).delete()
        db.collection("spots").document(spot.id!).updateData(["privacyLevel" : "public"])
        
        let functions = Functions.functions()
        functions.httpsCallable("acceptPublicSpot").call(["spotID": spot.id!, "postPrivacies": spot.postPrivacies, "posterIDs": spot.posterIDs, "postIDs": spot.postIDs, "createdBy": spot.founderID]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }
    
    func adjustPostPrivacies(postIDs: [String], adjustedIDs: [String]) {
        
        let db: Firestore! = Firestore.firestore()

        for id in postIDs {
            /// update spot privacy for all posts, post privacy for founder posts
            db.collection("posts").document(id).updateData(["spotPrivacy" : "public"])
            if adjustedIDs.contains(id) {             db.collection("posts").document(id).updateData(["privacyLevel" : "public"]) }
        }
    }
    
    func sendRejectPublicNotification(spot: MapSpot) {

        let db: Firestore! = Firestore.firestore()

        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        let notiID = UUID().uuidString
        let notificationRef = db.collection("users").document(spot.founderID).collection("notifications")
        let acceptRef = notificationRef.document(notiID)
        
        acceptRef.setData(["seen" : false, "timestamp" : time, "senderID": "T4KMLe3XlQaPBJvtZVArqXQvaNT2", "type": "publicSpotRejected", "spotID": spot.id!, "postID": spot.postIDs.first!, "imageURL": spot.imageURL] as [String: Any])
        db.collection("submissions").document(spot.id!).delete()
    }
}

extension String {
/*    func indices(of string: String) -> [Int] {
        return indices.reduce([]) { $1.utf16Offset(in: self) > ($0.last ?? -1) && self[$1...].hasPrefix(string) ? $0 + [$1.utf16Offset(in: self)] : $0 }
    }
    */
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
    
    func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] {
        var ranges: [Range<Index>] = []
        while let range = range(of: substring, options: options, range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale) {
            ranges.append(range)
        }
        return ranges
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
    
    func animateGIF(directionUp: Bool, counter: Int, alive: Bool) {
        
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { return }
        
        var newDirection = directionUp
        var newCount = counter
        
        if let postImage = self as? PostImageView { postImage.animationIndex = newCount }
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

        let duration: TimeInterval = alive ? 0.06 : 0.049
        
        UIView.transition(with: self, duration: duration, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
                            guard let self = self else { return }
                            if self.animationImages?.isEmpty ?? true { return }
                            if counter >= self.animationImages?.count ?? 0 { return }
                            self.image = self.animationImages![counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.005) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount, alive: alive)
        }
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
    
    func addBottomMask() {
        let bottomMask = UIView(frame: CGRect(x: 0, y: bounds.height - 140, width: UIScreen.main.bounds.width, height: 140))
        bottomMask.backgroundColor = nil
        let layer0 = CAGradientLayer()
        layer0.frame = bottomMask.bounds
        layer0.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.01).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.06).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.23).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.85).cgColor
        ]
        layer0.locations = [0, 0.11, 0.24, 0.43, 0.65, 1]
        layer0.startPoint = CGPoint(x: 0.5, y: 0)
        layer0.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomMask.layer.addSublayer(layer0)
        addSubview(bottomMask)
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
            appearance.backgroundImage = UIImage(color: UIColor.black)
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        } else {
            setBackgroundImage(UIImage(color: UIColor.black), for: .default)
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
    
    ///https://gist.github.com/AJMiller/0def0fd492a09ca22fee095c4526cf68
    func roundedView() {
        let maskPath1 = UIBezierPath(roundedRect: bounds,
            byRoundingCorners: [.topLeft , .topRight],
            cornerRadii: CGSize(width: 8, height: 8))
        let maskLayer1 = CAShapeLayer()
        maskLayer1.frame = bounds
        maskLayer1.path = maskPath1.cgPath
        layer.mask = maskLayer1
    }

    
    func getTimestamp(postTime: Firebase.Timestamp) -> String {
        let seconds = postTime.seconds
        let current = NSDate().timeIntervalSince1970
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
        } else {
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
