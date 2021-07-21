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
        temp.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        temp.numberOfLines = 0
        temp.lineBreakMode = .byWordWrapping
        temp.sizeToFit()
        let commentHeight: CGFloat = temp.bounds.height < 15 ? 15 : temp.bounds.height
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

    
    func hasPOILevelAccess(creatorID: String, privacyLevel: String, inviteList: [String], mapVC: MapViewController) -> Bool {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
        if mapVC.adminIDs.contains(where: {$0 == creatorID}) {
            if uid != creatorID {
                return false
            }
        }
        
        if privacyLevel == "friends" {
            if !mapVC.friendIDs.contains(where: {$0 == creatorID}){
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
    
    func hasSpotAccess(spot: MapSpot, mapVC: MapViewController) -> Bool {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        
        if mapVC.adminIDs.contains(where: {$0 == spot.founderID}) {
            if uid != spot.founderID {
                return false
            }
        }
        
        if spot.privacyLevel == "friends" {
            if mapVC.friendIDs.contains(where: {$0 == spot.founderID}) || uid == spot.founderID {
                return true
            }
            
        } else if spot.privacyLevel == "invite" {
            if spot.inviteList!.contains(where: {$0 == uid}) {
                return true
            }
            
        } else {
            for posterID in spot.posterIDs {
                if mapVC.friendIDs.contains(posterID) || mapVC.uid == posterID { return true }
            }
            for postPrivacy in spot.postPrivacies {
                if postPrivacy == "public" { return true }
            }
        }
        
        return false
    }
    
    func hasPostAccess(post: MapPost, mapVC: MapViewController) -> Bool {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        if uid == post.posterID { return true }
        if mapVC.adminIDs.contains(where: {$0 == post.posterID}) { return false }
        
        if post.privacyLevel == "friends" {
            if !mapVC.friendIDs.contains(post.posterID) { return false }
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

    
    func incrementSpotScore(user: String, increment: Int) {
        
        let db: Firestore = Firestore.firestore()
        // increments
        /// 1 for like / comment
        /// 3 for creating spot
        /// 3 for post
        let ref = db.collection("users").document(user)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var spotScore: Int = 0
            
            spotScore = myDoc.data()?["spotScore"] as? Int ?? 0
            spotScore += increment
            let finalScore = max(spotScore, 0) // never set sp0tsc0re < 0
            
            transaction.updateData([
                "spotScore": finalScore
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }
    }
    
    func checkUserSpotsOnPostDelete(spotID: String, deletedID: String) {
        
        if spotID == "" { return }
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore = Firestore.firestore()
        
        var deleteUser = true
        db.collection("spots").document(spotID).getDocument { (snap, err) in
            
            do {
                let spot = try snap?.data(as: MapSpot.self)
                guard let spotInfo = spot else { return }
                
                if spotInfo.postIDs.count == 0 { return }
                for i in 0 ... spotInfo.postIDs.count - 1 {
                    if spotInfo.postIDs[i] != deletedID && spotInfo.posterIDs[i] == uid {
                        deleteUser = false
                    }
                    
                    if i == spotInfo.postIDs.count - 1 {
                        /// if we didn't find a post with current users uid, remove from that users spot list, remove that user from the visitor list
                        if deleteUser {
                            db.collection("users").document(uid).collection("spotsList").document(spotID).delete()
                            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name("UserListRemove"), object: nil, userInfo: ["spotID" : spotID]) }
                            db.collection("spots").document(spotID).updateData(["visitorList" : FieldValue.arrayRemove([uid])])
                        } else {
                            /// else remove the post from postslist in spotsList
                            db.collection("users").document(uid).collection("spotsList").document(spotID).updateData(["postsList" : FieldValue.arrayRemove([deletedID])])
                        }
                    }
                }
            } catch { return }
        }
    }
    
    /// on spot delete (could be multiple posts / visitors)
    func userDelete(spot: MapSpot) {
        
        let db: Firestore = Firestore.firestore()

        for visitor in spot.visitorList {
            db.collection("users").document(visitor).collection("spotsList").document(spot.id!).delete()
        }
        
        for invite in spot.inviteList ?? [] {
            if !spot.visitorList.contains(invite) {            db.collection("users").document(invite).collection("spotsList").document(spot.id!).delete()
            }
        }
    }
    
    /// on post delete (1 post / 1 user)
    func userDelete(spotID: String) {
        let db: Firestore = Firestore.firestore()
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        db.collection("users").document(uid).collection("spotsList").document(spotID).delete()
    }
    
    func spotNotificationDelete(spot: MapSpot) {
        //delete any spot level notifications
        
        let db: Firestore = Firestore.firestore()

        for visitor in spot.visitorList {
            let postNotiRef = db.collection("users").document(visitor).collection("notifications")
            let query = postNotiRef.whereField("spotID", isEqualTo: spot.id!)
            query.getDocuments { (querysnapshot, err) in
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                }
            }
        }
        
        for invite in spot.inviteList ?? [] {
            let postNotiRef = db.collection("users").document(invite).collection("notifications")
            let query = postNotiRef.whereField("spotID", isEqualTo: spot.id!)
            query.getDocuments { (querysnapshot, err) in
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                }
            }
        }
    }
    
    func spotDelete(spotID: String) {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore = Firestore.firestore()
        
        self.incrementSpotScore(user: uid, increment: -6)
        db.collection("spots").document(spotID).delete()
        
        /// user delete for each user on spot page
    }
    
    func postNotificationDelete(createdBy: String, posterID: String, postID: String) {
        
        let db: Firestore = Firestore.firestore()

        let postNotiRef = db.collection("users").document(posterID).collection("notifications")
        let query = postNotiRef.whereField("postID", isEqualTo: postID)
        
        query.getDocuments {(querysnapshot, err) in

            for doc in querysnapshot!.documents {
                doc.reference.delete()
            }
        }
        
        if createdBy != "" {
            
            let spotNotiRef = db.collection("users").document(createdBy).collection("notifications")
            let spotQuery = spotNotiRef.whereField("postID", isEqualTo: postID)
            spotQuery.getDocuments {(querysnapshot, err) in
                
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                }
            }
        }
    }
    
    func postDelete(postsList: [MapPost], spotID: String) {
        ///delete all spot posts / post objects and comments
        /// spotID != "" when spot isn't being deleted
        
        let db: Firestore = Firestore.firestore()
        for post in postsList {
            
            let postRef = db.collection("posts").document(post.id!)
            postRef.collection("comments").getDocuments { (querysnapshot, err) in

                if querysnapshot?.documents.count == 0 || err != nil { postRef.delete() }
                
                for doc in querysnapshot!.documents {
                    postRef.collection("comments").document(doc.documentID).delete()
                    
                    if doc == querysnapshot?.documents.last {
                        self.postNotificationDelete(createdBy: post.createdBy ?? "", posterID: post.posterID, postID: post.id! )
                        
                        /// spotID != "" when the spot is not being deleted -> need to run transaction
                        if spotID != "" {
                                                        
                            /// can be identical values for posterIDs + postPrivacies so need to run transactions
                            let db: Firestore! = Firestore.firestore()
                            let ref = db.collection("spots").document(spotID)
                            
                            db.runTransaction({ (transaction, errorPointer) -> Any? in
                                
                                let myDoc: DocumentSnapshot
                                do {
                                    try myDoc = transaction.getDocument(ref)
                                } catch let fetchError as NSError {
                                    errorPointer?.pointee = fetchError
                                    return nil
                                }
                                
                                var postIDs: [String] = []
                                var postTimestamps: [Firebase.Timestamp] = []
                                var posterIDs: [String] = []
                                var postPrivacies: [String] = []
                                
                                postIDs = myDoc.data()?["postIDs"] as? [String] ?? []
                                let arrayIndex = postIDs.firstIndex(where: {$0 == post.id!}) ?? 0

                                postTimestamps = myDoc.data()?["postTimestamps"] as? [Firebase.Timestamp] ?? []
                                posterIDs = myDoc.data()?["posterIDs"] as? [String] ?? []
                                postPrivacies = myDoc.data()?["postPrivacies"] as? [String] ?? []
                                
                                if postIDs.count > arrayIndex { postIDs.remove(at: arrayIndex) }
                                
                                if postTimestamps.count > arrayIndex { postTimestamps.remove(at: arrayIndex) }
                                
                                if posterIDs.count > arrayIndex { posterIDs.remove(at: arrayIndex) }
                                
                                if postPrivacies.count > arrayIndex {
                                    postPrivacies.remove(at: arrayIndex)
                                }
                                
                                    transaction.updateData([
                                        "postIDs": postIDs,
                                        "postTimestamps": postTimestamps,
                                        "posterIDs" : posterIDs,
                                        "postPrivacies" : postPrivacies
                                    ], forDocument: ref)
                                
                                return nil
                                
                            }) { (object, error) in
                                if error != nil {
                                    postRef.delete()
                                } else {
                                    postRef.delete()
                                }
                            }
                        } else { postRef.delete() }
                    }
                }
            }
        }
    }
    
    func removeFriendFromPosts(posterID: String, friendID: String, completion: @escaping (_ complete: Bool) -> Void) {
        
        let db = Firestore.firestore()
        
        db.collection("posts").whereField("posterID", isEqualTo: posterID).order(by: "timestamp", descending: true).getDocuments { (snap, err) in
            if err == nil {
                
                var index = 0
                if snap!.documents.count == 0 { completion(true); return }
                
                for doc in snap!.documents {
                    if let _ = doc.get("friendsList") as? [String] {
                        doc.reference.updateData(["friendsList" : FieldValue.arrayRemove([friendID])])
                        print("remove from friends", doc.documentID, posterID)
                        
                        if let _ = doc.get("inviteList") as? [String] {
                            doc.reference.updateData(["inviteList" : FieldValue.arrayRemove([friendID])])
                            index += 1; if index == snap!.documents.count { completion(true); return }
                            
                        } else {
                            index += 1; if index == snap!.documents.count { completion(true); return }
                        }
                            
                    } else { index += 1; if index == snap!.documents.count { completion(true); return }}
                }
            } else { completion(true); return }
        }
    }
    
    func removeFriendFromNotis(posterID: String, friendID: String, completion: @escaping (_ complete: Bool) -> Void) {
        
        let db = Firestore.firestore()
        
        let postNotiRef = db.collection("users").document(posterID).collection("notifications")
        let query = postNotiRef.whereField("senderID", isEqualTo: friendID)
        query.getDocuments { (querysnapshot, err) in
            if err != nil || querysnapshot!.documents.count == 0 { completion(true); return }
            var index = 0

            for doc in querysnapshot!.documents {

                doc.reference.delete()
                index += 1
                if index == querysnapshot!.documents.count { completion(true); return }
            }
        }
    }
    
    func addFriend(friendID: String, frienderID: String) {
        
        let db: Firestore = Firestore.firestore()
        let ref = db.collection("users").document(friendID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var friendsList = myDoc.data()?["friendsList"] as? [String] else { return nil }
            friendsList.append(frienderID)
            
            transaction.updateData([
                "friendsList": friendsList
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }

    }
    
    func addFriends(friendIDs: [String], uid: String, yetToJoin: [String]) {
        
        let db: Firestore = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var friendsList = myDoc.data()?["friendsList"] as? [String] else { return nil }
            friendsList.append(contentsOf: friendIDs)
            
            transaction.updateData([
                "friendsList": friendsList,
                "signupGroup": yetToJoin
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }

    }
    
    
    func adjustPostsFriendsList(userID: String, friendID: String) {
        
        let db = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: userID).order(by: "timestamp", descending: true).getDocuments { (snap, err) in

            if err != nil { return }
            for doc in snap!.documents {
                
                /// dont give user access to posts that have been hidden from feed
                print("add user")
                let hideFromFeed = doc.get("hideFromFeed") as? Bool ?? false
                if hideFromFeed { continue }
                
                let privacyLevel = doc.get("privacyLevel") as? String ?? "friends"
                if privacyLevel != "invite" {
                    db.collection("posts").document(doc.documentID).updateData(["friendsList" : FieldValue.arrayUnion([friendID])])
                }
            }
        }
    }

    func addToCityList(city: String) {
        
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
    
    func sendInviteNotis(spotObject: MapSpot, postObject: MapPost, username: String) {
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db = Firestore.firestore()
        let interval = Date().timeIntervalSince1970
        let timestamp = Date(timeIntervalSince1970: TimeInterval(interval))
        
        for invite in spotObject.inviteList ?? [] {
            
            if invite == uid { continue }
            /// add to invited users spots list
            db.collection("users").document(invite).collection("spotsList").document(spotObject.id!).setData(["spotID" : spotObject.id!, "checkInTime" : timestamp, "postsList" : [], "city": spotObject.city ?? ""], merge: true)

            let notiID = UUID().uuidString
            
            let notificationRef = db.collection("users").document(invite).collection("notifications")
            let notiRef = notificationRef.document(notiID)
            
            let notiValues = ["seen" : false, "timestamp" : timestamp, "senderID": uid, "type": "invite", "spotID": spotObject.id!, "postID" : postObject.id!, "imageURL": spotObject.imageURL, "spotName": spotObject.spotName] as [String : Any]
            notiRef.setData(notiValues)
            
            let sender = PushNotificationSender()
            
            db.collection("users").document(postObject.posterID).getDocument { (tokenSnap, err) in
                guard let token = tokenSnap?.get("notificationToken") as? String else { return }
                sender.sendPushNotification(token: token, title: "", body: "\(username) added you to a private spot")
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
        let imageRect = CGRect(x: (size.width - width) / 2.0, y: (size.height - height) / 2.0 - 0.5, width: width, height: height)
        
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
        
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        let values = ["senderID" : uid,
                      "type" : "friendRequest",
                      "timestamp" : time,
                      "status" : "pending",
                      "seen" : false
        ] as [String : Any]
        ref.setData(values)
        
        db.collection("users").document(uid).updateData(["pendingFriendRequests" : FieldValue.arrayUnion([receiverID])])
        
        let sender = PushNotificationSender()
        
        db.collection("users").document(receiverID).getDocument { (tokenSnap, err) in
            if (tokenSnap != nil) {
                guard let token = tokenSnap?.get("notificationToken") as? String else { return }
                sender.sendPushNotification(token: token, title: "", body: "\(senderProfile.username) sent you a friend request")
            }
        }
    }
    
    func acceptFriendRequest(friendID: String, uid: String, username: String) {
        
        let db: Firestore! = Firestore.firestore()
        /// add friend to current users friendsList
        addFriendToFriendsList(uid: uid, friendID: friendID)
        adjustPostsFriendsList(userID: uid, friendID: friendID)
        /// add current user to new friends friendsListt
        addFriendToFriendsList(uid: friendID, friendID: uid)
        adjustPostsFriendsList(userID: friendID, friendID: uid)

        //remove notification
        let notificationRef = db.collection("users").document(uid).collection("notifications")
        let query = notificationRef.whereField("senderID", isEqualTo: friendID).whereField("type", isEqualTo: "friendRequest")
        query.getDocuments(completion: { (snap, err) in
            
            if err != nil { return }
            let timestamp = NSDate().timeIntervalSince1970
            let myTimeInterval = TimeInterval(timestamp)
            let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
            for document in snap!.documents {
                db.collection("users").document(uid).collection("notifications").document(document.documentID).updateData(["status" : "accepted", "timestamp" : time])
            }
            
            let notiID = UUID().uuidString
            let acceptRef = db.collection("users").document(friendID).collection("notifications").document(notiID)
            
            acceptRef.setData(["status" : "accepted", "timestamp" : time, "senderID": uid, "type": "friendRequest", "seen": false])
            
            let sender = PushNotificationSender()
            
            db.collection("users").document(friendID).getDocument {  (tokenSnap, err) in
                                
                if (tokenSnap == nil) {
                    return
                } else {
                    guard let token = tokenSnap?.get("notificationToken") as? String else { return }
                    sender.sendPushNotification(token: token, title: "", body: "\(username) accepted your friend request")
                }
            }
        })
    }
    
    func addFriendToFriendsList(uid: String, friendID: String) {
        
        let db: Firestore = Firestore.firestore()
        let ref = db.collection("users").document(uid)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var friendsList = myDoc.data()?["friendsList"] as? [String] else { return nil }
            friendsList.append(friendID)
            
            var pendingRequests = myDoc.data()? ["pendingFriendRequests"] as? [String] ?? []
            pendingRequests.removeAll(where: {$0 == friendID})
            
            transaction.updateData([
                "friendsList": friendsList,
                "pendingFriendRequests" : pendingRequests
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }

    }
    
    func adjustPostsFriendsList(userID: String, friendID: String) {
        
        let db = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: userID).order(by: "timestamp", descending: true).getDocuments { (snap, err) in
            if err != nil { return }
            for doc in snap!.documents {
                
                /// dont give user access to posts that have been hidden from feed
                let hideFromFeed = doc.get("hideFromFeed") as? Bool ?? false
                if hideFromFeed { continue }
                
                let privacyLevel = doc.get("privacyLevel") as? String ?? "friends"
                if privacyLevel != "invite" {
                    db.collection("posts").document(doc.documentID).updateData(["friendsList" : FieldValue.arrayUnion([friendID])])
                }
            }
        }
    }
    
    func removeFriendRequest(friendID: String, uid: String) {
        
        let db: Firestore! = Firestore.firestore()
        db.collection("users").document(friendID).updateData(["pendingFriendRequests" : FieldValue.arrayRemove([uid])])

        let notificationRef = db.collection("users").document(uid).collection("notifications")
        let query = notificationRef.whereField("type", isEqualTo: "friendRequest").whereField("senderID", isEqualTo: friendID)
        var temp: String!
        query.getDocuments(completion: { [weak self] (snap, err) in
            
            if self == nil { return }
            
            if err != nil {
                print("error")
            } else {
                for document in snap!.documents {
                    temp = document.documentID
                    let finalRef = notificationRef.document(temp)
                    finalRef.delete()
                }
            }
        })
    }
        
    func getAttString(caption: String, taggedFriends: [String]) -> ((NSMutableAttributedString, [(rect: CGRect, username: String)])) {
        
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
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCamera-Semibold", size: 12.5) as Any, range: range)
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
    
    func incrementSpotScore(user: String, increment: Int) {
        let db: Firestore = Firestore.firestore()
        // increments
        /// 1 for like / comment
        /// 3 for creating spot
        /// 3 for post
        let ref = db.collection("users").document(user)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var spotScore: Int = 0
            
            spotScore = myDoc.data()?["spotScore"] as? Int ?? 0
            spotScore += increment
            let finalScore = max(spotScore, 0) // never set sp0tsc0re < 0
            
            transaction.updateData([
                "spotScore": finalScore
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }
    }
    
    func likePostDB(post: MapPost) {
        
        if post.id == "" { return }
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore! = Firestore.firestore()
        
        db.collection("posts").document(post.id!).updateData(["likers" : FieldValue.arrayUnion([uid])])
        incrementSpotScore(user: post.posterID, increment: 1)
        
        if (post.posterID != uid) {
            
            let timestamp = NSDate().timeIntervalSince1970
            let myTimeInterval = TimeInterval(timestamp)
            let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
            
            let notiID = UUID().uuidString
            let notificationRef = db.collection("users").document(post.posterID).collection("notifications")
            let acceptRef = notificationRef.document(notiID)
            
            acceptRef.setData(["seen" : false, "timestamp" : time, "senderID": uid, "type": "like", "spotID": post.spotID ?? "", "postID": post.id ?? "", "imageURL": post.imageURLs.first ?? ""] as [String: Any])
            
            let sender = PushNotificationSender()
            var token: String!
            var senderName: String!
            
            db.collection("users").document(post.posterID).getDocument {  (tokenSnap, err) in
                
                if (tokenSnap == nil) {
                    return
                } else {
                    token = tokenSnap?.get("notificationToken") as? String
                }
                
                db.collection("users").document(uid).getDocument { (userSnap, err) in
                    if (userSnap == nil) {
                        return
                    } else {
                        senderName = userSnap?.get("username") as? String
                        
                        if (token != nil && token != "") {
                            DispatchQueue.main.async { sender.sendPushNotification(token: token, title: "", body: "\(senderName ?? "someone") liked your post") }
                        }
                    }
                }
            }
        }
    }
    
    func unlikePostDB(post: MapPost) {
        
        if post.id == "" { return }
        
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore! = Firestore.firestore()
        
        db.collection("posts").document(post.id!).updateData(["likers" : FieldValue.arrayRemove([uid])])
        
        incrementSpotScore(user: post.posterID, increment: -1)

        let notificationRef = db.collection("users").document(post.posterID).collection("notifications")
        let query = notificationRef.whereField("type", isEqualTo: "like").whereField("postID", isEqualTo: post.id ?? "").whereField("senderID", isEqualTo: uid)
        query.getDocuments { [weak self] (querysnapshot, err) in
            if self == nil { return }
            
            for doc in querysnapshot!.documents {
                doc.reference.delete()
            }
        }
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
        
        let sender = PushNotificationSender()
        var token: String!
        
        db.collection("users").document(spot.founderID).getDocument {  (tokenSnap, err) in
            
            if (tokenSnap == nil) {
                return
            } else {
                token = tokenSnap?.get("notificationToken") as? String
                DispatchQueue.main.async { sender.sendPushNotification(token: token, title: "", body: "\(spot.spotName) was approved!") }
            }
        }
        
        /// change spotLevelValues
        let ref = db.collection("spots").document(spot.id!)
        var adjustedIDs: [String] = []
        var postIDs: [String] = []

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
                        
            let posterIDs = myDoc.data()?["posterIDs"] as? [String] ?? []
            var postPrivacies = myDoc.data()?["postPrivacies"] as? [String] ?? []
            postIDs = myDoc.data()?["postIDs"] as? [String] ?? []
                        
            /// change all of the founder IDs posts to public
            for i in 0...posterIDs.count - 1 {
                if posterIDs[i] == spot.founderID {
                    postPrivacies[i] = "public"
                    adjustedIDs.append(postIDs[i])
                }
            }
            
            /// change spots privacy to public and update post privacies
            transaction.updateData([
                "privacyLevel": "public",
                "postPrivacies": postPrivacies
            ], forDocument: ref)
            
            return nil
            
        }) { (object, error) in
            if error != nil {
                self.adjustPostPrivacies(postIDs: postIDs, adjustedIDs: adjustedIDs)
            } else {
                self.adjustPostPrivacies(postIDs: postIDs, adjustedIDs: adjustedIDs)
            }
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
    
    func animateGIF(directionUp: Bool, counter: Int, frames: Int, alive: Bool) {
        
        if superview == nil || isHidden || animationImages?.isEmpty ?? true { return }
        
        var newDirection = directionUp
        var newCount = counter
        if let postCell = superview as? PostCell { postCell.animationCounter = newCount } /// for smooth animations on likes / other table reloads
        
        if directionUp {
            if counter == frames - 1 {
                newDirection = false
                newCount = frames - 2
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
            self.animateGIF(directionUp: newDirection, counter: newCount, frames: frames, alive: alive)
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
            }else {
                drawingRect.size.height = drawingRect.size.width / imageScale
                drawingRect.origin.y = (bounds.size.height - drawingRect.size.height) / 2
            }
            let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: radius)
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            layer.mask = mask
        }
    }
    
    func enableZoom() {
        
        isUserInteractionEnabled = true
        
        guard let postCell = superview as? PostCell else { return } /// not ideal way to access delegate but right now zoom only enabled on post so its fine
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
        pinchGesture.delegate = postCell
        addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.delegate = postCell
        addGestureRecognizer(panGesture)
    }

        
    @objc func zoom(_ sender: UIPinchGestureRecognizer) {
        
        switch sender.state {
        
        case .began:
            guard let postCell = superview as? PostCell else { return }
            postCell.isZooming = true
            postCell.originalCenter = center
            
        case .changed:
            let pinchCenter = CGPoint(x: sender.location(in: self).x - self.bounds.midX,
                                      y: sender.location(in: self).y - self.bounds.midY)
            
            let transform = self.transform.translatedBy(x: pinchCenter.x, y: pinchCenter.y)
                .scaledBy(x: sender.scale, y: sender.scale)
                .translatedBy(x: -pinchCenter.x, y: -pinchCenter.y)
            
            let currentScale = self.frame.size.width / self.bounds.size.width
            var newScale = currentScale*sender.scale
            if newScale < 1 {
                newScale = 1
                let transform = CGAffineTransform(scaleX: newScale, y: newScale)
                self.transform = transform
            } else {
                //   let transform = CGAffineTransform(scaleX: newScale, y: newScale)
                self.transform = transform
                sender.scale = 1
            }
            
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                guard let self = self else { return }
                guard let postCell = self.superview as? PostCell else { return }
                self.center = postCell.originalCenter
                
                self.transform = CGAffineTransform.identity
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [ weak self] in
                guard let self = self else { return }
                guard let postCell = self.superview as? PostCell else { return }
                postCell.isZooming = false
            }
            
        default: return
        }
    }
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        
        guard let postCell = superview as? PostCell else { return }
        
        if postCell.isZooming && sender.state == .changed {
            let translation = sender.translation(in: self)
            let currentScale = self.frame.size.width / self.bounds.size.width
            center = CGPoint(x: center.x + (translation.x * currentScale), y: center.y + (translation.y * currentScale))
            sender.setTranslation(CGPoint.zero, in: superview)
        }
    }
    
    /// source: https://medium.com/@jeremysh/instagram-pinch-to-zoom-pan-gesture-tutorial-772681660dfe
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
    
    func addBackgroundImage(alpha: CGFloat) {
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
        setBackgroundImage(self.image(fromLayer: gradient), for: .default)
    }
    
    func removeBackgroundImage() {
        setBackgroundImage(UIImage(), for: .default)
    }
    
    func image(fromLayer layer: CALayer) -> UIImage {
        UIGraphicsBeginImageContext(layer.frame.size)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return outputImage!
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
