//
//  PublicSpotReviewController.swift
//  Spot
//
//  Created by kbarone on 9/12/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation
import GoogleMaps
import UIKit

class PublicSpotReviewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
  /*
    var tableView: UITableView!
    var listener1, listener2, listener3, listener4, listener5, listener6: ListenerRegistration!
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    var dispatchGroup = DispatchGroup()
    var mapView: GMSMapView!
    var spotIDs: [(spotID: String, docID: String)] = []
    var selectedSpotIndex = 0
    var visitorList: [String] = []
    var imageURLs: [String] = []
    var spotObject = AboutSpot(spotImage: [UIImage](), spotName: "", userImage: UIImage(), username: "", description: "", tags: [String](), address: "", directions: "", tips: "", labelType: "", founderID: "", spotID: "")
    var spotImages: [UIImage] = []
    var imageHeight: CGFloat = 0
    var selectedImageIndex = 0
    
    var descriptionHeight: CGFloat = 0
    var cellCount = 4
    var tags: [String] = []
    
    var postsList: [FeedPost] = []
    var postCount = 0
    var postIndex = 0
    
    var spotLat = 0.0
    var spotLong = 0.0
    
    var acceptButton: UIButton!
    var acceptAsBot: UIButton!
    var rejectButton: UIButton!
    
    var friendsListRaw: [String] = []
    var friendsList: [(uid: String, username: String, name: String)] = []
    
    var friendVisitorsRaw: [String] = []
    var friendVisitors: [Friend] = []
    
    override func viewDidLoad() {
        self.view.backgroundColor = UIColor(named: "SpotBlack")
        setUpViews()
        getIDs()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeListeners()
    }
    func removeListeners() {
        if self.listener1 != nil {self.listener1.remove()}
        if self.listener2 != nil {self.listener2.remove()}
        if self.listener3 != nil {self.listener3.remove()}
        if self.listener4 != nil {self.listener4.remove()}
        if self.listener5 != nil {self.listener5.remove()}
    }
    
    func setUpViews() {
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 110))
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isOpaque = true
        tableView.clearsContextBeforeDrawing = false
      //  tableView.register(DescriptionCell.self, forCellReuseIdentifier: "DescriptionCell")
       // tableView.register(GuestbookScroll.self, forCellReuseIdentifier: "GuestbookScroll")
       // tableView.register(MapViewCell.self, forCellReuseIdentifier: "MapCell")
       // tableView.register(visitorsCell.self, forCellReuseIdentifier: "VisitorCell")

        view.addSubview(tableView)
        
        acceptButton = UIButton(frame: CGRect(x: 20, y: 100, width: 110, height: 30))
        acceptButton.layer.cornerRadius = 15
        acceptButton.layer.borderWidth = 1
        acceptButton.layer.borderColor = UIColor(named: "SpotGreen")?.cgColor
        acceptButton.backgroundColor = nil
        acceptButton.setTitle("Accept", for: UIControl.State.normal)
        acceptButton.setTitleColor(UIColor(named: "SpotGreen"), for: UIControl.State.normal)
        acceptButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        acceptButton.addTarget(self, action: #selector(acceptTap(_:)), for: UIControl.Event.touchUpInside)
        view.addSubview(acceptButton)
        
        rejectButton = UIButton(frame: CGRect(x: 145, y: 100, width: 110, height: 30))
        rejectButton.layer.cornerRadius = 15
        rejectButton.layer.borderWidth = 1
        rejectButton.layer.borderColor = UIColor.red.cgColor
        rejectButton.backgroundColor = nil
        rejectButton.setTitle("Reject", for: UIControl.State.normal)
        rejectButton.setTitleColor(UIColor.red, for: UIControl.State.normal)
        rejectButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        rejectButton.addTarget(self, action: #selector(rejectTap(_:)), for: UIControl.Event.touchUpInside)
        view.addSubview(rejectButton)
        
        acceptAsBot = UIButton(frame: CGRect(x: 270, y: 100, width: 110, height: 30))
        acceptAsBot.layer.cornerRadius = 15
        acceptAsBot.layer.borderWidth = 1
        acceptAsBot.layer.borderColor = UIColor.systemBlue.cgColor
        acceptAsBot.backgroundColor = nil
        acceptAsBot.setTitle("Accept as Bot", for: UIControl.State.normal)
        acceptAsBot.setTitleColor(UIColor.systemBlue, for: UIControl.State.normal)
        acceptAsBot.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 14)
        acceptAsBot.addTarget(self, action: #selector(acceptAsBotTap(_:)), for: UIControl.Event.touchUpInside)
        view.addSubview(acceptAsBot)
    }
    func getIDs() {
        self.db.collection("submissions").getDocuments { (idSnap, err) in
            let count = idSnap?.documents.count
            var index = 0
            for doc in idSnap!.documents {
                let spotID = doc.get("spotID") as! String
                self.spotIDs.append((spotID, doc.documentID))
                index = index + 1
                if index == count {
                    self.loadSpotData()
                }
            }
        }
    }
    func loadSpotData() {
        self.listener2 = self.db.collection("spots").document(spotIDs[selectedSpotIndex].spotID).addSnapshotListener({ (spotSnap, err) in
            if let tempName = spotSnap!.get("spotName") as? String {
                self.spotObject.spotName = tempName
                self.visitorList = spotSnap!.get("visitorList") as! [String]
                
                if self.visitorList.contains(self.uid) {
                                     self.friendVisitorsRaw.append(self.uid)
                                 }
                                 
                                 if !self.friendsListRaw.isEmpty {
                                     self.getFriendVisitors()
                                 }
                                 
            
                
                let imageURL = spotSnap!.get("imageURL") as? String
                self.imageURLs.append(imageURL!)
                if let imageURL1 = spotSnap!.get("imageURL1") as? String {
                    self.imageURLs.append(imageURL1)
                }
                if let imageURL2 = spotSnap!.get("imageURL2") as? String {
                    self.imageURLs.append(imageURL2)
                }
                if let imageURL3 = spotSnap!.get("imageURL3") as? String {
                    self.imageURLs.append(imageURL3)
                }
                if let imageURL4 = spotSnap!.get("imageURL4") as? String {
                    self.imageURLs.append(imageURL4)
                }
                self.spotObject.description = (spotSnap!.get("description") as? String)!
                
                let dLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 70, height: 20))
                dLabel.font = UIFont(name: "SFCamera-regular", size: 13)
                dLabel.numberOfLines = 0
                dLabel.lineBreakMode = .byWordWrapping
                dLabel.text = self.spotObject.description
                dLabel.sizeToFit()
                self.descriptionHeight = dLabel.bounds.height
                                    
                    let tag1 = spotSnap!.get("tag1") as! String
                    self.spotObject.tags.append(tag1)
                    self.tags.append(tag1)
                    
                    
                    let tag2 = spotSnap!.get("tag2") as! String
                    self.spotObject.tags.append(tag2)
                    self.tags.append(tag2)
                    
                    
                    let tag3 = spotSnap!.get("tag3") as! String
                    self.spotObject.tags.append(tag3)
                    self.tags.append(tag3)
                    
                    
                
                let arrayLocation = spotSnap!.get("l") as! [NSNumber]
                
                self.spotLat = arrayLocation[0] as! Double
                self.spotLong = arrayLocation[1] as! Double
                
                self.mapView = GMSMapView(frame: CGRect(x: 0, y: 0, width: 100, height: 150), camera: GMSCameraPosition(latitude: self.spotLat, longitude: self.spotLong, zoom: 15))
                self.mapView.isBuildingsEnabled = true
                self.mapView.isUserInteractionEnabled = false
                self.mapView.layer.cornerRadius = 8
                
                let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: self.spotLat, longitude: self.spotLong))
                marker.map = self.mapView
                marker.isTappable = false
                
                let location = CLLocation(latitude: self.spotLat, longitude: self.spotLong)
                
                self.reverseGeocodeFromCoordinate(numberOfFields: 4, location: location) { address in
                    self.spotObject.address = address
                }
                
                self.spotObject.founderID = spotSnap!.get("createdBy") as? String ?? ""
                
                self.tableView.reloadData()
                self.getProfileImage()
                self.getGuestbook()
            }
            
        })
    }
    
    
    func getFriendVisitors() {
         self.friendsListRaw.append(self.uid)
         
         if self.visitorList.contains(self.uid) {
             self.friendVisitorsRaw.append(self.uid)
         }
         
         for visitor in self.visitorList {
             if self.friendsListRaw.contains(visitor) && visitor != "T4KMLe3XlQaPBJvtZVArqXQvaNT2" {
                 self.friendVisitorsRaw.append(visitor)
             }
         }
         self.getFriends()
     }
     
     func getFriends() {
         for friend in self.friendsListRaw {
             self.listener6 = self.db.collection("users").document(friend).addSnapshotListener { (snap, err) in
                 if err != nil {
                     return
                 } else {
                     if let name = snap!.get("name") as? String {
                         let username = snap!.get("username") as! String
                         let profilePicURL = snap!.get("imageURL") as! String
                         self.friendsList.append((uid: friend, username: username, name: name))
                         ///need to populate get friend visitors raw before this is called for drawer
                         if self.friendVisitorsRaw.contains(friend) {
                             print("found friend visitor")
                             if self.cellCount == 3 {
                                 self.cellCount += 1
                             }
                             self.getVisitorProfile(friend: Friend(id: friend, username: username, profilePicURL: profilePicURL, profileImage: UIImage(), name: name))
                         }
                     }
                 }
             }
         }
     }
    
    func getVisitorProfile(friend: Friend) {
          print("ran get visitor profile")
          let newFriend = friend
          let profileReference = Storage.storage().reference(forURL: friend.profilePicURL)
          profileReference.getData(maxSize: 1 * 2048 * 2048) { data, error in
              if error != nil {
                  print("error occured")
              } else {
                  let image = UIImage(data: data!)
                  newFriend.profileImage = image ?? UIImage()
                  self.friendVisitors.append(newFriend)
              }
          }
      }
      
    
    func getProfileImage() {
        var profileURL = ""
        var username = ""
        
        self.listener3 = self.db.collection("users").document(self.spotObject.founderID).addSnapshotListener{ (userSnap, err) in
            if err != nil {
                return
            } else {
                profileURL = userSnap!.get("imageURL") as! String
                username = userSnap!.get("username") as! String
                
                let profileReference = Storage.storage().reference(forURL: profileURL)
                profileReference.getData(maxSize: 1 * 2048 * 2048) { data, error in
                    if error != nil {
                        print("error occured")
                    } else {
                        let image = UIImage(data: data!)
                        self.spotObject.userImage = image!
                        self.spotObject.username = username
                        self.tableView.reloadData()
                    }
                    
                }
            }
        }
    }
    func getGuestbook() {
        self.listener4 = self.db.collection("spots").document(self.spotIDs[selectedSpotIndex].spotID).collection("feedPost").addSnapshotListener { (guestbookSnap, err) in
            if err != nil {
                return
            }
            self.postCount = guestbookSnap!.documents.count
            
            docLoop: for doc in guestbookSnap!.documents {
                let postID = doc.documentID
                let caption = doc.get("caption") as! String
                var imgURLs: [String] = []
                
                if (doc.get("imageURL") != nil) {
                    imgURLs.append(doc.get("imageURL") as! String)
                }
                if (doc.get("imageURL1") != nil) {
                    imgURLs.append(doc.get("imageURL1") as! String)
                }
                if (doc.get("imageURL2") != nil) {
                    imgURLs.append(doc.get("imageURL2") as! String)
                }
                if (doc.get("imageURL3") != nil) {
                    imgURLs.append(doc.get("imageURL3") as! String)
                }
                if (doc.get("imageURL4") != nil) {
                    imgURLs.append(doc.get("imageURL4") as! String)
                }
                var taggedPosters: [String] = []
                if let pFriends = doc.get("taggedUsers") as? [String] {
                    taggedPosters = pFriends
                }
                var gif = false
                if let g = doc.get("gif") as? Bool {
                    if g {gif = true}
                }
                
                let likers = doc.get("likers") as! [String]
                let rawTimeStamp = doc.get("timestamp") as! Timestamp
                let seconds = rawTimeStamp.seconds
                let postDate = rawTimeStamp.dateValue()
                var wasLiked = false
                if likers.contains(self.uid) {
                    wasLiked = true
                }
                let posterID = doc.get("posterID") as! String
                
                var commentsArray = [Comment]()
                
                var seen = false
                
                if let seenList = doc.get("seenList") as? [String] {
                    if seenList.contains(self.uid) { seen = true }
                }
                
                self.listener5 = self.db.collection("spots").document(self.spotIDs[self.selectedSpotIndex].spotID).collection("feedPost").document(postID).collection("Comments").addSnapshotListener { (commentSnap, err) in
                    if err != nil {
                        print("busted")
                        return
                    }
                    var index = 0
                    let newPost = FeedPost(spotname: self.spotObject.spotName, spotID: self.spotIDs[self.selectedSpotIndex].spotID, posterID: posterID, founderID: self.spotObject.founderID, captionText: caption, captionHeight: 0, imageURL: imgURLs, photo: [UIImage](), uNameString: "", profilePic: UIImage(), likers: likers, wasLiked: wasLiked, location: "", spotLat: 0, spotLong: 0, time: seconds, date: postDate, postID: postID, commentList: commentsArray, imageHeight: 0, isFirst: false, seen: seen, friends: false, selectedImageIndex: 0, privacyLevel: "friends", taggedFriends: taggedPosters, GIF: gif)
                    
                    if commentSnap!.documents.count != 0 {
                        for docs in commentSnap!.documents {
                            let commentID = docs.documentID
                            let commenterID = docs.get("commenterID") as! String
                            let comment = docs.get("comment") as! String
                            let commentTime = docs.get("timestamp") as! Timestamp
                            let commentSeconds = commentTime.seconds
                            var taggedFriends: [String] = []
                            if let sFriends = docs.get("taggedUsers") as? [String] {
                                taggedFriends = sFriends
                            }
                            if commentSeconds == seconds {
                                index = index + 1
                                if index == commentSnap!.documents.count {
                                    newPost.commentList = commentsArray
                                    self.setUpPost(post: newPost)
                                } else {
                                    continue
                                }
                            }
                            let commentDate = commentTime.dateValue()
                            let newComment = Comment(commentID: commentID, commenterID: commenterID, comment: comment, time: commentSeconds, date: commentDate, taggedFriends: taggedFriends, commentHeight: 0)
                            
                            if (!commentsArray.contains(where: {$0.time == commentSeconds})) {
                                commentsArray.append(newComment)
                            }
                            
                            index = index + 1
                            if index == commentSnap!.documents.count {
                                newPost.commentList = commentsArray
                                self.setUpPost(post: newPost)
                            }
                        }
                        
                    } else {
                        self.setUpPost(post: newPost)
                    }
                    
                }
            }
        }
    }
    func setUpPost(post: FeedPost) {
        self.listener4 = self.db.collection("users").document(post.posterID).addSnapshotListener { (posterSnapshot, posterErr) in
            
            let posterUserName : String = posterSnapshot?.get("username") as! String
            
            let profilePicURL : String = posterSnapshot?.get("imageURL") as! String
            
            let profileImgRef = Storage.storage().reference(forURL: profilePicURL)
            
            let newPost = post
            post.uName = posterUserName
            
            self.getPostImages(post: newPost, profileImgRef: profileImgRef)
            
        }
    }
    func getPostImages(post: FeedPost, profileImgRef: StorageReference) {
        
        var index = 0
        var images: [UIImage] = []
        var profileImage = UIImage()
        for _ in post.imageURL {
            images.append(UIImage())
        }
        
        dispatchGroup.enter()
        urlLoop: for url in post.imageURL {
            if url == "" {
                let image = UIImage()
                let i = post.imageURL.lastIndex(where: {$0 == url})
                images[i ?? 0] = image
                index = index + 1
                if index == post.imageURL.count {
                    self.dispatchGroup.leave()
                }
            } else {
                let postRef = Storage.storage().reference(forURL: url)
                if (postRef != StorageReference()) {
                    postRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
                        if error != nil {
                            return
                        } else {
                            let image = UIImage(data: data!)!
                            let i = post.imageURL.lastIndex(where: {$0 == url})
                            images[i ?? 0] = image
                            index = index + 1
                            if index == post.imageURL.count {
                                self.dispatchGroup.leave()
                            }
                        }
                        
                    }
                }
            }
        }
        dispatchGroup.enter()
        profileImgRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
            if error != nil {
                return
            } else {
                profileImage = UIImage(data: data!)!
                self.dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) {
            let newPost = post
            newPost.profilePic = profileImage
            newPost.photo = images
            if !self.postsList.contains(where: {$0.postID == newPost.postID}) {
                self.postsList.append(newPost)
                
                
                self.postIndex = self.postIndex + 1
                if self.postIndex == self.postCount {
                    //running now to make sure friends list has already been fetched
                    
                    
                    self.postsList.sort(by: {$0.time > $1.time})
                    self.postsList.sort(by: {$0.friends && !$1.friends})
                    self.postsList.sort(by: {!$0.seen && $1.seen})
                    
                    self.tableView.reloadData()
                }
            }
        }
    }
    
   
    @objc func acceptTap(_ sender: UIButton) {
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        db.collection("submissions").document(spotIDs[selectedSpotIndex].docID).delete()
        db.collection("spots").document(spotIDs[selectedSpotIndex].spotID).updateData(["privacyLevel" : "public"])
        for post in postsList {
            db.collection("posts").document(post.postID).updateData(["privacyLevel" : "public"])
        }
        
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(self.spotObject.founderID).collection("notifications").document(notiID)
        
        let values = ["senderID" : "T4KMLe3XlQaPBJvtZVArqXQvaNT2",
                      "type" : "publicSpotAccepted",
                      "timestamp" : time,
                      "imageURL" : self.imageURLs[0] as Any,
                      "spotID" : self.spotIDs[selectedSpotIndex].spotID as Any,
                      "postID" : "",
                      "spotName" : spotObject.spotName,
                      "status" : "pending",
                      "seen" : false
            ] as [String : Any]
        ref.setData(values)
        
        let sender = PushNotificationSender()
        var token: String!
                
        self.db.collection("users").document(self.spotObject.founderID).getDocument { (tokenSnap, err) in
            if (tokenSnap == nil) {
                return
            } else {
                token = tokenSnap?.get("notificationToken") as? String
                
                if (token != nil && token != "") {
                    sender.sendPushNotification(token: token, title: "", body: "\(self.spotObject.spotName) was approved!")
                }
            }
            
        }
        transitionSpots()
    }
    
    @objc func rejectTap(_ sender: UIButton) {
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        transitionSpots()
        db.collection("submissions").document(spotIDs[selectedSpotIndex].docID).delete()
        
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(self.spotObject.founderID).collection("notifications").document(notiID)
        
        
        let values = ["senderID" : "T4KMLe3XlQaPBJvtZVArqXQvaNT2",
                      "type" : "publicSpotRejected",
                      "timestamp" : time,
                      "imageURL" : self.imageURLs[0] as Any,
                      "spotID" : self.spotIDs[selectedSpotIndex].spotID as Any,
                      "spotName" : spotObject.spotName,
                      "status" : "pending",
                      "postID" : "",
                      "seen" : false
            ] as [String : Any]
        ref.setData(values)
        
        transitionSpots()
        
    }
    
    @objc func acceptAsBotTap(_ sender: UIButton) {
        
        let sender = PushNotificationSender()
        var token: String!
        
        db.collection("submissions").document(spotIDs[selectedSpotIndex].docID).delete()
        
        self.db.collection("users").document(self.spotObject.founderID).getDocument { (tokenSnap, err) in
            if (tokenSnap == nil) {
                return
            } else {
                token = tokenSnap?.get("notificationToken") as? String
                
                if (token != nil && token != "") {
                    sender.sendPushNotification(token: token, title: "", body: "\(self.spotObject.spotName) was approved!")
                }
            }
            
        }
        
        db.collection("spots").document(spotIDs[selectedSpotIndex].spotID).updateData(["privacyLevel" : "public"])
        
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        
        db.collection("spots").document(spotIDs[selectedSpotIndex].spotID).updateData(["createdBy" : "T4KMLe3XlQaPBJvtZVArqXQvaNT2"])
        db.collection("users").document("T4KMLe3XlQaPBJvtZVArqXQvaNT2").collection("spotsList").document(self.spotIDs[selectedSpotIndex].spotID).setData(["spotID" : self.spotIDs[selectedSpotIndex].spotID as Any, "checkInTime" : time, "postsList": [String]()])
        
        let notiID = UUID().uuidString
        let ref = db.collection("users").document(self.spotObject.founderID).collection("notifications").document(notiID)
        
        let values = ["senderID" : "T4KMLe3XlQaPBJvtZVArqXQvaNT2",
                      "type" : "publicSpotAccepted",
                      "timestamp" : time,
                      "imageURL" : self.imageURLs[0] as Any,
                      "spotID" : self.spotIDs[selectedSpotIndex].spotID as Any,
                      "postID" : "",
                      "spotName" : spotObject.spotName,
                      "status" : "pending",
                      "seen" : false
            ] as [String : Any]
        ref.setData(values)
        
        transitionSpots()
        
    }
    
    func transitionSpots() {
        if selectedSpotIndex != spotIDs.count - 1 {
            selectedSpotIndex += 1
        } else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        visitorList.removeAll()
        imageURLs.removeAll()
        spotObject = AboutSpot(spotImage: [UIImage](), spotName: "", userImage: UIImage(), username: "", description: "", tags: [String](), address: "", directions: "", tips: "", labelType: "", founderID: "", spotID: "")
        spotImages.removeAll()
        imageHeight = 0
        selectedImageIndex = 0
        descriptionHeight = 0
        cellCount = 4
        tags.removeAll()
        postsList.removeAll()
        postCount = 0
        postIndex = 0
        spotLat = 0.0
        spotLong = 0.0
        loadSpotData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellCount
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 400
    }
    
    
      func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

          if indexPath.row == 0 {
              return descriptionHeight + 88
          } else if indexPath.row == 1 {
              return 197
          } else if indexPath.row == 2 {
              if cellCount == 3 {
                  return 120
              } else {
                  return 95
              }
          } else {
              return 120
          }
      }
      
      func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
          if (indexPath.row == 0) {
              let cell = tableView.dequeueReusableCell(withIdentifier: "DescriptionCell") as! DescriptionCell
            if tags.count < 3 { return cell }
              cell.setUp(model: self.spotObject, index: self.selectedImageIndex, privacyLevel: "friends", tag1: spotObject.tags[0], tag2: spotObject.tags[1], tag3: spotObject.tags[2])
            
              return cell
            
          } else if indexPath.row == 1 {
              let cell = tableView.dequeueReusableCell(withIdentifier: "GuestbookScroll") as! GuestbookScroll
              cell.setUp(posts: postsList, spot: spotObject, notiPostID: "", commentNoti: false)
       
              return cell
              //change to friends cell
          } else if indexPath.row == 2 {
              if cellCount == 3 {
                  let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell") as! MapViewCell
                  cell.setUp(spotLocation: CLLocation(latitude: self.spotLat, longitude: self.spotLong), mapView: self.mapView, spot: self.spotObject)
                  return cell
              }
              let cell = tableView.dequeueReusableCell(withIdentifier: "VisitorCell") as! visitorsCell
              cell.setUp(friendVisitors: self.friendVisitors)
              return cell
              
              //change to map cell
          } else {
              let cell = tableView.dequeueReusableCell(withIdentifier: "MapCell") as! MapViewCell
            if mapView == nil {return cell}
              cell.setUp(spotLocation: CLLocation(latitude: self.spotLat, longitude: self.spotLong), mapView: self.mapView, spot: self.spotObject)
              return cell
          }
      }
    
    
}*/
