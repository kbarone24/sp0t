//
//  GuestbookViewController.swift
//  Spot
//
//  Created by kbarone on 4/21/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//
/*
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import CoreLocation

class GuestbookViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CreatePostDelegate {
    
    
    func FinishPassing(post: Post) {
        //check to make sure there isn't an active listener that already grabbed the post
        if !self.postsList.contains(where: {$0.postID == post.postID}) {
            postsList.insert(post, at: 0)
        }
        if !self.postIDs.contains(post.postID) {
            postIDs.append(post.postID)
        }
        tableView.reloadData()
    }
    
    private let refreshControl = UIRefreshControl()
    private var activityIndicatorView: CustomActivityIndicator!
    var refreshActivityIndicator: CustomActivityIndicator!
    
    @IBOutlet weak var tableView: UITableView!
    var spotID : String?
    
    let db = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var postsList : [Post] = [];
    var index : Int = 0;
    var postIDs : [String] = []
    var postButton: UIButton!
    var offset: CGFloat = 200
    
    var dataFetched = false
    
    let postNotificationName = Notification.Name("postDelete")
    let feedPostNotificationName = Notification.Name("feedPostDelete")
    
    var deletedPostID = ""
    var spotName = ""
    var spotFounder = ""
    var documentCount = 0
    
    var sendToGuestbook = false
    var notificationPostID = ""
    
    var start: CFAbsoluteTime!
    
    var listener1, listener2, listener3, listener4, listener5, listener6: ListenerRegistration!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        start = CFAbsoluteTimeGetCurrent()
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: postNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyFeedPostDelete(_:)), name: feedPostNotificationName, object: nil)
        
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        
        activityIndicatorView = CustomActivityIndicator(frame: CGRect(x: 0, y: UIScreen.main.bounds.minX + 30, width: UIScreen.main.bounds.width, height: 40))
        tableView.addSubview(activityIndicatorView)
        
        self.activityIndicatorView.startAnimating()
        
        refreshControl.backgroundColor = nil
        refreshControl.tintColor = .clear
        
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
        
        refreshActivityIndicator = CustomActivityIndicator(frame: .zero)
        tableView.addSubview(refreshControl)
        
        refreshTableData()
        
        if (UIScreen.main.nativeBounds.height > 2400 || UIScreen.main.nativeBounds.height == 1792) {
            postButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 193, width: 30, height: 30))
            tableView.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 100, right: 0)
        } else {
            postButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 145, width: 30, height: 30))
            tableView.contentInset = UIEdgeInsets(top: 40, left: 0, bottom: 60, right: 0)
        }
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(false)
    }
    
    @objc func createPost(_ sender:UIButton) {
        self.performSegue(withIdentifier: "postToCreatePost", sender: self )
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "postToCreatePost"{
            if let vc = segue.destination as? CreatePostViewController{
                vc.spotID = self.spotID
                vc.spotName = self.spotName
                vc.spotFounder = self.spotFounder
                vc.delegate = self
            }
        }
    }
    
    func loadSpots(currentspot : String) {
        
        
        self.listener1 = self.db.collection("spots").document(currentspot).addSnapshotListener { (spotSnapshot, spotsErr) in
            
            if (spotsErr != nil) {
                print("Error getting documents")
                
            } else {
                
                self.db.collection("spots").document(currentspot).collection("feedPost").order(by: "timestamp", descending: false).getDocuments { (querysnapshot, err) in
                    
                    self.documentCount = querysnapshot!.documents.count
                    print(self.documentCount)
                    for document in querysnapshot!.documents {
                        
                        var isFirst = false
                        if (document.documentID == querysnapshot!.documents[0].documentID) {
                            isFirst = true
                        }
                        
                        let postID = document.documentID
                        
                        if (self.postIDs.contains(postID)) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                                self.refreshActivityIndicator.stopAnimating()
                                self.refreshControl.endRefreshing()
                            })
                            continue
                        } else if self.deletedPostID == postID {
                            continue
                        }
                        
                        self.postIDs.append(postID)
                        self.spotFounder = (spotSnapshot?.get("createdBy") as? String)!
                        self.spotName = (spotSnapshot?.get("spotName") as? String)!
                        
                        //wait to add post button until we have the spot name and spot founder
                        let image = UIImage(named: "AddSpotIcon")
                        self.postButton.setImage((image), for: UIControl.State.normal)
                        self.postButton.isUserInteractionEnabled = true
                        self.postButton.addTarget(self, action: #selector(self.createPost(_:)), for: .touchUpInside)
                        self.postButton.sizeToFit()
                        self.view.addSubview(self.postButton)
                        
                        
                        let captionText : String = document.get("caption") as! String
                        let imgURL : String = document.get("imageURL") as? String ?? "gs://sp0t-app.appspot.com/spotPics-dev/D543B8F5-3741-4F2E-8C05-1825367E40E0"
                        
                        let imgReference = Storage.storage().reference(forURL: imgURL)
                        
                        var rawTimeStamp = Timestamp()
                        rawTimeStamp = document.get("timestamp") as! Timestamp
                        let seconds = rawTimeStamp.seconds
                        let date = rawTimeStamp.dateValue()
                        
                        let posterID : String = document.get("posterID") as! String
                        guard let likers : [String] = document.get("likers") as? [String] else {
                            return }
                        var wasLiked = false
                        if (likers.contains(self.uid)) {
                            wasLiked = true
                        }
                        
                        var commentsArray = [Comment]()
                        
                        self.listener2 = self.db.collection("spots").document(currentspot).collection("feedPost").document(postID).collection("Comments").addSnapshotListener { (querysnapshot, err) in
                            for docs in querysnapshot!.documents {
                                let commentID = docs.documentID
                                let commenterID = docs.get("commenterID") as! String
                                let comment = docs.get("comment") as! String
                                let commentTime = docs.get("timestamp") as! Timestamp
                                let commentSeconds = commentTime.seconds
                                let commentDate = commentTime.dateValue()
                                let newComment = Comment(commentID: commentID, commenterID: commenterID, comment: comment, time: commentSeconds, date: commentDate)
                                
                                if (!commentsArray.contains(where: {$0.time == commentSeconds})) {
                                    commentsArray.append(newComment)
                                }
                            }
                            
                            self.listener3 = self.db.collection("users").document(posterID).addSnapshotListener { (posterSnapshot, posterErr) in
                                
                                let posterUserName : String = posterSnapshot?.get("username") as! String
                                let profilePicURL : String = posterSnapshot?.get("imageURL") as! String
                                
                                var profileImgRef = StorageReference()
                                profileImgRef = Storage.storage().reference(forURL: profilePicURL)
                                
                                let arrayLocation = spotSnapshot?.get("l") as! [NSNumber]
                                
                                let spotLatitude : Double = arrayLocation[0] as! Double
                                let spotLongitude : Double = arrayLocation[1] as! Double
                                
                                let tempPost = (Post(spotname: self.spotName, spotID: currentspot, posterID: posterID, founderID: self.spotFounder, captionText: captionText, imageURL: [imgURL], photo: [UIImage()], uNameString: posterUserName, profilePic: UIImage(), likers: likers, wasLiked: wasLiked, location: "", spotLat: spotLatitude, spotLong: spotLongitude, time: seconds, date: date, postID: postID, commentList : commentsArray, imageHeight: 0, isFirst: isFirst))
                                
                                self.getPostImages(post: tempPost, profileRef: profileImgRef, postRef: imgReference)
                                
                            } // End get image data
                            
                        }
                        
                    }
                    
                }
            } // End loop through all feed post documents
            
        } // End get collection of all feed post documents
    } //End get nearby spot
    
    func getPostImages(post: Post, profileRef: StorageReference, postRef: StorageReference) {
        var profileImage = UIImage()
        
        if profileRef != nil {
            profileRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
                if error != nil {
                    print("error occured")
                } else {
                    profileImage = UIImage(data: data!)!
                    
                    if postRef != nil {
                        postRef.getData(maxSize: 1 * 2048 * 2048) { data, error in
                            if error != nil {
                                print("error occured")
                            } else {
                                let image = UIImage(data: data!)!
                                let imView = UIImageView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 500))
                                imView.image = image
                                imView.contentMode = .scaleAspectFill
                                let aspect = image.size.height / image.size.width
                                var imageHeight = 0
                                
                                let trueHeight = UIScreen.main.bounds.width * aspect
                                if (trueHeight > UIScreen.main.bounds.height * 2/3) {
                                    imageHeight = Int(UIScreen.main.bounds.height * 2/3)
                                } else {
                                    imageHeight = Int(trueHeight)
                                }
                                
                                let newPost = post
                                newPost.imageHeight = imageHeight
                                newPost.profilePic = profileImage
                                newPost.photo.append(image)
                                
                                let dup = self.postsList.contains(where: {$0.postID == newPost.postID})
                                var reloader = true
                                if (!dup) {
                                    print("caption of dup", newPost.caption)
                                    self.postsList.append(newPost)
                                    reloader = true
                                } else {
                                    let post = self.postsList.first(where: {$0.postID == newPost.postID})!
                                    if post.commentList.count != newPost.commentList.count {
                                        print("comments not equal")
                                        if (newPost.commentList.count != 0) {
                                            print("comments not 0")
                                            post.commentList = newPost.commentList
                                            reloader = true
                                        }
                                    }
                                    if post.likers.count != newPost.likers.count {
                                        post.likers = newPost.likers
                                        post.wasLiked = newPost.wasLiked
                                        reloader = true
                                    }
                                }
                                if reloader {
                                    
                                    if self.postsList.count == self.documentCount {
                                        self.dataFetched = true
                                        self.removeListeners()
                                        
                                        self.postsList = self.postsList.sorted(by: { $0.time > $1.time})
                                        
                                        self.tableView.reloadData()
                                        self.removeRefresh()
                                        
                                        if (self.sendToGuestbook) {
                                            var index = 0
                                            for post in self.postsList {
                                                if post.postID == self.notificationPostID {
                                                    let match = self.postsList.remove(at: index)
                                                    self.postsList.insert(match, at: 0)
                                                    self.tableView.reloadData()
                                                    self.refreshControl.endRefreshing()
                                                    self.activityIndicatorView.stopAnimating()
                                                }
                                                index = index + 1
                                                if self.postsList.count == self.postIDs.count {
                                                    self.removeListeners()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        let image = UIImage()
                        
                        let newPost = post
                        newPost.imageHeight = 200
                        newPost.profilePic = profileImage
                        newPost.photo = [image]
                        self.removeRefresh()
                        let dup = self.postsList.contains(where: {$0.postID == newPost.postID})
                        var reloader = true
                        if (!dup) {
                            print("caption of dup", newPost.caption)
                            self.postsList.append(newPost)
                            reloader = true
                        } else {
                            let post = self.postsList.first(where: {$0.postID == newPost.postID})!
                            if post.commentList.count != newPost.commentList.count {
                                print("comments not equal")
                                if (newPost.commentList.count != 0) {
                                    print("comments not 0")
                                    post.commentList = newPost.commentList
                                    reloader = true
                                }
                            }
                            if post.likers.count != newPost.likers.count {
                                post.likers = newPost.likers
                                post.wasLiked = newPost.wasLiked
                                reloader = true
                            }
                        }
                        if reloader {
                            
                            if self.postsList.count == self.documentCount {
                                self.dataFetched = true
                                self.removeListeners()
                                
                                self.postsList = self.postsList.sorted(by: { $0.time > $1.time})
                                
                                self.tableView.reloadData()
                                self.removeRefresh()
                                
                                if (self.sendToGuestbook) {
                                    var index = 0
                                    for post in self.postsList {
                                        if post.postID == self.notificationPostID {
                                            let match = self.postsList.remove(at: index)
                                            self.postsList.insert(match, at: 0)
                                            self.tableView.reloadData()
                                            self.refreshControl.endRefreshing()
                                            self.activityIndicatorView.stopAnimating()
                                        }
                                        index = index + 1
                                        if self.postsList.count == self.postIDs.count {
                                            self.removeListeners()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    func removeRefresh() {
        if (self.refreshActivityIndicator.isAnimating()) { self.refreshActivityIndicator.stopAnimating() }
        if (self.activityIndicatorView.isAnimating()) { self.activityIndicatorView.stopAnimating() }
        if (self.refreshControl.isRefreshing) {self.refreshControl.endRefreshing()}
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (dataFetched) {
            print("data fetched")
            print(postsList.count)
            return postsList.count
        } else { return 0 }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (dataFetched) {
            return CGFloat(postsList[indexPath.row].imageHeight + 200)
        } else { return 0}
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 700
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "GuestbookCell", for: indexPath) as! GuestbookCell
        
        //get rid of old values on reuse
        cell.setUpAll(post: postsList[indexPath.row])
        
        cell.imageTap.tag = indexPath.row
        cell.imageTap.addTarget(self, action: #selector(imageTapped(_:event:)), for: .touchDownRepeat)
        
        cell.profilePicButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        cell.profilePicButton.tag = indexPath.row
        
        cell.handleDisplay.tag = indexPath.row
        cell.handleDisplay.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        
        if cell.showMoreButton != nil {
            cell.showMoreButton.tag = indexPath.row
            cell.showMoreButton.addTarget(self, action: #selector(showMoreTapped(_:)), for: .touchUpInside)
        }
        
        cell.likeButton.tag = indexPath.row
        cell.likeButton.addTarget(self, action: #selector(likeTapped(_:)), for: .touchUpInside)
        
        cell.numComments.tag = indexPath.row
        cell.numComments.addTarget(self, action: #selector(commentsTapped(_:)), for: .touchUpInside)
        
        if cell.more != nil {
            cell.more.addTarget(self, action: #selector(moreTapped(_:)), for: UIControl.Event.touchUpInside)
        }
        
        return cell
        
    }
    
    @objc private func refreshData(_ sender: Any) {
        
        refreshActivityIndicator = CustomActivityIndicator(frame: CGRect(x: 6, y: refreshControl.bounds.minY + 15, width: UIScreen.main.bounds.width - 20, height: refreshControl.bounds.height - 20))
        refreshActivityIndicator?.translatesAutoresizingMaskIntoConstraints = false
        refreshActivityIndicator.backgroundColor = nil
        
        self.refreshControl.addSubview(refreshActivityIndicator)
        
        self.refreshActivityIndicator.startAnimating()
        
        self.refreshTableData()
        
        refreshTableData()
    }
    
    private func refreshTableData() {
        DispatchQueue.main.async {
            self.loadSpots(currentspot: self.spotID!)
        }
    }
    
    func removeListeners() {
        if self.listener1 != nil {
            self.listener1.remove()
        }
        if self.listener2 != nil {
            self.listener2.remove()
        }
        if self.listener3 != nil {
            self.listener3.remove()
        }
        
    }
    
    @objc func usernameTap(_ sender:UIButton){
        Analytics.logEvent("guestbookUsernameTap", parameters: nil)
        
        let row = sender.tag
        let clickedID = self.postsList[row].posterID
        if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(withIdentifier: "ProfileMain") as? ProfileViewController {
            vc.id = clickedID
            vc.navigationItem.backBarButtonItem?.title = ""
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    
    
    @objc func moreTapped(_ sender:UIButton){
        Analytics.logEvent("guestbookElipsesTap", parameters: nil)
        
        let moreView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2 - 130, y: offset + 200, width: 261, height: 85))
        moreView.backgroundColor = UIColor(red:0.07, green:0.07, blue:0.07, alpha:1.0)
        moreView.layer.cornerRadius = 24
        moreView.accessibilityIdentifier = "moreView"
        let tag = sender.tag
        
        
        let maskView = UIButton(frame: CGRect(x: 0, y: offset - 200, width: tableView.bounds.width, height: tableView.bounds.height + 200))
        maskView.tag = tag
        maskView.accessibilityIdentifier = "maskView"
        maskView.backgroundColor = UIColor(white: 0, alpha: 0.6)
        maskView.isUserInteractionEnabled = false
        maskView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // maskView.addTarget(self, action: #selector(maskTapped(_:)), for: .touchUpInside)
        //   maskView.addTarget(self, action: #selector(maskTapped(_:)), for: .touchDragInside)
        
        tableView.addSubview(maskView)
        tableView.addSubview(moreView)
        tableView.bringSubviewToFront(moreView)
        
        tableView.isScrollEnabled = false
        
        let exitButton = UIButton(frame: CGRect(x: moreView.bounds.width - 35, y: 10, width: 20, height: 20))
        exitButton.backgroundColor = nil
        exitButton.isUserInteractionEnabled = true
        exitButton.setImage(UIImage(named: "cancel"), for: UIControl.State.normal)
        exitButton.tag = tag
        exitButton.addTarget(self, action: #selector(exitMoreTapped(_:)), for: .touchUpInside)
        moreView.addSubview(exitButton)
        
        let deleteButton = UIButton(frame: CGRect(x: 52, y: 20, width: 156, height: 47))
        deleteButton.setImage(UIImage(named: "DeletePostButton"), for: UIControl.State.normal)
        deleteButton.backgroundColor = nil
        deleteButton.tag = tag
        deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
        moreView.addSubview(deleteButton)
        
    }
    @objc func exitMoreTapped(_ sender:UIButton) {
        let views = tableView.subviews
        for sub in views {
            if sub.accessibilityIdentifier == "moreView" {
                sub.removeFromSuperview()
            }
            if sub.accessibilityIdentifier == "maskView" {
                sub.removeFromSuperview()
            }
        }
        tableView.isScrollEnabled = true
    }
    
    @objc func deleteTapped(_ sender:UIButton) {
        Analytics.logEvent("guestbookDeleteTap", parameters: nil)
        
        if self.postsList[sender.tag].posterID != self.uid { return }

        let alert = UIAlertController(title: "Delete Post?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
            switch action.style{
            case .default:
                
                let views = self.tableView.subviews
                for sub in views {
                    if sub.accessibilityIdentifier == "moreView" {
                        sub.removeFromSuperview()
                    }
                    if sub.accessibilityIdentifier == "maskView" {
                        sub.removeFromSuperview()
                    }
                }
                self.tableView.isScrollEnabled = true
                
            case .cancel:
                print("cancel")
            case .destructive:
                print("destruct")
            @unknown default:
                fatalError()
            }}))
        alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { action in
            switch action.style{
            case .default:
                
                self.deletedPostID = self.postsList[sender.tag].postID
                
                let postNotiRef = self.db.collection("users").document(self.postsList[sender.tag].posterID).collection("notifications")
                let query = postNotiRef.whereField("postID", isEqualTo: self.postsList[sender.tag].postID)
                query.getDocuments { (querysnapshot, err) in
                    for doc in querysnapshot!.documents {
                        doc.reference.delete()
                    }
                }
                
                let spotNotiRef = self.db.collection("users").document(self.postsList[sender.tag].founderID).collection("notifications")
                let spotQuery = spotNotiRef.whereField("postID", isEqualTo: self.postsList[sender.tag].postID)
                spotQuery.getDocuments { (querysnapshot, err) in
                    for doc in querysnapshot!.documents {
                        doc.reference.delete()
                    }
                }
                
                
                
                
                let tempSpotID = self.postsList[sender.tag].spotID
                let tempPostID = self.postsList[sender.tag].postID
                self.postsList.remove(at: sender.tag)
                self.postIDs.remove(at: sender.tag)
                self.tableView.reloadData()
                let postRef = self.db.collection("spots").document(tempSpotID).collection("feedPost").document(tempPostID)
                
                postRef.collection("Comments").getDocuments { (querysnapshot, err) in
                    for doc in querysnapshot!.documents {
                        postRef.collection("Comments").document(doc.documentID).delete()
                    }
                    postRef.delete()
                    
                    //remove from user's post list
                    let ref = self.db.collection("users").document(self.uid).collection("spotsList").document(tempSpotID)
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
                            if post == tempPostID {
                                postsList.remove(at: counter)
                            }
                            counter = counter + 1
                        }
                        
                        transaction.updateData([
                            "postsList": postsList
                        ], forDocument: ref)
                        
                        
                        /*    let notificationRef = self.db.collection("users").document(self.postsList[row].posterID).collection("notifications")
                         let query = notificationRef.whereField("type", isEqualTo: "like").whereField("postID", isEqualTo: self.postsList[row].postID).whereField("senderID", isEqualTo: self.uid)
                         query.getDocuments { (querysnapshot, err) in
                         for doc in querysnapshot!.documents {
                         doc.reference.delete()
                         }
                         } */
                        
                        return nil
                        
                    }) { (object, error) in
                        if let error = error {
                            print("Transaction failed: \(error)")
                        } else {
                            print("Transaction successfully committed!")
                        }
                    }
                }
                
                let views = self.tableView.subviews
                for sub in views {
                    if sub.accessibilityIdentifier == "moreView" {
                        sub.removeFromSuperview()
                    }
                    if sub.accessibilityIdentifier == "maskView" {
                        sub.removeFromSuperview()
                    }
                }
                self.tableView.isScrollEnabled = true
                
                let infoPass = ["postID": tempPostID] as [String : Any]
                
                NotificationCenter.default.post(name: self.postNotificationName, object: nil, userInfo: infoPass)
                
            case .cancel:
                print("cancel")
            case .destructive:
                print("destruct")
            @unknown default:
                fatalError()
            }}))
        
        
        self.present(alert, animated: true, completion: nil)
        
    }
    @objc func notifyPostDelete (_ notification:Notification) {
        if let dict = notification.userInfo as? [String: String] {
            let id = dict.first?.value
            self.deletedPostID = id!
        }
    }
    
    @objc func notifyFeedPostDelete (_ notification:Notification) {
        Analytics.logEvent("guestbookFeedPostDeleteNotification", parameters: nil)
        
        if let dict = notification.userInfo as? [String: String] {
            let id = dict.first?.value
            var index = 0
            for post in postsList {
                if post.postID == id {
                    self.deletedPostID = post.postID
                    postsList.remove(at: index)
                }
                index = index + 1
            }
            tableView.reloadData()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        offset = tableView.contentOffset.y
    }
    
    
    
    @objc func imageTapped(_ sender:UIButton, event: UIEvent) {
        let row = sender.tag
        let touch: UITouch = event.allTouches!.first!
        if (touch.tapCount == 2) {
            if(postsList[row].wasLiked){
            } else {
                Analytics.logEvent("guestbookDoubleTap", parameters: nil)
                postsList[row].likers.append(self.uid)
                postsList[row].wasLiked = true
                self.tableView.reloadData()
                DispatchQueue.main.async {
                    self.db.collection("spots").document(self.postsList[row].spotID).collection("feedPost").document(self.postsList[row].postID).updateData([
                        "likers" : self.postsList[row].likers
                    ])
                }
                if (postsList[row].posterID != self.uid) {
                    let timestamp = NSDate().timeIntervalSince1970
                    let myTimeInterval = TimeInterval(timestamp)
                    let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
                    
                    let notiID = UUID().uuidString
                    let notificationRef =   self.db.collection("users").document(self.postsList[row].posterID).collection("notifications")
                    let acceptRef = notificationRef.document(notiID)
                    
                    
                    acceptRef.setData(["seen" : false, "timestamp" : time, "senderID": self.uid, "type": "like", "spotID": postsList[row].spotID, "postID": postsList[row].postID, "imageURL": postsList[row].imageURL])
                    
                    let sender = PushNotificationSender()
                    var token: String!
                    var senderName: String!
                    
                    self.db.collection("users").document(self.postsList[row].posterID).getDocument { (tokenSnap, err) in
                        if (tokenSnap == nil) {
                            return
                        } else {
                            token = tokenSnap?.get("notificationToken") as? String
                        }
                        self.db.collection("users").document(self.uid).getDocument { (userSnap, err) in
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
        }
    }
    
    @objc func likeTapped(_ sender:UIButton){
        let row = sender.tag
        if(postsList[row].wasLiked){
            var count =  0
            for likes in postsList[row].likers {
                if likes == self.uid {
                    
                    Analytics.logEvent("guestbookLikeRemoved", parameters: nil)
                    postsList[row].likers.remove(at: count)
                }
                count = count + 1
            }
            postsList[row].wasLiked = false
            tableView.reloadData()
            let ref = db.collection("spots").document(self.postsList[row].spotID).collection("feedPost").document(self.postsList[row].postID)
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                let myDoc: DocumentSnapshot
                do {
                    try myDoc = transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                
                var likers: [String] = []
                
                likers = myDoc.data()?["likers"] as! [String]
                if (likers.contains(self.uid)) {
                    likers.removeAll(where: {$0 == self.uid})
                    transaction.updateData([
                        "likers": likers
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
            
            
            let notificationRef = self.db.collection("users").document(self.postsList[row].posterID).collection("notifications")
            let query = notificationRef.whereField("type", isEqualTo: "like").whereField("postID", isEqualTo: self.postsList[row].postID).whereField("senderID", isEqualTo: self.uid)
            query.getDocuments { (querysnapshot, err) in
                for doc in querysnapshot!.documents {
                    doc.reference.delete()
                }
            }
            
        } else {
            Analytics.logEvent("guestbookLikeTap", parameters: nil)
            
            postsList[row].likers.append(self.uid)
            postsList[row].wasLiked = true
            tableView.reloadData()
            let ref = db.collection("spots").document(self.postsList[row].spotID).collection("feedPost").document(self.postsList[row].postID)
            
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                let myDoc: DocumentSnapshot
                do {
                    try myDoc = transaction.getDocument(ref)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                
                var likers: [String] = []
                
                likers = myDoc.data()?["likers"] as! [String]
                if (!likers.contains(self.uid)) {
                    likers.append(self.uid)
                    transaction.updateData([
                        "likers": likers
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
            
            
            if (postsList[row].posterID != self.uid) {
                
                let timestamp = NSDate().timeIntervalSince1970
                let myTimeInterval = TimeInterval(timestamp)
                let time = NSDate(timeIntervalSince1970: TimeInterval(myTimeInterval))
                
                let notiID = UUID().uuidString
                let notificationRef = self.db.collection("users").document(self.postsList[row].posterID).collection("notifications")
                let acceptRef = notificationRef.document(notiID)
                
                
                acceptRef.setData(["seen" : false, "timestamp" : time, "senderID": self.uid, "type": "like", "spotID": postsList[row].spotID, "postID": postsList[row].postID, "imageURL": postsList[row].imageURL])
                
                let sender = PushNotificationSender()
                var token: String!
                var senderName: String!
                
                self.db.collection("users").document(self.postsList[row].posterID).getDocument { (tokenSnap, err) in
                    if (tokenSnap == nil) {
                        return
                    } else {
                        token = tokenSnap?.get("notificationToken") as? String
                    }
                    self.db.collection("users").document(self.uid).getDocument { (userSnap, err) in
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
    }
    
    
    @objc func showMoreTapped(_ sender:UIButton) {
        Analytics.logEvent("guestbookShowMoreCaptionTap", parameters: nil)
        
        let row = sender.tag
        
        if let vc = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(withIdentifier: "CommentStoryboard") as? CommentsViewController {
            vc.commentList = self.postsList[row].commentList
            vc.posterID = postsList[row].posterID
            vc.spotID = postsList[row].spotID
            vc.postID = postsList[row].postID
            vc.spotImageURL = postsList[row].imageURL[0]
            vc.row = row
            vc.vc = "SpotFeed"
            vc.navigationItem.backBarButtonItem?.title = ""
            self.navigationController!.pushViewController(vc, animated: true)
        }
    }
    @objc func commentsTapped(_ sender:UIButton){
        Analytics.logEvent("guestbookCommentsTap", parameters: nil)
        
        print("comment tap")
        let row = sender.tag
        
        if let vc = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(withIdentifier: "CommentStoryboard") as? CommentsViewController {
            vc.commentList = self.postsList[row].commentList
            vc.posterID = postsList[row].posterID
            vc.spotID = postsList[row].spotID
            vc.postID = postsList[row].postID
            vc.spotImageURL = postsList[row].imageURL[0]
            vc.row = row
            vc.vc = "SpotFeed"
            vc.navigationItem.backBarButtonItem?.title = ""
            self.navigationController!.pushViewController(vc, animated: true)
        }
        
    }
    func getLinesArrayOfString(in label: UILabel) -> [String] {
        
        /// An empty string's array
        var linesArray = [String]()
        
        guard let text = label.text, let font = label.font else {return linesArray}
        
        let rect = label.frame
        
        let myFont: CTFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        let attStr = NSMutableAttributedString(string: text)
        attStr.addAttribute(kCTFontAttributeName as NSAttributedString.Key, value: myFont, range: NSRange(location: 0, length: attStr.length))
        
        let frameSetter: CTFramesetter = CTFramesetterCreateWithAttributedString(attStr as CFAttributedString)
        let path: CGMutablePath = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: rect.size.width, height: 100000), transform: .identity)
        
        let frame: CTFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
        guard let lines = CTFrameGetLines(frame) as? [Any] else {return linesArray}
        
        for line in lines {
            let lineRef = line as! CTLine
            let lineRange: CFRange = CTLineGetStringRange(lineRef)
            let range = NSRange(location: lineRange.location, length: lineRange.length)
            let lineString: String = (text as NSString).substring(with: range)
            linesArray.append(lineString)
        }
        return linesArray
    }
}
class GuestbookCell: UITableViewCell {
    var dateTimestamp: UILabel!
    var postImage: UIImageView!
    var posterProfile: UIImageView!
    var profilePicButton: UIButton!
    var handleDisplay: UIButton!
    var captionLayer: UILabel!
    var numLikes: UILabel!
    var upArrow: UIImageView!
    var imageTap: UIButton!
    var showMoreButton: UIButton!
    var likeButton: UIButton!
    var numComments: UIButton!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid ID"
    var more: UIButton!
    
    func setUpAll (post: Post) {
        self.backgroundColor = UIColor(named: "SpotBlack")
        
        self.subviews.forEach({$0.removeFromSuperview()})
        
        //Display the username of the user that created the post
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.17
        
        dateTimestamp = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 100, y: 42, width: 88, height: 13))
        dateTimestamp.lineBreakMode = .byTruncatingTail
        dateTimestamp.numberOfLines = 0
        dateTimestamp.textColor = UIColor.lightGray
        dateTimestamp.textAlignment = .right
        let rawDate = post.date
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.setLocalizedDateFormatFromTemplate("M/d/y")
        dateTimestamp.text = dateFormatter.string(from: rawDate)
        dateTimestamp.font = UIFont(name: "SFCamera-Semibold", size: 13)!
        //    dateTimestamp.sizeToFit()
        self.addSubview(dateTimestamp)
        
        
        //Show the image associated with the post
        var constantHeight = CGFloat(post.imageHeight)
        
        postImage = UIImageView(frame: CGRect(x: 0, y: 65, width: UIScreen.main.bounds.width, height: constantHeight))
        postImage.image = post.photo[0]
        postImage.contentMode = UIView.ContentMode.scaleAspectFill
        postImage.clipsToBounds = true
        
        imageTap = UIButton(frame: CGRect(x: 0, y: 60, width: UIScreen.main.bounds.width, height: constantHeight + 20))
        imageTap.isUserInteractionEnabled = true
        imageTap.backgroundColor = UIColor.clear
        imageTap.tintColor = .clear
        
        self.addSubview(imageTap)
        self.insertSubview(postImage, at: 0)
        
        constantHeight = constantHeight + 70
        
        posterProfile = UIImageView(frame: CGRect(x: 10, y: constantHeight + 6, width: 36, height: 36))
        posterProfile.image = post.profilePic
        posterProfile.layer.masksToBounds = false
        posterProfile.layer.cornerRadius = posterProfile.frame.height/2
        posterProfile.clipsToBounds = true
        posterProfile.contentMode = UIView.ContentMode.scaleAspectFill
        self.insertSubview(posterProfile, at: 0)
        
        profilePicButton = UIButton(frame: CGRect(x: 4, y: constantHeight + 3, width: 44, height: 46))
        profilePicButton.backgroundColor = .clear
        profilePicButton.isUserInteractionEnabled = true
        self.addSubview(profilePicButton)
        
        //Display the username in front of the caption
        handleDisplay = UIButton(frame: CGRect(x: 54, y: constantHeight + 10, width: UIScreen.main.bounds.width - 105, height: 12))
        handleDisplay.setTitle(post.uName, for: UIControl.State.normal)
        handleDisplay.setTitleColor(UIColor(red:0.82, green:0.82, blue:0.82, alpha:1), for: UIControl.State.normal)
        handleDisplay.titleLabel?.font =  UIFont(name: "SFCamera-Semibold", size: 14)
        handleDisplay.contentHorizontalAlignment = .left
        
        let handleTitle = NSAttributedString(string: (handleDisplay.titleLabel?.text)!, attributes: [NSAttributedString.Key.kern: 0.5])
        
        handleDisplay.setAttributedTitle(handleTitle, for: .normal)
        handleDisplay.isUserInteractionEnabled = true
        self.addSubview(handleDisplay)
        
        
        constantHeight = constantHeight + 30
        captionLayer = UILabel(frame: CGRect(x: 54, y: constantHeight - 4, width: UIScreen.main.bounds.width - 100, height: 45))
        captionLayer.lineBreakMode = .byWordWrapping
        captionLayer.textColor = UIColor.white
        let captionContent = post.caption
        var full = true
        
        captionLayer.font = UIFont(name: "SFCamera-regular", size: 13)!
        captionLayer.text = captionContent
        
        let dupLabel = UILabel(frame: captionLayer.frame)
        let tempLabel = UILabel(frame: (captionLayer.frame))
        
        dupLabel.text = captionContent
        dupLabel.font = UIFont(name: "SFCamera-regular", size: 13)!
        dupLabel.numberOfLines = 4
        
        var frame0 = dupLabel.frame;
        dupLabel.sizeToFit()
        frame0.size.height = dupLabel.frame.size.height;
        dupLabel.frame = frame0;
        
        captionLayer.numberOfLines = 3
        
        var frame = captionLayer.frame;
        captionLayer.sizeToFit()
        frame.size.height = captionLayer.frame.size.height;
        captionLayer.frame = frame;
        
        var thirdLineWidth : CGFloat = 0
        
        //if caption is >3 lines add the "more" button
        if captionLayer.frame.height < dupLabel.frame.height {
            
            let lines : [String] = getLinesArrayOfString(in: captionLayer)
            let text = lines[2]
            
            tempLabel.numberOfLines = 1
            tempLabel.text = text
            tempLabel.font = UIFont(name: "SFCamera-regular", size: 13)!
            
            tempLabel.sizeToFit()
            
            thirdLineWidth = tempLabel.frame.width
            full = false
        }
        
        captionLayer.isUserInteractionEnabled = true
        self.addSubview(captionLayer)
        
        if (!full) {
            showMoreButton = UIButton(frame: CGRect(x: thirdLineWidth + 52, y: constantHeight + captionLayer.bounds.height - 20.5, width: 50, height: 20))
            showMoreButton.setTitle("...more", for: UIControl.State.normal)
            showMoreButton.setTitleColor(UIColor.lightGray, for: UIControl.State.normal)
            showMoreButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 13)!
            showMoreButton.isUserInteractionEnabled = true
            showMoreButton.clipsToBounds = true
            self.addSubview(showMoreButton)
        }
        
        
        //Display number of likes
        numLikes = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 27, y: constantHeight - 20, width: 15, height: 13))
        numLikes.lineBreakMode = .byWordWrapping
        numLikes.numberOfLines = 0
        numLikes.textColor = UIColor(red:0.02, green:0.62, blue:1, alpha:1)
        numLikes.textAlignment = .center
        let num = post.likers.count
        numLikes.text = String(num)
        numLikes.font = UIFont(name: "Menlo-Bold", size: 13)!
        
        if num >= 10 {
            let frame = CGRect(x: numLikes.frame.minX - 3.4, y: numLikes.frame.minY, width: numLikes.frame.width + 10, height: numLikes.frame.height)
            numLikes.frame = frame
        } else if num >= 20 {
            let frame = CGRect(x: numLikes.frame.minX - 4.1, y: numLikes.frame.minY, width: numLikes.frame.width + 11, height: numLikes.frame.height)
            numLikes.frame = frame
        }
        numLikes.sizeToFit()
        numLikes.isUserInteractionEnabled = true
        self.addSubview(numLikes)
        
        //like button
        let upArrow = UIImage(named: "UpArrow") as UIImage?
        
        likeButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 35, y: constantHeight - 5, width: 25, height: 25))
        likeButton.backgroundColor = UIColor(named: "SpotBlack")
        
        if(post.wasLiked){
            likeButton.setImage(UIImage.init(named: "UpArrowFilled"), for: UIControl.State.normal)
        } else {
            likeButton.setImage(upArrow, for: UIControl.State.normal)
        }
        likeButton.contentEdgeInsets = UIEdgeInsets(top: 4.5, left: 4.5, bottom: 4.5, right: 4.5)
        likeButton.isUserInteractionEnabled = true
        self.addSubview(likeButton)
        
        
        constantHeight = constantHeight + captionLayer.bounds.height
        //Display number of comments
        numComments = UIButton(frame: CGRect(x: 54, y: constantHeight - 3, width: 341, height: 14))
        let commentsCount = post.commentList.count
        var commentsContent = ""
        if (commentsCount <= 1) {
            commentsContent = ("0 comments")
        }
        else if (commentsCount == 2) {
            commentsContent = ("1 comment")
        } else {
            commentsContent = ("\(commentsCount - 1) comments")
        }
        numComments.setTitle(commentsContent, for: UIControl.State.normal)
        numComments.setTitleColor(UIColor.lightGray, for: UIControl.State.normal)
        numComments.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12)
        numComments.sizeToFit()
        numComments.isUserInteractionEnabled = true
        self.addSubview(numComments)
        
        
        constantHeight = constantHeight + 15
        
        if (post.posterID == self.uid) {
            if(!post.isFirst) {
                more = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 10, y: constantHeight, width: 25, height: 15))
                more.backgroundColor = nil
                more.setImage(UIImage(named: "more"), for: UIControl.State.normal)
                more.isUserInteractionEnabled = true
                self.addSubview(more)
            }
        }
        
        self.selectionStyle = UITableViewCell.SelectionStyle.none
    }
    
    override func prepareForReuse() {
        if dateTimestamp != nil {dateTimestamp.isHidden = true}
        if postImage != nil {postImage.isHidden = true}
        if posterProfile != nil {posterProfile.isHidden = true}
        if profilePicButton != nil {profilePicButton.isHidden = true}
        if handleDisplay != nil {handleDisplay.isHidden = true}
        if captionLayer != nil {captionLayer.isHidden = true}
        if numLikes != nil {numLikes.isHidden = true}
        if upArrow != nil {upArrow.isHidden = true}
        if imageTap != nil {imageTap.isHidden = true}
        if showMoreButton != nil {showMoreButton.isHidden = true}
        if likeButton != nil {likeButton.isHidden = true}
        if numComments != nil {numComments.isHidden = true}
    }
    
    func getLinesArrayOfString(in label: UILabel) -> [String] {
        
        /// An empty string's array
        var linesArray = [String]()
        
        guard let text = label.text, let font = label.font else {return linesArray}
        
        let rect = label.frame
        
        let myFont: CTFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        let attStr = NSMutableAttributedString(string: text)
        attStr.addAttribute(kCTFontAttributeName as NSAttributedString.Key, value: myFont, range: NSRange(location: 0, length: attStr.length))
        
        let frameSetter: CTFramesetter = CTFramesetterCreateWithAttributedString(attStr as CFAttributedString)
        let path: CGMutablePath = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: rect.size.width, height: 100000), transform: .identity)
        
        let frame: CTFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, nil)
        guard let lines = CTFrameGetLines(frame) as? [Any] else {return linesArray}
        
        for line in lines {
            let lineRef = line as! CTLine
            let lineRange: CFRange = CTLineGetStringRange(lineRef)
            let range = NSRange(location: lineRange.location, length: lineRange.length)
            let lineString: String = (text as NSString).substring(with: range)
            linesArray.append(lineString)
        }
        return linesArray
    }
}
*/
