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
        return pred.evaluate(with: username)
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
    
    func hasAccess(creatorID: String, privacyLevel: String, inviteList: [String], mapVC: MapViewController) -> Bool {
        
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
            
            transaction.updateData([
                "spotScore": spotScore
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }
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
        let ref = db.collection("users").document(uid)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(ref)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            
            var friendsList: [String] = []
            
            friendsList = myDoc.data()?["friendsList"] as! [String]
            if (!friendsList.contains(friendID)) {
                friendsList.append(friendID)
                transaction.updateData([
                    "friendsList": friendsList
                ], forDocument: ref)
            }
            
            return nil
            
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
        //add current user to new friend's friends list
        let friendRef = db.collection("users").document(friendID)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            
            let friendDoc: DocumentSnapshot
            do {
                try friendDoc = transaction.getDocument(friendRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var friendList2: [String] = []
            
            friendList2 = friendDoc.data()?["friendsList"] as! [String]
            //  newFriendUsername = friendDoc.get("username") as! String
            if (!friendList2.contains(uid)) {
                friendList2.append(uid)
                transaction.updateData([
                                        "friendsList": friendList2], forDocument: friendRef)
            }
            
            return nil
            
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
        
        //remove notification
        let notificationRef = db.collection("users").document(uid).collection("notifications")
        let query = notificationRef.whereField("senderID", isEqualTo: friendID).whereField("type", isEqualTo: "friendRequest")
        query.getDocuments(completion: { [weak self] (snap, err) in
            
            if self == nil { return }
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
            
            db.collection("users").document(friendID).getDocument { [weak self]  (tokenSnap, err) in
                
                if self == nil { return }
                
                if (tokenSnap == nil) {
                    return
                } else {
                    guard let token = tokenSnap?.get("notificationToken") as? String else { return }
                    sender.sendPushNotification(token: token, title: "", body: "\(username) accepted your friend request")
                }
            }
        })
    }
    
    func removeFriendRequest(friendID: String, uid: String) {
        let db: Firestore! = Firestore.firestore()
        
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
            
            transaction.updateData([
                "spotScore": spotScore
            ], forDocument: ref)
            
            return nil
            
        }) { _,_ in  }
    }
    
    func likePostDB(post: MapPost) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore! = Firestore.firestore()
        
        incrementSpotScore(user: post.posterID, increment: 1)
        
        ///like post from spots collection if not a free post
        
        if post.spotID != "" {
            let ref = db.collection("spots").document(post.spotID ?? "").collection("feedPost").document(post.id ?? "")
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                
                let myDoc: DocumentSnapshot
                do {
                    try myDoc = transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                var likers: [String] = []
                
                likers = myDoc.data()?["likers"] as? [String] ?? []
                if (!likers.contains(uid)) {
                    likers.append(uid)
                    transaction.updateData([
                        "likers": likers
                    ], forDocument: ref)
                }
                
                return nil
                
            }) { _,_ in  }
        }
        
        let postsRef = db.collection("posts").document(post.id ?? "")
        // update posts likers in DB
        db.runTransaction({ (transaction, error) -> Any? in
            
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(postsRef)
            } catch let fetchError as NSError {
                error?.pointee = fetchError
                return nil
            }
            
            
            var likers: [String] = []
            
            likers = myDoc.data()?["likers"] as? [String] ?? []
            if (!likers.contains(uid)) {
                likers.append(uid)
                transaction.updateData([
                    "likers": likers
                ], forDocument: postsRef)
            }
            
            return nil
            
        }) { _,_ in  }
        
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
                            sender.sendPushNotification(token: token, title: "", body: "\(senderName ?? "someone") liked your post")
                        }
                    }
                }
            }
        }
    }
    
    func unlikePostDB(post: MapPost) {
        let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
        let db: Firestore! = Firestore.firestore()
        
        incrementSpotScore(user: post.posterID, increment: -1)
        
        if post.spotID != "" {
            let ref = db.collection("spots").document(post.spotID ??
                                                        "").collection("feedPost").document(post.id ?? "")
            
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                                
                let myDoc: DocumentSnapshot
                do {
                    try myDoc = transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                
                var likers: [String] = []
                
                likers = myDoc.data()?["likers"] as? [String] ?? []
                if (likers.contains(uid)) {
                    likers.removeAll(where: {$0 == uid})
                    transaction.updateData([
                        "likers": likers
                    ], forDocument: ref)
                }
                
                return nil
                
            }) { _,_ in  }
        }
        
        let postsRef = db.collection("posts").document(post.id ?? "")
        
        db.runTransaction({ (transaction, error) -> Any? in
                        
            let myDoc: DocumentSnapshot
            do {
                try myDoc = transaction.getDocument(postsRef)
            } catch let fetchError as NSError {
                error?.pointee = fetchError
                return nil
            }
            
            var likers: [String] = []
            
            likers = myDoc.data()?["likers"] as? [String] ?? []
            if (likers.contains(uid)) {
                likers.removeAll(where: {$0 == uid})
                transaction.updateData([
                    "likers": likers
                ], forDocument: postsRef)
            }
            
            return nil
            
        }) { _,_ in  }
        
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
        
        UIView.transition(with: self, duration: 0.09, options: [.transitionCrossDissolve, .allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
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

