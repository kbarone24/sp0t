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
        
        db.collection("posts").whereField("posterID", isEqualTo: posterID).getDocuments { (snap, err) in
            if err == nil {
                
                var index = 0
                if snap!.documents.count == 0 { completion(true); return }
                
                for doc in snap!.documents {
                    if let _ = doc.get("friendsList") as? [String] {
                        doc.reference.updateData(["friendsList" : FieldValue.arrayRemove([friendID])])
                        
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
    
    func getCoordinateFrom(address: String, completion: @escaping(_ coordinate: CLLocationCoordinate2D?, _ error: Error?) -> () ) {
        CLGeocoder().geocodeAddressString(address) { completion($0?.first?.location?.coordinate, $1) }
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
        db.collection("users").document(uid).updateData(["friendsList" : FieldValue.arrayUnion([friendID])])
        adjustPostsFriendsList(userID: uid, friendID: friendID)
        /// add current user to new friends friendsList
        db.collection("users").document(friendID).updateData(["friendsList" : FieldValue.arrayUnion([uid])])
        adjustPostsFriendsList(userID: friendID, friendID: uid)
        db.collection("users").document(friendID).updateData(["pendingFriendRequests" : FieldValue.arrayRemove([uid])])

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
    
    func adjustPostsFriendsList(userID: String, friendID: String) {
        
        let db = Firestore.firestore()
        db.collection("posts").whereField("posterID", isEqualTo: userID).getDocuments { (snap, err) in
            if err != nil { return }
            for doc in snap!.documents {
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
        
        let word = caption.split(separator: " ")
        var index = 0
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") && taggedFriends.contains(where: {$0 == username}) {
                let tag = (username: String(w.dropFirst()), range: NSMakeRange(index + 1, w.count - 1))
                if !tags.contains(where: {$0 == tag}) {
                    tags.append(tag)
                    let range = NSMakeRange(index, w.count)
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCamera-Semibold", size: 12.5) as Any, range: range)
                }
            }
            index = index + w.count + 1
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
        db.collection("spots").document(spot.id!).updateData(["privacyLevel" : "public"])
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
    
    func animateGIF(directionUp: Bool, counter: Int, photos: [UIImage]) {
        
        if superview == nil { return }
        
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
        
        UIView.transition(with: self, duration: 0.09, options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
            guard let self = self else { return }
                            self.image = photos[counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount, photos: photos)
        }
    }
    
    func animateGIF(directionUp: Bool, counter: Int) {
    
        if superview == nil { return }
        
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
                            self.image = self.animationImages![counter] },
                          completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.085) { [weak self] in
            guard let self = self else { return }
            self.animateGIF(directionUp: newDirection, counter: newCount)
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
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(startZooming(_:)))
        isUserInteractionEnabled = true
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func startZooming(_ sender: UIPinchGestureRecognizer) {
        if sender.state == .began || sender.state == .changed {
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
        } else if sender.state == .ended || sender.state == .cancelled {
            UIView.animate(withDuration: 0.3, animations: {
                self.transform = CGAffineTransform.identity
            })
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

extension String {
    func formatNumber() -> String {
        var newNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined() /// remove dashes and spaces 
        newNumber = String(newNumber.suffix(10)) /// match based on last 10 digits to eliminate country codes and formatting
        return newNumber
    }
}
/*
extension UICollectionViewCell {
    
    func addCellShadow() {

        let shadows = UIView()
        shadows.frame = bounds
        shadows.clipsToBounds = false
        shadows.tag = 11
        addSubview(shadows)

        let shadowPath0 = UIBezierPath(roundedRect: bounds, cornerRadius: 7.5)
        let layer0 = CALayer()
        layer0.shadowPath = shadowPath0.cgPath
        layer0.shouldRasterize = true
        layer0.rasterizationScale = UIScreen.main.scale
        layer0.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4).cgColor
        layer0.shadowOpacity = 1
        layer0.shadowRadius = 1.5
        layer0.shadowOffset = CGSize(width: 0.25, height: 1)
        layer0.bounds = shadows.bounds
        layer0.position = shadows.center
        shadows.layer.addSublayer(layer0)
        
    }
    
    func addCellBorder() {
        
        let shapes = UIView()
        shapes.frame = bounds
        shapes.clipsToBounds = true
        shapes.tag = 12
        addSubview(shapes)
        
        let color1 = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.00)
        let color2 = UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 1.00)
        let layer1 = CAGradientLayer()
        layer1.frame = shapes.bounds
        layer1.shouldRasterize = true
        layer1.shadowPath = UIBezierPath(roundedRect: shapes.bounds, cornerRadius: 7.5).cgPath
        layer1.rasterizationScale = UIScreen.main.scale
        layer1.colors = [color1, color2]
        
        let shape = CAShapeLayer()
        shape.lineWidth = 1
        shape.path = UIBezierPath(roundedRect: shapes.bounds, cornerRadius: 7.5).cgPath
        shape.strokeColor = UIColor.blue.cgColor
        shape.fillColor = UIColor.clear.cgColor
        layer1.mask = shape
        shapes.layer.addSublayer(layer1)
    }
    
}
*/

