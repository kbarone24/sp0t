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

class ProfilePostsViewController: UIViewController {
    
    unowned var profileVC: ProfileViewController!
    unowned var mapVC: MapViewController!
    weak var postVC: PostViewController!
    
    lazy var postsIndicator = CustomActivityIndicator()
    lazy var postsCollection: UICollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout.init())
    lazy var postsLayout: UICollectionViewFlowLayout = UICollectionViewFlowLayout.init()
    
    lazy var postsList: [MapPost] = []
    lazy var postAnnotations: [CustomPointAnnotation] = []
    
    var listener1, listener2: ListenerRegistration!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    
    var endDocument: DocumentSnapshot!
    var refresh: refreshStatus = .noRefresh

    var active = false
    var loaded = false /// when loaded enables scroll
    var emptyView: UIView!
        
    enum refreshStatus {
        case yesRefresh
        case refreshing
        case noRefresh
    }
    
    deinit {
        print("deinit posts")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        setUpPostsCollection()
        DispatchQueue.global(qos: .userInitiated).async { self.getPosts(refresh: false) }
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostTap(_:)), name: NSNotification.Name("PostTap"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyNewPost(_:)), name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyEditPost(_:)), name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyDeletePost(_:)), name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if active {
            print(" remove ")
            mapVC.postsList.removeAll()
            active = false
        }
        
        removeDownloads()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if profileVC.children.contains(where: {$0 is PostViewController}) { return }
        if profileVC.status == .friends { resetPosts() }
    }
        
    @objc func notifyIndexChange(_ sender: NSNotification) {
        if profileVC.addedPost {
            if let info = sender.userInfo as? [String: Any] {
                if let index = info["index"] as? Int {
                    guard let id = info["id"] as? String else { return }
                    if postVC != nil && id != postVC.vcid { return }
                    if let post = info["post"] as? MapPost { self.postsList[index] = post }
                    /// refresh if current postIndex > 4 in the current refresh count and refresh hasn't been called yey so 4 / 16 / 28
                    let refreshes = (self.postsList.count - 1) / 12
                    if index > refreshes * 12 + 4 && self.refresh == .yesRefresh {
                        loadMorePosts(delay: false)
                    }
                }
            }
        }
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
            removeEmptyState()
            postsList.insert(newPost, at: 0)
            postsCollection.reloadData()
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: newPost.postLat, longitude: newPost.postLong)
            self.postAnnotations.append(annotation)
        }
    }
    
    @objc func notifyEditPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {
            // edit post from postsVC
            if let index = postsList.firstIndex(where: {$0.id == newPost.id}) {
                self.postsList[index] = newPost
                self.postsCollection.reloadData()
            }
        } else if let info = sender.userInfo as? [String: Any] {
            // spot level info changed
            guard let postID = info["postID"] as? String else { return }
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                self.postsList[index].spotName = info["spotName"] as? String ?? ""
                self.postsList[index].inviteList = info["inviteList"] as? [String] ?? []
                self.postsList[index].spotLat = info["spotLat"] as? Double ?? 0.0
                self.postsList[index].spotLong = info["spotLong"] as? Double ?? 0.0
                self.postsList[index].spotPrivacy = info["spotPrivacy"] as? String ?? ""
                self.postsCollection.reloadData()
            }
        }
    }
    
    @objc func notifyDeletePost(_ sender: NSNotification) {
        
        if let postID = sender.userInfo?.first?.value as? String {
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                
                self.postsList.remove(at: index)
                self.postsList.sort(by: {$0.seconds > $1.seconds})
                self.postsCollection.reloadData()
                mapVC.postsList = self.postsList
                
                if let postVC = self.profileVC.children.last(where: {$0 is PostViewController}) as? PostViewController {

                    postVC.postsList = self.postsList
                    postVC.tableView.deleteRows(at: [IndexPath(row: postVC.selectedPostIndex, section: 0)], with: .bottom)
                    
                    if postVC.postsList.count == 0 { postVC.exitPosts(swipe: false) }
                    
                    let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.profile] as [String : Any]
                    NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                }
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
        if !self.postsIndicator.isHidden {
            DispatchQueue.main.async { self.postsIndicator.startAnimating() }
        }
    }

    
    func resetPosts() {
        // reset posts called on initial load and when switching between segs
        active = true
        addAnnotations()
        if postsList.isEmpty && mapVC.userInfo.spotScore ?? 0 > 0 {
            loadMorePosts(delay: false)
            resumeIndicatorAnimation()
        } else {
            /// call reload in case cell images didn't finish loading
            DispatchQueue.main.async { self.postsCollection.reloadData() }
            checkForNewPosts()
        }
    }
    
    func addAnnotations() {
        let annotations = self.mapVC.mapView.annotations
        self.mapVC.mapView.removeAnnotations(annotations)
        
        if !self.postAnnotations.isEmpty {
            mapVC.postsList = self.postsList
            for anno in postAnnotations {
                DispatchQueue.main.async { self.mapVC.mapView.addAnnotation(anno) }
            }
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
        
        postsIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 30))
        postsCollection.addSubview(postsIndicator)
    }
    
    func checkForNewPosts() {
        DispatchQueue.global().async { self.getPosts(refresh: true) }
    }
        
    func getPosts(refresh: Bool) {
        
        var query = self.db.collection("posts").whereField("posterID", isEqualTo: profileVC.id).order(by: "timestamp", descending: true)
        if endDocument != nil && !refresh { query = query.start(atDocument: endDocument) }
        
        self.listener1 = query.addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (snap, err) in
            
            guard let self = self else { return }
            
            guard let docs = snap?.documents else {
                /// add empty state if user got nothing
                if self.profileVC.userInfo == nil { return }
                
                if self.profileVC.userInfo.spotScore == 0 {
                    self.addEmptyState()
                    self.postsIndicator.stopAnimating()
                }
                return
            }
            
            if docs.count == 0 {
                self.addEmptyState()
                self.postsIndicator.stopAnimating()
                return
            }
            
            
            var dispatchIndex = 1
            for doc in docs {
                
                if doc == docs.last! {
                    if self.postsIndicator.isAnimating() { self.postsIndicator.stopAnimating() }
                }
                
                if dispatchIndex > 12 {
                    if !refresh { self.endDocument = doc }
                    return
                }
                
                /// at the end of the query, noRefresh to avoid future calls
                if docs.count < 12 {
                    self.refresh = .noRefresh
                }

                do {
                    let postInfo = try doc.data(as: MapPost.self)
                    guard var info = postInfo else { continue }

                    info.seconds = info.timestamp.seconds
                    info.id = doc.documentID
                    
                    //access check
                    /// check user access if the profile isn't from current user, friend check will happen over the top so don't need to check if user is friends with current user
                    if self.uid != self.profileVC.id {
                        if info.createdBy != self.uid && info.privacyLevel == "invite" {
                            if !(info.inviteList?.contains(where: {$0 == self.uid}) ?? false) {
                                continue
                            }
                        }
                    }
                    
                    /// animate map to first post location if this isn't the active user
                    if dispatchIndex == 1 && self.postsList.isEmpty && self.uid != self.profileVC.id {
                        self.profileVC.mapVC.animateToProfileLocation(active: false, coordinate: CLLocationCoordinate2D(latitude: info.postLat, longitude: info.postLong))
                    }
                    
                    dispatchIndex += 1
                    
                    /// set user data -- don't need another listener here because poster is same for all posts
                    info.userInfo = self.profileVC.userInfo
                    
                    var commentList: [MapComment] = []
                    
                    self.listener2 = self.db.collection("posts").document(info.id!).collection("comments").order(by: "timestamp", descending: true).addSnapshotListener(includeMetadataChanges: true, listener: { [weak self] (commentSnap, err) in

                        guard let self = self else { return }
                        if err != nil { return }
                        
                        for doc in commentSnap!.documents {
                            do {
                                
                                let commInfo = try doc.data(as: MapComment.self)
                                guard var commentInfo = commInfo else { continue }
                                
                                commentInfo.id = doc.documentID
                                commentInfo.seconds = commentInfo.timestamp.seconds
                                commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)

                                if !commentList.contains(where: {$0.id == doc.documentID}) {
                                    commentList.append(commentInfo)
                                    commentList.sort(by: {$0.seconds < $1.seconds})
                                }

                                let docCount = commentSnap!.documents.count
                                let commentCount = commentList.count
                                
                                 if commentCount >= docCount {
                                     info.commentList = commentList
                                     self.loadPostToProfile(post: info)
                                 }
                                
                            } catch {
                                continue
                            }
                        }
                    })
                } catch { continue }
            }
        })
    }
    
    
    func loadPostToProfile(post: MapPost) {
        if !postsList.contains(where: {$0.id == post.id}) {

            postsList.append(post)
            loaded = true
            // load more posts on a delay if active
            if postsList.count % 12 == 0 { refresh = .yesRefresh }
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            postAnnotations.append(annotation)
            
            postsList.sort(by: {$0.seconds > $1.seconds})
            
            DispatchQueue.main.async {
                if self.postsIndicator.isAnimating() { self.postsIndicator.stopAnimating() }
                self.postsCollection.reloadData()
                self.postsCollection.performBatchUpdates(nil, completion: {
                    (result) in
                    if self.profileVC.selectedIndex == 0 { self.profileVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - self.profileVC.sec0Height, self.postsCollection.contentSize.height + 65)) }
                })
            }
            
            if self.mapVC.customTabBar.view.frame.minY < 200 && self.profileVC.selectedIndex == 0 { self.profileVC.shadowScroll.isScrollEnabled = true }
            
            if let postVC = profileVC.children.last(where: {$0 is PostViewController}) as? PostViewController {
                
                postVC.mapVC.postsList = self.postsList
                
                if postVC.postsList.count == postVC.selectedPostIndex {
                    mapVC.postsList = postsList
                    ///send notification to map to animate to new post if its on the loading page
                    let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC":  PostViewController.parentViewController.profile] as [String : Any]
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass) }
                }
                
                postVC.postsList.append(post)
                DispatchQueue.main.async { postVC.tableView.reloadData() }
                
            } else {
                if active {
                    mapVC.postsList = postsList
                    mapVC.mapView.addAnnotation(annotation)
                }
            }
            
        } else {
            /// already contains post - active listener found a change, probably a comment or like
            if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {
                
                if mapVC.deletedPostIDs.contains(post.id ?? "") { return }
                postsList[index] = post

                if let postVC = profileVC.children.last(where: {$0 is PostViewController}) as? PostViewController {
                    if let index = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
                        
                        let selectedIndex = postVC.postsList[index].selectedImageIndex
                        self.postsList[index].selectedImageIndex = selectedIndex

                        postVC.postsList[index] = post
                        postVC.postsList[index].selectedImageIndex = selectedIndex
                    }
                    if postVC.tableView != nil { postVC.tableView.reloadData() }
                }
            }
        }
    }
    
    
    func addEmptyState() {
        /// add empty state to collection
        print("add empty")
        if uid != profileVC.id { return }
        emptyView = UIView(frame: CGRect(x: 0, y: 20, width: UIScreen.main.bounds.width, height: 100))
        emptyView.backgroundColor = nil
        postsCollection.addSubview(emptyView)
        
        let emptyButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - 81.5, y: 5, width: 163, height: 76))
        emptyButton.setImage(UIImage(named: "ProfileEmptyState"), for: .normal)
        emptyButton.imageView?.contentMode = .scaleAspectFit
        emptyButton.addTarget(self, action: #selector(pushCamera(_:)), for: .touchUpInside)
        emptyView.addSubview(emptyButton)
        /// disable seg
        if let segHeader = profileVC.tableView.headerView(forSection: 1) as? SegViewHeader {
            segHeader.segmentedControl.isEnabled = false
            segHeader.buttonBar.isHidden = true
        }
    }
    
    func removeEmptyState() {
        if emptyView != nil { emptyView.removeFromSuperview()}
        if let segHeader = profileVC.tableView.headerView(forSection: 1) as? SegViewHeader {
            segHeader.segmentedControl.isEnabled = true
            segHeader.buttonBar.isHidden = false
        }
    }
    
    func loadMorePosts(delay: Bool) {
        
        if profileVC.status != .friends { return }
        
        refresh = .refreshing
        let rows = (((self.postsList.count) - 1) / 3) + 1
        let itemHeight = ((UIScreen.main.bounds.width - 10) / 3) *  1.374
        var indicatorY = CGFloat(rows) * itemHeight
        
        /// y adjustment for indicator
        indicatorY += CGFloat(rows - 4) * 5
        if postsList.isEmpty { indicatorY = 25 }
        
        self.postsIndicator.frame = CGRect(x: 0, y: indicatorY + 30, width: UIScreen.main.bounds.width, height: 40)
        self.postsIndicator.startAnimating()
        
        DispatchQueue.global(qos: .userInitiated).async {
            if delay { DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.getPosts(refresh: false)
            }} else { self.getPosts(refresh: false) }
        }
    }
    
    // pushCamera is called from the empty state prompting first spot add
    @objc func pushCamera(_ sender: UIButton) {
        if let vc = UIStoryboard(name: "AddSpot", bundle: nil).instantiateViewController(identifier: "AVCameraController") as? AVCameraController {
            vc.mapVC = profileVC.mapVC
            let transition = CATransition()
            transition.duration = 0.3
            transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            transition.type = CATransitionType.push
            transition.subtype = CATransitionSubtype.fromTop
            profileVC.mapVC.navigationController?.view.layer.add(transition, forKey: kCATransition)
            profileVC.mapVC.navigationController?.pushViewController(vc, animated: false)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        //initiate reload of posts once user hits bottom
        let reloadNum = (postsList.count - 1) / 12
        let itemHeight = ((UIScreen.main.bounds.width - 10) / 3) *  1.374

        let originalOffset = postsCollection.frame.minY
        let minOffset = CGFloat(reloadNum) * (itemHeight * 4) + originalOffset
        let yOffset = scrollView.contentOffset.y
        
        if yOffset > minOffset && self.refresh == .yesRefresh {
            refresh = .refreshing
            self.loadMorePosts(delay: true)
        }
    }
    
    func removeListeners() {
        if self.listener1 != nil { self.listener1.remove() }
        if self.listener2 != nil { self.listener2.remove() }
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
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
        
        if cell.cachedImage.postID == post.id! && cell.cachedImage.image != UIImage() {
            cell.imagePreview.image = cell.cachedImage.image
            return
        }
        
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
        cell.imagePreview.sd_cancelCurrentImageLoad()

    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("did select")
        openPostAt(row: indexPath.row)
    }

    func openPostAt(row: Int) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            /// cancel downloads on visible images
            removeDownloads()
            
            vc.postsList = self.postsList
            vc.selectedPostIndex = row
            vc.mapVC = self.mapVC
            vc.parentVC = .profile
            
            self.postVC = vc
            
            /// move posts list to parent controller
            vc.view.frame = profileVC.view.frame
            
            profileVC.shadowScroll.isScrollEnabled = false
            profileVC.passedCamera = MKMapCamera(lookingAtCenter: mapVC.mapView.centerCoordinate, fromDistance: mapVC.mapView.camera.centerCoordinateDistance, pitch: mapVC.mapView.camera.pitch, heading: mapVC.mapView.camera.heading)

            mapVC.postsList = self.postsList
            mapVC.profileViewController = nil
            profileVC.addedPost = true
            
            mapVC.customTabBar.tabBar.isHidden = true
            mapVC.navigationController?.setNavigationBarHidden(true, animated: false)

            profileVC.addChild(vc)
            profileVC.view.addSubview(vc.view)
            vc.didMove(toParent: profileVC)
            
            /// open from mapVC
            let infoPass = ["selectedPost": row, "firstOpen": true, "parentVC":  PostViewController.parentViewController.profile] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            
            self.navigationItem.titleView = nil
        }
    }
}
