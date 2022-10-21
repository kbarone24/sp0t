//  AddSpotViewController.swift
//  Spot
//
//  Created by kbarone on 4/7/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
import CoreData
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Geofirestore
import MapKit
import Photos
import RSKImageCropper
import UIKit

protocol CreatePostDelegate {
    func FinishPassing(post: FeedPost)
}

class CreatePostViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    func setUpImages() {
        selectedImageIndex = 0
        selectedImageView.image = self.selectedImages[0]
        selectedImageView.roundCornersForAspectFit(radius: 8)
        setImageViewBounds()
        addPostButton()
        if gifMode {
            self.selectedImageView.animateGIF(directionUp: true, counter: 0, photos: self.selectedImages)
        } else {
            if self.selectedImages.count > 1 {
                self.nextImageView.image = self.selectedImages[1]
                self.nextImageView.roundCornersForAspectFit(radius: 8)
                self.setUpDotView(count: self.selectedImages.count)
            }

            let swipe = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            swipe.cancelsTouchesInView = false
            self.selectedImageView.addGestureRecognizer(swipe)
        }
    }

    var selectedImagesFromPicker: [(UIImage, Int, CLLocation)] = []
    var selectedImages: [UIImage] = []

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var descriptionTextField: UITextView!

    var selectedImageView: UIImageView!
    var nextImageView: UIImageView!
    var previousImageView: UIImageView!
    var selectedImageIndex = 0
    var dotView: UIView!

    var username: String!
    var posterProfile: UIImageView!
    let db = Firestore.firestore()
    var urlStr: String = ""
    var checkedInNow = false
    var postBtn: UIBarButtonItem!

    var spotObject = ((id: "", name: "Add post", founder: ""))

    var passedImages = false
    var delegate: CreatePostDelegate?

    var delegateObject = FeedPost(spotname: "", spotID: "", posterID: "", founderID: "", captionText: "", captionHeight: 0, imageURL: [""], photo: [UIImage()], uNameString: "", profilePic: UIImage(), likers: [String](), wasLiked: false, location: "", spotLat: 0, spotLong: 0, time: 0, date: Date(), postID: "", commentList: [Comment](), imageHeight: 0, isFirst: false, seen: false, friends: false, selectedImageIndex: 0, privacyLevel: "", taggedFriends: [""], GIF: false)

    var profilePicURL = ""
    var imageURL = ""
    var friendsListRaw: [String] = []
    var friendsList: [(uid: String, username: String, name: String)] = []

    var imageHeight = 0

    let newPostNotificationName = Notification.Name("newPost")
    let checkInNotificationName = Notification.Name("checkIn")

    var checkedInBefore = false

    var errorBox: UIView!
    var errorTextLayer: UILabel!

    var notiID: String!

    var constantHeight: CGFloat = 104.0

    var start: CFAbsoluteTime!

    var postID: String!
    var firstCommentID: String!
    var privacy: String!
    var spotLat: Double = 0.0
    var spotLong: Double = 0.0
    var city: String!
    var inviteList: [String] = []

    var listener1, listener2, listener3, listener4: ListenerRegistration!

    var progressView: UIProgressView!

    var shouldUploadPost: Bool!
    var imageFromCamera: UIImage!
    var cameraFacingFront = false
    var gifMode = false

    var animationImages: [UIImage] = []

    var queryObject: [(name: String, username: String)] = []

    var queried = false
    var resultsView: UITableView!

    var selectedUsers: [(uid: String, username: String, name: String)] = []

    var largeScreen = false

    var draftID: Int64!

    override func viewDidLoad() {

        super.viewDidLoad()

        start = CFAbsoluteTimeGetCurrent()

        shouldUploadPost = true

        if UIScreen.main.nativeBounds.height > 2_400 || UIScreen.main.nativeBounds.height == 1_792 {
            errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 180, width: UIScreen.main.bounds.width, height: 32))
            errorTextLayer = UILabel(frame: CGRect(x: 23, y: UIScreen.main.bounds.height - 174, width: UIScreen.main.bounds.width - 46, height: 18))
            largeScreen = true

        } else {
            errorBox = UIView(frame: CGRect(x: 0, y: UIScreen.main.bounds.height - 160, width: UIScreen.main.bounds.width, height: 32))
            errorTextLayer = UILabel(frame: CGRect(x: 23, y: UIScreen.main.bounds.height - 154, width: UIScreen.main.bounds.width - 46, height: 18))
            constantHeight = 74.0
        }

        self.notiID = UUID().uuidString
        errorBox.backgroundColor = UIColor(red: 0.35, green: 0, blue: 0.04, alpha: 1)
        self.view.addSubview(errorBox)
        errorBox.isHidden = true

        // Load error text
        errorTextLayer.lineBreakMode = .byWordWrapping
        errorTextLayer.numberOfLines = 0
        errorTextLayer.textColor = UIColor.white
        errorTextLayer.textAlignment = .center
        let errorTextContent = "Add a picture with your post"
        let errorTextString = NSMutableAttributedString(string: errorTextContent, attributes: [
            NSAttributedString.Key.font: UIFont(name: "SFCamera-regular", size: 14)!
        ])
        let errorTextRange = NSRange(location: 0, length: errorTextString.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.14
        errorTextString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: errorTextRange)
        errorTextLayer.textAlignment = .center
        errorTextLayer.attributedText = errorTextString
        //  errorTextLayer.sizeToFit()
        self.view.addSubview(errorTextLayer)
        errorTextLayer.isHidden = true

        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: newPostNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCheckIn(_:)), name: checkInNotificationName, object: nil)

        self.view.backgroundColor = UIColor(named: "SpotBlack")

        // Post button

        selectedImageView = UIImageView(frame: CGRect(x: 15, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3))
        selectedImageView.contentMode = .scaleAspectFit
        selectedImageView.isUserInteractionEnabled = true
        selectedImageView.image = UIImage()
        view.addSubview(selectedImageView)

        nextImageView = UIImageView(frame: CGRect(x: 15 + UIScreen.main.bounds.width, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3))
        nextImageView.contentMode = .scaleAspectFit
        nextImageView.isUserInteractionEnabled = true
        view.addSubview(nextImageView)

        previousImageView = UIImageView(frame: CGRect(x: -(15 + UIScreen.main.bounds.width), y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3))
        previousImageView.contentMode = .scaleAspectFit
        previousImageView.isUserInteractionEnabled = true
        view.addSubview(previousImageView)

        self.setUpImages()

        descriptionTextField = UITextView(frame: CGRect(x: 53, y: selectedImageView.bounds.height + 51 + constantHeight, width: UIScreen.main.bounds.width - 65, height: 70))
        descriptionTextField.delegate = self
        descriptionTextField.textAlignment = .left
        descriptionTextField.text = "Write a caption..."
        descriptionTextField.backgroundColor = nil
        descriptionTextField.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.0)
        descriptionTextField.alpha = 0.65
        descriptionTextField.font = UIFont(name: "SFCamera-regular", size: 13)!
        descriptionTextField.isScrollEnabled = false
        descriptionTextField.textContainer.lineBreakMode = .byTruncatingHead
        //      descriptionTextField.autocorrectionType = .no
        descriptionTextField.keyboardDistanceFromTextField = 100

        view.addSubview(descriptionTextField)

        posterProfile = UIImageView(frame: CGRect(x: 15, y: selectedImageView.bounds.height + 48 + constantHeight, width: 36, height: 36))
        //   posterProfile.image = self.postsList[indexPath.row].profilePic
        // fetch profile pic
        posterProfile.layer.masksToBounds = false
        posterProfile.layer.cornerRadius = posterProfile.frame.height / 2
        posterProfile.clipsToBounds = true
        posterProfile.contentMode = UIView.ContentMode.scaleAspectFill
        let genericProfile = UIImage(named: "Profile1x.png")!
        self.posterProfile.image = genericProfile
        // placeholder profile

        progressView = UIProgressView(frame: CGRect(x: 50, y: UIScreen.main.bounds.minY + 400, width: UIScreen.main.bounds.width - 100, height: 20))
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 10)
        progressView.layer.cornerRadius = 5
        progressView.layer.sublayers![1].cornerRadius = 5
        progressView.subviews[1].clipsToBounds = true
        progressView.clipsToBounds = true
        progressView.isHidden = true
        progressView.progressTintColor = UIColor(named: "SpotGreen")
        progressView.progress = 0.0
        view.addSubview(progressView)

        self.getDocuments()

        resultsView = UITableView(frame: CGRect(x: 0, y: 85, width: UIScreen.main.bounds.width, height: 0))
        resultsView.backgroundColor = UIColor(named: "SpotBlack")
        resultsView.separatorStyle = .none
        resultsView.dataSource = self
        resultsView.delegate = self
        resultsView.register(resultsCell.self, forCellReuseIdentifier: "resultsCell")
        resultsView.isHidden = true
        view.addSubview(resultsView)
    }

    func getDocuments() {
        listener1 = self.db.collection("users").document(self.uid).addSnapshotListener { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {

                self.profilePicURL = snapshot?.get("imageURL") as! String
                self.friendsListRaw = snapshot?.get("friendsList") as! [String]
                self.getFriends()
                // Check if User does not have a profile image saved
                if self.profilePicURL == "" {
                    // insert stock picture
                    print("stock")
                } else {
                    let gsReference = Storage.storage().reference(forURL: self.profilePicURL)

                    // Extract image and put it into ProfileIcon
                    gsReference.getData(maxSize: 1 * 2_048 * 2_048) {
                        data, error in
                        if error != nil {
                            print("error occured")
                        } else {
                            let profImage = UIImage(data: data!)
                            self.posterProfile.image = profImage
                            self.view.addSubview(self.posterProfile)
                        }
                    }
                }

            }
        }
        self.listener4 = self.db.collection("spots").document(self.spotObject.id).addSnapshotListener { (spotSnap, err) in
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                self.privacy = (spotSnap?.get("privacyLevel") as! String)

                let privacyMessage = UILabel(frame: CGRect(x: CGFloat(24), y: UIScreen.main.bounds.height - 120, width: UIScreen.main.bounds.width - 48, height: CGFloat(30)))
                privacyMessage.textColor = UIColor(red: 0.71, green: 0.71, blue: 0.71, alpha: 1.0)
                privacyMessage.textAlignment = .left
                privacyMessage.numberOfLines = 0
                privacyMessage.font = UIFont(name: "SFCamera-Regular", size: 14)
                self.view.addSubview(privacyMessage)

                self.imageURL = spotSnap?.get("imageURL") as! String
                if self.spotObject.name == "Add post" {
                    self.spotObject.name = spotSnap?.get("spotName") as! String
                    self.navigationItem.title = self.spotObject.name
                } else {
                    self.navigationItem.title = self.spotObject.name
                }

                switch self.privacy {
                case "public":
                    privacyMessage.text = "Your post will be visible to those who check in here and your friends"
                case "invite":
                    privacyMessage.text = "Your post will only be visible to those invited to the spot"

                    self.inviteList = spotSnap?.get("inviteList") as! [String]
                default:
                    privacyMessage.text = "Your post will be visible to those who check in here and your friends"
                }
                privacyMessage.sizeToFit()

                let arrayLocation = spotSnap?.get("l") as! [NSNumber]

                self.spotLat = arrayLocation[0] as! Double
                self.spotLong = arrayLocation[1] as! Double
                self.city = spotSnap?.get("city") as? String ?? ""
            }
        }
    }
    func getFriends() {
        for friend in self.friendsListRaw {
            self.db.collection("users").document(friend).addSnapshotListener { (snap, err) in
                if err != nil {
                    return
                } else {
                    if let name = snap!.get("name") as? String {
                        let username = snap!.get("username") as! String
                        self.friendsList.append((uid: friend, username: username, name: name))
                    }
                }
            }
        }
    }
    func addPostButton() {
        let add = UIImage(named: "PostButton")?.withRenderingMode(UIImage.RenderingMode.alwaysOriginal)
        self.postBtn = UIBarButtonItem(image: add, style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.handleCreatePost))
        self.navigationItem.rightBarButtonItem = postBtn
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(false)
        if self.postBtn != nil {
            self.postBtn.isEnabled = true
        }
        self.navigationItem.backBarButtonItem?.title = ""
    }
   /*
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
        if self.isMovingFromParent {
            self.removeListeners()
            if let spotVC = self.parent as? SpotViewController {
                if spotVC.drawer {
                    var offset: CGFloat = 60
                    if spotVC.largeScreen { offset = 85 }
                    spotVC.view.frame = CGRect(x: 0, y: offset, width: self.view.frame.width, height: self.view.frame.height)
                }
            }
        }
    }
    */

    @objc func handleCreatePost(_sender: AnyObject) {
        self.view.endEditing(true)

        self.navigationController?.navigationBar.isUserInteractionEnabled = false
      //  self.tabBarController?.tabBar.isUserInteractionEnabled = false

        errorTextLayer.isHidden = true
        errorBox.isHidden = true
        progressView.isHidden = false

        self.progressView.setProgress(0.1, animated: true)

        if gifMode {
            saveGIF(images: self.selectedImages)
        } else if imageFromCamera != nil && imageFromCamera != UIImage() {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else { return }
                SpotPhotoAlbum.sharedInstance.save(image: self.imageFromCamera)
            }
        }

        self.postBtn.isEnabled = false
        postID = UUID().uuidString
        var caption = ""
        if self.descriptionTextField.text != nil && self.descriptionTextField.text != "Write a caption..." {
            caption = self.descriptionTextField.text
        } else {
            caption = ""
        }
        let posterID = self.uid

        while caption.last?.isNewline ?? false {
            caption = String(caption.dropLast())
        }

        let word = descriptionTextField.text.split(separator: " ")

        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = friendsList.first(where: { $0.username == username }) {
                    self.selectedUsers.append(f)
                }
            }
        }

        let selectedUsernames = self.selectedUsers.map({ $0.username })

        // Get the time that the post was created
        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
        let likersList: [String] = []

        let values = ["caption": caption,
                      "posterID": posterID,
                      "timestamp": time,
                      "likers": likersList,
                      "imageURL": "",
                      "taggedUsers": selectedUsernames
            ] as [String: Any]

        // saveLocally(values: values)

        self.db.collection("spots").document(self.spotObject.id).collection("feedPost").document(postID).setData(values, merge: true)

        firstCommentID = UUID().uuidString
        self.db.collection("spots").document(spotObject.id).collection("feedPost").document(postID).collection("Comments").document(firstCommentID).setData(["commenterID": uid, "comment": caption, "timestamp": time, "taggedUsers": selectedUsernames], merge: true)

        self.progressView.setProgress(0.3, animated: true)

        self.listener2 = self.db.collection("users").document(self.uid).addSnapshotListener { (snapshot, userErr) in

            let username = snapshot?.get("username") as! String
            self.profilePicURL = snapshot?.get("imageURL") as! String

            var posts: [String] = []

            self.listener3 = self.db.collection("users").document(self.uid).collection("spotsList").addSnapshotListener { (spots, _) in

                for documents in spots!.documents {
                    if documents.documentID == self.spotObject.id {
                        self.checkedInBefore = true
                        posts = documents.get("postsList") as? [String] ?? []
                    }
                }
                if self.checkedInBefore {
                    self.db.collection("users").document(self.uid).collection("spotsList").document(self.spotObject.id).updateData(["postsList": posts])
                } else {
                    let timestamp = NSDate().timeIntervalSince1970
                    let myTimeInterval = TimeInterval(timestamp)
                    let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
                    self.db.collection("users").document(self.uid).collection("spotsList").document(self.spotObject.id).setData(["spotID": self.spotObject.id, "postsList": posts, "checkInTime": time], merge: true)

                    let spotRef = self.db.collection("spots").document(self.spotObject.id)

                    self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                        let spotDoc: DocumentSnapshot
                        do {
                            try spotDoc = transaction.getDocument(spotRef)
                        } catch let fetchError as NSError {
                            errorPointer?.pointee = fetchError
                            return nil
                        }

                        var visitorList: [String] = []
                        visitorList = spotDoc.data()?["visitorList"] as! [String]
                        visitorList.append(self.uid)
                        transaction.updateData([
                            "visitorList": visitorList
                        ], forDocument: spotRef)

                        return nil

                    }) { (_, error) in
                        if let error = error {
                            print("Transaction failed: \(error)")
                        } else {
                            print("Transaction successfully committed!")
                        }
                    }
                    self.checkedInNow = true

                }
                /// patch fix for uploadPostImage running twice
                if self.delegateObject.spotID == "" {
                    var commentList: [Comment] = []
                    commentList.append(Comment(commentID: self.firstCommentID, commenterID: self.uid, comment: caption, time: Int64(timestamp), date: time as Date, taggedFriends: [""], commentHeight: 0))

                    self.delegateObject = FeedPost(spotname: "", spotID: self.spotObject.id, posterID: self.uid, founderID: self.spotObject.founder, captionText: caption, captionHeight: 0, imageURL: [""], photo: self.selectedImages, uNameString: username, profilePic: self.posterProfile.image!, likers: likersList, wasLiked: false, location: "", spotLat: self.spotLat, spotLong: self.spotLat, time: Int64(timestamp), date: time as Date, postID: self.postID, commentList: commentList, imageHeight: self.imageHeight, isFirst: false, seen: false, friends: true, selectedImageIndex: 0, privacyLevel: self.privacy, taggedFriends: selectedUsernames, GIF: self.gifMode)

                    self.uploadPostImage(self.selectedImages, postId: self.postID, postValues: values) { error in
                        if error != nil {
                            print("error")
                        }

                        return
                    }
                } else {
                    return
                }
            }
        }
    }

    func saveLocally(values: [String: Any]) {

        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }

        let managedContext =
            appDelegate.persistentContainer.viewContext

        let postObject = PostDraft(context: managedContext)
        var imageObjects: [(ImageModel)] = []

        var index: Int16 = 0
        for image in self.selectedImages {
            let im = ImageModel(context: managedContext)
            im.imageData = image.jpegData(compressionQuality: 0.7)
            im.position = index
            imageObjects.append(im)
            index += 1
        }

        postObject.caption = values["caption"] as? String ?? ""
        postObject.city = self.city
        postObject.createdBy = spotObject.founder
        postObject.images = NSSet(array: imageObjects)

        postObject.inviteList = self.inviteList
        postObject.spotLat = self.spotLat
        postObject.spotLong = self.spotLong
        postObject.spotID = self.spotObject.id
        postObject.spotName = self.spotObject.name
        postObject.privacyLevel = privacy
        let tagged = values["taggedUsers"] as? [String] ?? []
        postObject.taggedUsers = tagged
        postObject.gif = self.gifMode
        postObject.uid = self.uid

        let timestamp = NSDate().timeIntervalSince1970
        let seconds = Int64(timestamp)

        postObject.timestamp = seconds

        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    func uploadToPosts(values: [String: Any]) {
        var newValues = values
        newValues["privacyLevel"] = privacy
        newValues["spotName"] = spotObject.name
        newValues["spotID"] = spotObject.id
        newValues["isFirst"] = false
        newValues["createdBy"] = spotObject.founder
        newValues["inviteList"] = inviteList
        newValues["spotLat"] = self.spotLat
        newValues["spotLong"] = self.spotLong
        newValues["city"] = self.city

        self.db.collection("posts").document(postID!).setData(newValues)
        self.db.collection("posts").document(postID!).collection("comments").document(firstCommentID).setData(["commenterID": uid, "comment": newValues["caption"] as Any, "timestamp": newValues["timestamp"] as Any, "taggedUsers": newValues["taggedUsers"] as Any], merge: true)

    }

    func sendNotification(receiverID: String, postID: String, imageURL: String, type: String) {

        let timestamp = NSDate().timeIntervalSince1970
        let myTimeInterval = TimeInterval(timestamp)
        let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))

        let notificationRef = self.db.collection("users").document(receiverID).collection("notifications")
        let acceptRef = notificationRef.document(self.notiID)

        var notiValues = ["seen": false, "timestamp": time, "senderID": self.uid, "type": "post", "spotID": self.spotObject.id, "postID": postID, "imageURL": imageURL, "spotName": self.spotObject.name] as [String: Any]
        if type == "postTag" {
            notiValues.updateValue("postTag", forKey: "type")
        }
        acceptRef.setData(notiValues)

        let sender = PushNotificationSender()
        var token: String!
        var senderName: String!

        self.db.collection("users").document(receiverID).getDocument { (tokenSnap, err) in
            if tokenSnap == nil {
                return
            } else {
                token = tokenSnap?.get("notificationToken") as? String
            }
            self.db.collection("users").document(self.uid).getDocument { (userSnap, _) in
                if userSnap == nil {
                    return
                } else {
                    senderName = userSnap?.get("username") as? String
                    if token != nil && token != "" {
                        if type == "postTag" {
                            sender.sendPushNotification(token: token, title: "", body: "\(senderName ?? "someone") tagged you in a post")
                        } else {
                            sender.sendPushNotification(token: token, title: "", body: "\(senderName ?? "someone") posted at \(self.spotObject.name)")
                        }
                    }
                }
            }

        }
    }

    func uploadPostImage(_ images: [UIImage], postId: String, postValues: [String: Any], completion: @escaping ((_ url: String?) -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            if self.progressView.progress != 1.0 {
                self.shouldUploadPost = false
                self.saveLocally(values: postValues)
                self.triggerDestruct(postID: postId)
            } else {
                return
            }
        }
        var index = 0
        var URLs: [String] = []

        let imageCount = images.count
        var progress = 0.7 / Double(imageCount)
        for _ in images {
            URLs.append("")
        }
        for image in images {
            let imageId = UUID().uuidString
            let storageRef = Storage.storage().reference().child("spotPics-dev").child("\(imageId)")

            guard var imageData = image.jpegData(compressionQuality: 0.7) else {return}

            if imageData.count > 1_000_000 {
                imageData = image.jpegData(compressionQuality: 0.3)!
            }

            var urlStr: String = ""
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            storageRef.putData(imageData, metadata: metadata) {metadata, error in

                if error == nil, metadata != nil {
                    // get download url
                    storageRef.downloadURL(completion: { url, error in
                        if let error = error {
                            print("\(error.localizedDescription)")
                        }
                        // url
                        if !self.shouldUploadPost {
                            return
                        }
                        self.progressView.setProgress(Float(0.3 + progress), animated: true)

                        urlStr = (url?.absoluteString)!

                        let i = images.lastIndex(where: { $0 == image })
                        URLs[i ?? 0] = urlStr

                        index = index + 1
                        progress = progress * Double(index + 1)

                        if index == imageCount {

                            var values: [String: Any] = [:]

                            switch imageCount {
                            case 1:
                                values = ["imageURL": URLs[0]]
                            case 2:
                                values = ["imageURL": URLs[0], "imageURL1": URLs[1]]
                            case 3:
                                values = ["imageURL": URLs[0], "imageURL1": URLs[1], "imageURL2": URLs[2]]
                            case 4:
                                values = ["imageURL": URLs[0], "imageURL1": URLs[1], "imageURL2": URLs[2], "imageURL3": URLs[3]]
                            case 5:
                                values = ["imageURL": URLs[0], "imageURL1": URLs[1], "imageURL2": URLs[2], "imageURL3": URLs[3], "imageURL4": URLs[4]]
                            default:
                                self.triggerDestruct(postID: postId)
                            }
                            values.updateValue(self.gifMode, forKey: "gif")

                            var newPostValues = postValues
                            newPostValues.updateValue(self.gifMode, forKey: "gif")
                            newPostValues.updateValue(URLs, forKey: "imageURLs")
                            self.uploadToPosts(values: newPostValues)

                            if self.privacy == "invite" {
                                for invite in self.inviteList {
                                    if invite != self.uid {
                                        print("sent notification")
                                        self.sendNotification(receiverID: invite, postID: postId, imageURL: urlStr, type: "newPost")
                                    }
                                }
                            } else if self.uid != self.spotObject.founder {
                                self.sendNotification(receiverID: self.spotObject.founder, postID: postId, imageURL: urlStr, type: "newPost")
                            }

                            if !self.selectedUsers.isEmpty {
                                self.db.collection("users").document(self.spotObject.founder).getDocument { (fSnap, _) in
                                    if let founderFriends = fSnap?.get("friendsList") as? [String] {
                                        for user in self.selectedUsers {
                                            if founderFriends.contains(user.uid) || self.privacy == "public"{
                                                if user.uid != self.spotObject.founder {
                                                    self.sendNotification(receiverID: user.uid, postID: postId, imageURL: urlStr, type: "spotTag")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            self.selectedUsers.removeAll()
                            self.db.collection("spots").document(self.spotObject.id).collection("feedPost").document(postId).setData(values, merge: true)

                            self.navigationController?.navigationBar.isUserInteractionEnabled = true
                     //       self.tabBarController?.tabBar.isUserInteractionEnabled = true

                            let draft = self.draftID == nil

                            if self.passedImages {
                                // add spot flow
                                let infoPass = ["postID": postId, "spotID": self.spotObject.id] as [String: Any]
                                NotificationCenter.default.post(name: self.newPostNotificationName, object: nil, userInfo: infoPass)

                                if self.checkedInNow {
                                    let infoPass = ["spotID": self.spotObject.id] as [String: Any]
                                    NotificationCenter.default.post(name: self.checkInNotificationName, object: nil, userInfo: infoPass)
                                }

                                let storyboard = UIStoryboard(name: "SpotPage", bundle: nil)
                                let root = self.navigationController?.viewControllers[0]
                                self.navigationController?.popToViewController(root!, animated: false)
                                let vc = storyboard.instantiateViewController(withIdentifier: "SpotPage") as! SpotViewController
                           //     vc.spotLat = self.spotLat
                            //    vc.spotLong = self.spotLat
                                vc.spotID = self.spotObject.id
                             //   vc.friendsListRaw = self.friendsListRaw
                              //  vc.privacyLevel = self.privacy

                                vc.navigationItem.backBarButtonItem?.title = ""
                                root?.navigationController?.pushViewController(vc, animated: true)
                                if self.draftID != nil {self.deleteDraft(id: self.draftID)}
                            } else {
                                // create post flow
                                let controllers = self.navigationController?.viewControllers
                                var spotVC: SpotViewController!
                                var drawer = false
                                var map: MapViewController!
                                if self.navigationController?.viewControllers[controllers!.count - 4].children.count != 0 {
                                    if let s = self.navigationController?.viewControllers[controllers!.count - 4].children[0] as? SpotViewController {
                                        spotVC = s
                               //         self.delegate = spotVC
                                        drawer = true
                                        map = self.navigationController?.viewControllers[controllers!.count - 4] as? MapViewController
                                    }
                                } else if let vc = self.navigationController?.viewControllers[controllers!.count - 4] as? SpotViewController {
                                    spotVC = vc
                                 //   self.delegate = spotVC
                                } else if let vc = self.navigationController?.viewControllers[controllers!.count - 5] as? SpotViewController {
                                    spotVC = vc
                                 //   self.delegate = spotVC
                                }
                                self.delegate?.FinishPassing(post: self.delegateObject)
                                let infoPass = ["postID": postId, "spotID": self.spotObject.id] as [String: Any]
                                NotificationCenter.default.post(name: self.newPostNotificationName, object: nil, userInfo: infoPass)
                                if self.checkedInNow {
                                    let infoPass = ["spotID": self.spotObject.id] as [String: Any]
                                    NotificationCenter.default.post(name: self.checkInNotificationName, object: nil, userInfo: infoPass)
                                    completion(nil)
                                }
                                if drawer {
                                    self.navigationController?.popToViewController(map, animated: false)
                                } else {
                                    if spotVC == nil {
                                        self.navigationController?.popToRootViewController(animated: false)
                                    } else {
                                        self.navigationController?.popToViewController(spotVC, animated: false)
                                    }
                                }
                                if self.draftID != nil {self.deleteDraft(id: self.draftID)}
                            }
                        }
                    })

                } else {
                    completion(nil)
                }
            }

        }
    }

    func removeListeners() {
        print("listeners removed")
        if self.listener1 != nil {
            self.listener1.remove()
        }
        if self.listener2 != nil {
            self.listener2.remove()
        }
        if self.listener3 != nil {
            self.listener3.remove()
        }
        if self.listener4 != nil {
            self.listener4.remove()
        }
    }

    func deleteDraft(id: Int64) {
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        let managedContext =
            appDelegate.persistentContainer.viewContext
        let fetchRequest =
            NSFetchRequest<ImagesArray>(entityName: "ImagesArray")
        fetchRequest.predicate = NSPredicate(format: "id == %d", id)
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

    @objc func notifyNewPost (_ notification: Notification) {
        print("notification posted in create")
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.alpha < 0.7 {
            //    let cursorPosition = textView.cursor
            textView.text = nil
            let newPosition = textView.beginningOfDocument
            textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            // textView.updateFloatingCursor(at: CGPoint(x: 8.0, y: 15.0))
            textView.alpha = 1.0
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Write a caption..."
            textView.alpha = 0.65
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let amountOfLinesToBeShown: CGFloat = 8
        let maxHeight: CGFloat = textView.font!.lineHeight * amountOfLinesToBeShown

        var size = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: maxHeight))
        if size.height > maxHeight {
            while size.height > maxHeight {
                textView.text = String(textView.text.dropLast())
                size = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: maxHeight))
            }
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: maxHeight)
        } else if size.height > 70 {
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: size.height)
        } else {
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: 70)
        }

        if textView.text.last != " " {
            if let word = textView.text?.split(separator: " ").last {
                if word.hasPrefix("@") {
                    resultsView.isHidden = false
                    runQuery(searchText: String(word.lowercased().dropFirst()))
                } else {
                    resultsView.isHidden = true
                }
            } else {
                resultsView.isHidden = true
            }
        } else {
            resultsView.isHidden = true
        }
    }

    func runQuery(searchText: String) {
        queryObject.removeAll()

        var index = 0

        for friend in self.friendsList {
            if String(friend.username.prefix(searchText.count)) == searchText {
                self.queryObject.append((name: friend.name, username: friend.username))
            } else if String(friend.name.prefix(searchText.count)) == searchText {
                self.queryObject.append((name: friend.name, username: friend.username))
            } else if String(friend.name.lowercased().prefix(searchText.count)) == searchText {
                self.queryObject.append((name: friend.name, username: friend.username))
            }
            index = index + 1

            if index == self.friendsList.count {
                queryObject.append((name: friend.name, username: friend.username))
                self.queried = true
                self.resultsView.reloadData()
            }
        }

    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        let currentText = textView.text ?? ""

        guard let stringRange = Range(range, in: currentText) else { return false }

        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)

        if textView.accessibilityHint == "caption" {
            return updatedText.count <= 560
        } else {
            return true
        }
    }

    func setImageViewBounds() {

        if self.previousImageView != nil {
            self.previousImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3)
        }

        if self.selectedImageView != nil {
            self.selectedImageView.frame = CGRect(x: 15, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3)
        }

        if self.nextImageView != nil {
            self.nextImageView.frame = CGRect(x: 15 + UIScreen.main.bounds.width, y: constantHeight, width: UIScreen.main.bounds.width - 30, height: UIScreen.main.bounds.height * 1 / 3)
        }

    }

    @objc func imageSwipe(_ gesture: UIGestureRecognizer) {
        if let swipe = gesture as? UIPanGestureRecognizer {
            let direction = swipe.velocity(in: view)
            let translation = swipe.translation(in: self.view)

            if abs(translation.y) > abs(translation.x) {
                return
            }

            if direction.x < 0 && translation.x > 0 || direction.x > 0 && translation.x < 0 {
            }

            if direction.x < 0 || translation.x < 0 {
                if self.selectedImageIndex != self.selectedImages.count - 1 {

                    let frame0 = CGRect(x: 15 + translation.x, y: constantHeight, width: selectedImageView.frame.width, height: selectedImageView.frame.height)

                    selectedImageView.frame = frame0

                    let frame1 = CGRect(x: selectedImageView.frame.minX + 30 + selectedImageView.frame.width, y: constantHeight, width: nextImageView.frame.width, height: nextImageView.frame.height)
                    nextImageView.frame = frame1

                    if swipe.state == .ended {

                        if frame1.minX + direction.x < UIScreen.main.bounds.width / 2 {
                            UIView.animate(withDuration: 0.2, animations: { (self.nextImageView.frame = CGRect(x: 15, y: self.constantHeight, width: self.nextImageView.frame.width, height: self.nextImageView.frame.height))
                                self.selectedImageView.frame = CGRect(x: -(15 + UIScreen.main.bounds.width), y: self.constantHeight, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                            })

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {

                                self.selectedImageIndex = self.selectedImageIndex + 1
                                self.setUpDotView(count: self.selectedImages.count)

                                self.selectedImageView.image = self.selectedImages[self.selectedImageIndex]

                                self.previousImageView.image = self.selectedImages[self.selectedImageIndex - 1]
                                self.selectedImageView.roundCornersForAspectFit(radius: 8)
                                self.previousImageView.roundCornersForAspectFit(radius: 8)

                                self.setImageViewBounds()

                                if self.selectedImageIndex != self.selectedImages.count - 1 {

                                    self.nextImageView.image = self.selectedImages[self.selectedImageIndex + 1]
                                    self.nextImageView.roundCornersForAspectFit(radius: 8)

                                }

                            }

                        } else {
                            print("not less than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })

                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                            //    self.tableView.reloadData()
                        }
                    }
                } else {

                    let frame0 = CGRect(x: 0 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0

                    if swipe.state == .ended {
                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            } else {
                if self.selectedImageIndex != 0 {

                    let frame0 = CGRect(x: 15 + translation.x, y: constantHeight, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0

                    let frame1 = CGRect(x: self.selectedImageView.frame.minX - self.selectedImageView.frame.width - 30, y: constantHeight, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height)
                    self.previousImageView.frame = frame1

                    if swipe.state == .ended {
                        if frame1.maxX + direction.x > UIScreen.main.bounds.width / 2 {
                            print("greater than")
                            UIView.animate(withDuration: 0.2, animations: { (self.previousImageView.frame = CGRect(x: 15, y: self.constantHeight, width: self.previousImageView.frame.width, height: self.previousImageView.frame.height))

                                self.selectedImageView.frame = CGRect(x: UIScreen.main.bounds.width + 15, y: self.constantHeight, width: self.selectedImageView.bounds.width, height: self.selectedImageView.bounds.height)
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.selectedImageIndex = self.selectedImageIndex - 1
                                self.setUpDotView(count: self.selectedImages.count)

                                self.selectedImageView.image = self.selectedImages[self.selectedImageIndex]

                                self.nextImageView.image = self.selectedImages[self.selectedImageIndex + 1]

                                self.selectedImageView.roundCornersForAspectFit(radius: 8)

                                self.nextImageView.roundCornersForAspectFit(radius: 8)

                                self.setImageViewBounds()

                                if self.selectedImageIndex != 0 {
                                    self.previousImageView.image = self.selectedImages[self.selectedImageIndex - 1]
                                    self.previousImageView.roundCornersForAspectFit(radius: 8)

                                }

                            }
                        } else {
                            print("not greater than")
                            UIView.animate(withDuration: 0.2, animations: { self.setImageViewBounds()
                            })

                            //    self.selectedImageIndex = self.selectedImageIndex + 1
                        }

                    }
                } else {

                    let frame0 = CGRect(x: 15 + translation.x, y: self.selectedImageView.frame.minY, width: self.selectedImageView.frame.width, height: self.selectedImageView.frame.height)
                    self.selectedImageView.frame = frame0

                    if swipe.state == .ended {

                        UIView.animate(withDuration: 0.2, animations: {
                            self.setImageViewBounds()
                        })
                    }
                }
            }
        }
    }

    @objc func notifyCheckIn (_ notification: Notification) {
        print("check in first post noti posted")
    }

    func setUpDotView(count: Int) {
        if self.selectedImages.count < 2 { return }
        if dotView != nil {self.dotView.removeFromSuperview()}
        let dotY = self.selectedImageView.frame.maxY + 5
        dotView = UIView(frame: CGRect(x: 0, y: dotY, width: UIScreen.main.bounds.width, height: 10))
        dotView.backgroundColor = nil
        self.view.addSubview(dotView)

        var i = 1.0
        var xOffset = CGFloat(3.5 + (Double(count - 1) * 5.5))
        while i <= Double(count) {
            let view = UIImageView(frame: CGRect(x: UIScreen.main.bounds.width / 2 - xOffset, y: 0, width: 7, height: 7))
            view.layer.cornerRadius = 3.5

            if i == Double(self.selectedImageIndex + 1) {
                view.image = UIImage(named: "ElipsesFilled")
            } else {
                view.image = UIImage(named: "ElipsesUnfilled")
            }
            dotView.addSubview(view)

            i = i + 1.0
            xOffset = xOffset - 11
        }
    }

    /* func animateGIF(directionUp: Bool, counter: Int) {
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
     
     UIView.animate(withDuration: 0.08, delay: 0.0, options: .transitionCrossDissolve, animations: {
     self.selectedImageView.image = self.selectedImages[newCount]
     })
     
     DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
     self.animateGIF(directionUp: newDirection, counter: newCount)
     }
     } */

    func triggerDestruct(postID: String) {
        let postRef = self.db.collection("spots").document(self.spotObject.id).collection("feedPost").document(postID)
        postRef.collection("Comments").getDocuments { (commentsnapshot, _) in
            for comment in commentsnapshot!.documents {

                postRef.collection("Comments").document(comment.documentID).delete()
                postRef.delete()
                let ref = self.db.collection("users").document(self.uid).collection("spotsList").document(self.spotObject.id)
                self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                    let spotDoc: DocumentSnapshot
                    do {
                        try spotDoc = transaction.getDocument(ref)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }

                    var postsList: [String] = []
                    postsList = spotDoc.data()?["postsList"] as! [String]
                    var counter = 0
                    for post in postsList {
                        if post == postID {
                            postsList.remove(at: counter)
                        }
                        counter = counter + 1
                    }

                    transaction.updateData([
                        "postsList": postsList
                    ], forDocument: ref)

                    return nil

                }) { (_, error) in
                    if let error = error {
                        print("Transaction failed: \(error)")
                    } else {
                        print("Transaction successfully committed!")
                    }
                }

                let alert = UIAlertController(title: "Upload failed", message: "Post saved to your drafts", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                    switch action.style {
                    case .default:
                        return
                    case .cancel:
                        return
                    case .destructive:
                        return
                    @unknown default:
                        fatalError()
                    }}))
                self.navigationController?.navigationBar.isUserInteractionEnabled = true
         //       self.tabBarController?.tabBar.isUserInteractionEnabled = true

                self.navigationController?.popToRootViewController(animated: false)
                self.present(alert, animated: true, completion: nil)

                return
            }

        }
    }
}

extension CreatePostViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if queried {

            let cellHeight = CGFloat(self.queryObject.count * 45)
            var offset: CGFloat = 60
            if largeScreen { offset = 85 }

            var minY: CGFloat = 0
            var height: CGFloat = 0

            if cellHeight > self.descriptionTextField.frame.minY - offset - 5 {
                minY = offset
                height = self.descriptionTextField.frame.minY - offset - 5
            } else {
                minY = self.descriptionTextField.frame.minY - 5 - cellHeight
                height = cellHeight
            }
            self.resultsView.frame = CGRect(x: 0, y: minY, width: self.resultsView.frame.width, height: height)

            return self.queryObject.count
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "resultsCell", for: indexPath) as! resultsCell
        if self.queried {
            if !self.queryObject.isEmpty {
                cell.setUp()

                cell.nameLabel.text = queryObject[indexPath.row].name
                cell.nameLabel.sizeToFit()
                cell.usernameLabel.text = queryObject[indexPath.row].username
                cell.usernameLabel.sizeToFit()
                //   cell.prepareForReuse()
                return cell
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! resultsCell
        let username = cell.usernameLabel.text
        if let word = self.descriptionTextField.text?.split(separator: " ").last {
            if word.hasPrefix("@") {
                var text = String(self.descriptionTextField.text.dropLast(word.count - 1))
                text.append(contentsOf: username ?? "")
                self.self.descriptionTextField.text = text
                self.resultsView.isHidden = true
            }
        }
    }

}
