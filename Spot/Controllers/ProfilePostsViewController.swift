//  ProfileFriendsViewController.swift
//  Spot
//
//  Created by kbarone on 6/27/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Photos
import CoreLocation
import MapKit
import FirebaseUI
import Mixpanel

class ProfilePostsViewController: UIViewController {
    
    unowned var mapVC: MapViewController!
    weak var profileVC: ProfileViewController!
    weak var postVC: PostViewController!
    
    lazy var postsIndicator = CustomActivityIndicator()
    lazy var postsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var postsLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    var docIndex = 0 /// global docIndex variable to account for addPostToMap func
    lazy var postsList: [MapPost] = []
    lazy var postAnnotations: [CustomPointAnnotation] = []
    
    var listener1, listener2: ListenerRegistration!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()

    var active = false
    var loaded = false /// when loaded enables scroll
    var emptyView: UIView!
    
    deinit {
        print("deinit posts")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        setUpPostsCollection()
        DispatchQueue.global(qos: .userInitiated).async { self.getPosts(refresh: false) }
        
   //     NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostTap(_:)), name: NSNotification.Name("PostTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditPost(_:)), name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if active {
            mapVC.postsList.removeAll()
            active = false
        }
        
        removeDownloads()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if profileVC.children.contains(where: {$0 is PostViewController}) { return }
        if profileVC.status == .friends { resetView() }
        Mixpanel.mainInstance().track(event: "ProfilePostsOpen")
    }
    
    @objc func notifyPostTap(_ sender: NSNotification) {
        if let info = sender.userInfo as? [String: Any] {
            if let id = info.first?.value as? String {
                if let index = self.postsList.firstIndex(where: {$0.id == id}) {
                    self.openPostAt(row: index)
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {

            postsList.insert(newPost, at: 0)
            postsCollection.reloadData()
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: newPost.postLat, longitude: newPost.postLong)
            annotation.postID = newPost.id!
            postAnnotations.append(annotation)
        }
    }
    
    @objc func notifyEditPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            // edit post from postsVC
            if let index = postsList.firstIndex(where: {$0.id == newPost.id}) {
                postsList[index] = newPost
                postsCollection.reloadData()
            }
        } else if let info = sender.userInfo as? [String: Any] {
            // spot level info changed
            guard let postID = info["postID"] as? String else { return }
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                postsList[index].spotName = info["spotName"] as? String ?? ""
                postsList[index].inviteList = info["inviteList"] as? [String] ?? []
                postsList[index].spotLat = info["spotLat"] as? Double ?? 0.0
                postsList[index].spotLong = info["spotLong"] as? Double ?? 0.0
                postsList[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                postsCollection.reloadData()
            }
        }
    }
        
    @objc func notifyDeletePost(_ sender: NSNotification) {
        
        var indexPaths: [IndexPath] = []

        if let postIDs = sender.userInfo?.first?.value as? [String] {
            
            if postVC != nil {
                /// seperate loop for postvc postslist just in case it doesnt match the feeds postslist during reload
                for id in postIDs {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == id}) {
                        indexPaths.append(IndexPath(row: index, section: 0))
                    }
                }
            }
            
            /// looping through these twice kind of sucks but i dont know how to account for the indexes changing upon removing a post
            for id in postIDs {
                if let index = self.postsList.firstIndex(where: {$0.id == id}) {
                    print("remove post", id)
                    postsList.remove(at: index)
                    postsList.sort(by: {$0.seconds > $1.seconds})
                    postsCollection.reloadData()
                }
                
                if let aIndex = postAnnotations.firstIndex(where: {$0.postID == id}) {
                    postAnnotations.remove(at: aIndex)
                }
            }
            
            
            if postVC != nil {

                /// avoid double refresh
                postVC.postsList = postsList
                mapVC.postsList = postsList

                postVC.tableView.beginUpdates()
                postVC.tableView.deleteRows(at: indexPaths, with: .bottom)
                postVC.tableView.endUpdates()

                if postVC.selectedPostIndex >= postVC.postsList.count {
                    if postVC.postsList.count == 0 { postVC.exitPosts(); return }
                    postVC.selectedPostIndex = max(0, postVC.postsList.count - 1)
                    postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: true)
                    postVC.tableView.reloadData()
                }

                let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.profile] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
            }
        }
    }

    
    @objc func notifyWillEnterForeground(_ notification: NSNotification) {
        resumeIndicatorAnimation()
    }

    func removeDownloads() {
        for cell in postsCollection.visibleCells {
            guard let guestbookCell = cell as? GuestbookCell else { return }
            guestbookCell.imagePreview.sd_cancelCurrentImageLoad()
        }
    }
    
    func resumeIndicatorAnimation() {
        if !postsIndicator.isHidden {
            DispatchQueue.main.async { self.postsIndicator.startAnimating() }
        }
    }

    
    func resetView() {
        // reset posts called on initial load and when switching between segs
        active = true
        addAnnotations()
        
        if postsList.isEmpty && mapVC.userInfo.spotScore ?? 0 > 0 {
            resumeIndicatorAnimation()
            
        } else {
            /// call reload in case cell images didn't finish loading
            DispatchQueue.main.async { self.postsCollection.reloadData() }
            checkForNewPosts()
        }
    }
    
    func addAnnotations() {
        
        let annotations = mapVC.mapView.annotations
        mapVC.mapView.removeAnnotations(annotations)
        
        if !postAnnotations.isEmpty {
            mapVC.postsList = self.postsList
            for anno in postAnnotations {
                DispatchQueue.main.async { self.mapVC.mapView.addAnnotation(anno) }
            }
        }
        
        /// reset map after post add
        if profileVC.passedCamera != nil {
            /// passed camera represents where the profile was before entering posts
            mapVC.mapView.setCamera(profileVC.passedCamera, animated: false)
            profileVC.passedCamera = nil
        } else {
            mapVC.animateToProfileLocation(active: uid == profileVC.id, coordinate: CLLocationCoordinate2D())
        }
    }
  
    func setUpPostsCollection() {
        let width = (UIScreen.main.bounds.width - 10.5) / 3
        let height = width * 1.374
        postsLayout.itemSize = CGSize(width: width, height: height)
        postsLayout.minimumInteritemSpacing = 5
        postsLayout.minimumLineSpacing = 5
        postsLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 350, right: 0)
        
        postsCollection.frame = view.frame
        postsCollection.backgroundColor = UIColor(named: "SpotBlack")
        postsCollection.setCollectionViewLayout(postsLayout, animated: true)
        postsCollection.delegate = self
        postsCollection.dataSource = self
        postsCollection.backgroundView = nil
        postsCollection.isScrollEnabled = false
        postsCollection.showsVerticalScrollIndicator = false
        postsCollection.register(GuestbookCell.self, forCellWithReuseIdentifier: "GuestbookCell")
        view.addSubview(postsCollection)
        
        postsIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 15, width: UIScreen.main.bounds.width, height: 30))
        postsCollection.addSubview(postsIndicator)
    }
    
    func checkForNewPosts() {
        DispatchQueue.global().async { self.getPosts(refresh: true) }
    }
        
    func getPosts(refresh: Bool) {
        
        if profileVC == nil { return }
        let query = db.collection("posts").whereField("posterID", isEqualTo: profileVC.id).order(by: "timestamp", descending: true)

        listener1 = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (snap, err) in
            
            guard let self = self else { return }
            if self.profileVC == nil { return }

            guard let docs = snap?.documents else {
                /// add empty state if user got nothing
                if self.profileVC.userInfo == nil { return }
                
                if self.profileVC.userInfo.spotScore == 0 {
                    self.postsIndicator.stopAnimating()
                }
                return
            }
            
            if docs.count == 0 {
                self.postsIndicator.stopAnimating()
                return
            }
                        
            var spotIndex = 0
            
            for doc in docs {
                                
                do {
                    
                    let postInfo = try doc.data(as: MapPost.self)
                    guard var info = postInfo else { self.docIndex += 1; if self.docIndex == docs.count  { self.finishPostsLoad() }; continue }

                    info.seconds = info.timestamp.seconds
                    info.id = doc.documentID
                    
                    //access check
                    /// check user access if the profile isn't from current user, friend check will happen over the top so don't need to check if user is friends with current user
                    if self.uid != self.profileVC.id {
                        if info.createdBy != self.uid && info.privacyLevel == "invite" {
                            if !(info.inviteList?.contains(where: {$0 == self.uid}) ?? false) {
                                self.docIndex += 1; if self.docIndex == docs.count {
                                    self.finishPostsLoad(); continue
                                } else { continue }
                            }
                        }
                    }
                    
                    spotIndex += 1

                    /// animate map to first post location if this isn't the active user
                    if spotIndex == 1 && self.postsList.isEmpty && self.uid != self.profileVC.id {
                        self.profileVC.mapVC.animateToProfileLocation(active: false, coordinate: CLLocationCoordinate2D(latitude: info.postLat, longitude: info.postLong))
                    }
                                        
                    /// set user data -- don't need another listener here because poster is same for all posts
                    info.userInfo = self.profileVC.userInfo
                    
                    var commentList: [MapComment] = []
                    
                    self.listener2 = self.db.collection("posts").document(info.id!).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (commentSnap, err) in
                        
                        guard let self = self else { return }
                        if self.profileVC == nil { return }
                        if err != nil { self.docIndex += 1; if self.docIndex == docs.count { self.finishPostsLoad() }; return }
                        if commentSnap!.documents.count == 0 {
                            self.docIndex += 1; if self.docIndex == docs.count { self.finishPostsLoad() }
                        }
                        
                        for doc in commentSnap!.documents {
                            
                            let lastComment = doc == commentSnap!.documents.last
                            
                            do {
                                
                                let commInfo = try doc.data(as: MapComment.self)
                                guard var commentInfo = commInfo else { if lastComment { info.commentList = commentList; self.loadPostToMap(post: info, docCount: docs.count) }; continue }
                                
                                commentInfo.id = doc.documentID
                                commentInfo.seconds = commentInfo.timestamp.seconds
                                commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)

                                if !commentList.contains(where: {$0.id == doc.documentID}) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: {$0.seconds < $1.seconds})
                                }

                                 if lastComment {
                                     info.commentList = commentList
                                     self.loadPostToMap(post: info, docCount: docs.count)
                                 }
                                
                            } catch {
                                if lastComment {
                                    info.commentList = commentList
                                    self.loadPostToMap(post: info, docCount: docs.count)
                                }
                                continue
                            }
                        }
                    })
                } catch { self.docIndex += 1; if self.docIndex == docs.count { self.finishPostsLoad() }; continue }
            }
        })
    }
    
    func finishPostsLoad() {
        
        loaded = true
        
        /// probably want to do 1 big refresh
        DispatchQueue.main.async {
            
            if self.postsIndicator.isAnimating() { self.postsIndicator.stopAnimating() }
            self.postsCollection.reloadData()
            
            self.postsCollection.performBatchUpdates(nil, completion: {
                (result) in
                
                if self.profileVC == nil { return }
                
                if self.profileVC.selectedIndex == 1 {
                    
                    self.profileVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.profileVC.sec0Height, self.postsCollection.contentSize.height + 65))
                    if self.mapVC.customTabBar.view.frame.minY < 200 { self.profileVC.shadowScroll.isScrollEnabled = true }
                    
                }
            })
        }
    }
    
    func loadPostToMap(post: MapPost, docCount: Int) {
        
        if !postsList.contains(where: {$0.id == post.id}) {

            postsList.append(post)
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            annotation.postID = post.id!
            postAnnotations.append(annotation)
            
            postsList.sort(by: {$0.seconds > $1.seconds})
            self.docIndex += 1; if self.docIndex == docCount { self.finishPostsLoad() }

            if active {
                mapVC.postsList = postsList
                mapVC.mapView.addAnnotation(annotation)
            }
            
        } else {
            /// already contains post - active listener found a change, probably a comment or like
            if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {
                
                if mapVC.deletedPostIDs.contains(post.id ?? "") { return }
                postsList[index] = post
                
                self.docIndex += 1; if self.docIndex == docCount { self.finishPostsLoad() }
                
                if let postVC = profileVC.children.last(where: {$0 is PostViewController}) as? PostViewController {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                        
                        let selectedIndex = postVC.postsList[index].selectedImageIndex
                        self.postsList[index].selectedImageIndex = selectedIndex

                        postVC.postsList[index] = post
                        postVC.postsList[index].selectedImageIndex = selectedIndex
                    }
                    
                    if postVC.tableView != nil && loaded { postVC.tableView.reloadData() }
                }
            }
        }
    }

    func removeListeners() {
        
        if self.listener1 != nil { self.listener1.remove() }
        if self.listener2 != nil { self.listener2.remove() }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostTap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension ProfilePostsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GuestbookCell", for: indexPath) as? GuestbookCell else { return UICollectionViewCell() }
        let post = postsList[indexPath.row]
        cell.setUp(post: post)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        guard let cell = cell as? GuestbookCell else { return }
        guard let post = postsList[safe: indexPath.row] else { return }
        
        /// cached images weren't working + were bringing in the wrong images on reuse
      /*  if cell.cachedImage.postID == post.id! && cell.cachedImage.image != UIImage() {
            cell.imagePreview.image = cell.cachedImage.image
            return
        } */
        
        cell.imagePreview.image = UIImage()

        guard let url = post.imageURLs.first else { return }
        if url == "" { return }
        
        let transformer = SDImageResizingTransformer(size: CGSize(width: 300, height: 300), scaleMode: .aspectFill)
        cell.imagePreview.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { (image, _, _, _) in
            if image != nil { cell.cachedImage.image = image!}
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? GuestbookCell else { return }
        guard let post = postsList[safe: indexPath.row] else { return }
        cell.cachedImage.postID = post.id!
        cell.imagePreview.sd_cancelCurrentImageLoad()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openPostAt(row: indexPath.row)
    }

    func openPostAt(row: Int) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            /// cancel downloads on visible images
            removeDownloads()
            
            vc.postsList = postsList
            vc.selectedPostIndex = row
            vc.mapVC = mapVC
            vc.parentVC = .profile
            
            postVC = vc
            
            /// move posts list to parent controller
            vc.view.frame = profileVC.view.frame
            
            profileVC.shadowScroll.isScrollEnabled = false
            profileVC.passedCamera = MKMapCamera(lookingAtCenter: mapVC.mapView.centerCoordinate, fromDistance: mapVC.mapView.camera.centerCoordinateDistance, pitch: mapVC.mapView.camera.pitch, heading: mapVC.mapView.camera.heading)

            mapVC.postsList = postsList
            mapVC.profileViewController = nil
            mapVC.toggleMapTouch(enable: true)
            
            mapVC.customTabBar.tabBar.isHidden = true
            mapVC.navigationItem.titleView = nil
    //        mapVC.navigationController?.setNavigationBarHidden(true, animated: false)

            profileVC.addChild(vc)
            profileVC.view.addSubview(vc.view)
            vc.didMove(toParent: profileVC)
            
            /// open from mapVC
            let infoPass = ["selectedPost": row, "firstOpen": true, "parentVC":  PostViewController.parentViewController.profile] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            
        }
    }
}
