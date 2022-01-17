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
    lazy var guestbookPreviews: [GuestbookPreview] = []
    lazy var postDates: [(date: String, seconds: Int64)] = []

    lazy var postAnnotations: [CustomPointAnnotation] = []
    
    var listener1: ListenerRegistration!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()

    var active = false
    var loaded = false /// when loaded enables scroll
    var emptyView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "SpotBlack")
        
        setUpPostsCollection()
        getPosts(refresh: false)
        
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
                if postsList.contains(where: {$0.id == id}) {
                    openPostPage(postID: id, imageIndex: 0)
                }
            }
        }
    }
    
    @objc func notifyNewPost(_ sender: NSNotification) {
        if let newPost = sender.userInfo?.first?.value as? MapPost {

            var post = newPost
            post = setSecondaryPostValues(post: post)

            postsList.append(newPost)
            postsList.sort(by: {$0.seconds > $1.seconds})

            var frameIndexes = newPost.frameIndexes ?? []
            if frameIndexes.isEmpty { for i in 0...newPost.imageURLs.count - 1 { frameIndexes.append(i)} }

            let date = getDateTimestamp(seconds: newPost.actualTimestamp?.seconds ?? newPost.seconds)
            for i in 0...frameIndexes.count - 1 { guestbookPreviews.append(GuestbookPreview(postID: newPost.id!, frameIndex: frameIndexes[i], imageIndex: i, imageURL: newPost.imageURLs[frameIndexes[i]], seconds: newPost.seconds, date: date)) }
            guestbookPreviews.sort(by: {$0.seconds > $1.seconds})

            updatePostDates(date: date, seconds: newPost.seconds)
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

        /// only one delete from spotVC so use single delete function
        if let postIDs = sender.userInfo?.first?.value as? [String] {
            guard let postID = postIDs.first else { return }
            
            if let index = self.postsList.firstIndex(where: {$0.id == postID}) {
                
                let postDate = getDateTimestamp(seconds: postsList[index].actualTimestamp?.seconds ?? postsList[index].seconds)
                
                self.postsList.remove(at: index)
                self.postsList.sort(by: {$0.seconds > $1.seconds})
                
                /// remove date section if this was the only post with that date
                var removeDate = true
                for post in postsList { if getDateTimestamp(seconds: post.actualTimestamp?.seconds ?? post.seconds) == postDate { removeDate = false } }
                if removeDate { self.postDates.removeAll(where: { $0.date == postDate })}
                
                self.guestbookPreviews.removeAll(where: {$0.postID == postID})
                guestbookPreviews.sort(by: {$0.seconds > $1.seconds})
                
                self.postsCollection.reloadData()
                if postsList.count == 0 { return } /// cancel post page funcs on spotDelete
                
                if let postVC = profileVC.children.last(where: {$0 is PostViewController}) as? PostViewController {

                    postVC.postsList = self.postsList
                    postVC.tableView.beginUpdates()
                    postVC.tableView.deleteRows(at: [IndexPath(row: postVC.selectedPostIndex, section: 0)], with: .bottom)
                    
                    /// scroll table to previous row if necessary
                    if postVC.selectedPostIndex >= postVC.postsList.count {
                        postVC.selectedPostIndex = max(0, postVC.postsList.count - 1)
                        postVC.tableView.scrollToRow(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .top, animated: true)
                        postVC.tableView.reloadData()
                    }
                    
                    postVC.tableView.endUpdates()

                    let mapPass = ["selectedPost": postVC.selectedPostIndex as Any, "firstOpen": false, "parentVC": PostViewController.parentViewController.profile] as [String : Any]
                    NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: mapPass)
                }
            }
            
            if let index = self.mapVC.postsList.firstIndex(where: {$0.id == postID}) {
                self.mapVC.postsList.remove(at: index)
                self.mapVC.postsList.sort(by: {$0.seconds > $1.seconds})
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
        if !loaded {
            DispatchQueue.main.async { self.postsIndicator.startAnimating() }
        }
    }

    
    func resetView() {
        // reset posts called on initial load and when switching between segs
        active = true
        addAnnotations()
        
        if postsList.isEmpty && UserDataModel.shared.userInfo.spotScore ?? 0 > 0 {
            resumeIndicatorAnimation()
            
        } else {
            /// call reload in case cell images didn't finish loading
            DispatchQueue.main.async { self.postsCollection.reloadData() }
        }
    }
    
    func addAnnotations() {
        
        print("remove on profile posts")
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
        postsLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        postsLayout.headerReferenceSize = CGSize(width: UIScreen.main.bounds.width, height: 39)

        postsCollection.frame = view.frame
        postsCollection.backgroundColor = UIColor(named: "SpotBlack")
        postsCollection.setCollectionViewLayout(postsLayout, animated: true)
        postsCollection.delegate = self
        postsCollection.dataSource = self
        postsCollection.backgroundView = nil
        postsCollection.isScrollEnabled = false
        postsCollection.showsVerticalScrollIndicator = false
        postsCollection.register(GuestbookCell.self, forCellWithReuseIdentifier: "GuestbookCell")
        postsCollection.register(TimestampHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "TimestampHeader")
        view.addSubview(postsCollection)
        
        postsIndicator = CustomActivityIndicator(frame: CGRect(x: 0, y: 15, width: UIScreen.main.bounds.width, height: 30))
        postsCollection.addSubview(postsIndicator)
    }
    
        
    func getPosts(refresh: Bool) {
        
        guard let profileVC = profileVC else { return }
        let query = db.collection("posts").whereField("posterID", isEqualTo: profileVC.id).order(by: "timestamp", descending: true)

        listener1 = query.addSnapshotListener { [weak self] (snap, err) in
            
            guard let self = self else { return }
            guard let profileVC = self.profileVC else { return }

            guard let docs = snap?.documents else {
                /// add empty state if user got nothing
                if profileVC.userInfo == nil { return }
                if profileVC.userInfo.spotScore == 0 {  self.postsIndicator.stopAnimating() }
                return
            }
            
            if docs.count == 0 { self.postsIndicator.stopAnimating(); return }
            var spotIndex = 0
            
            for doc in docs {
                                
                do {
                    
                    let info = try doc.data(as: MapPost.self)
                    guard var postInfo = info else { self.docIndex += 1; if self.docIndex == docs.count  { self.finishPostsLoad() }; continue }

                    postInfo.id = doc.documentID
                    postInfo = self.setSecondaryPostValues(post: postInfo)
                    
                    //access check
                    /// check user access if the profile isn't from current user, friend check will happen over the top so don't need to check if user is friends with current user
                    if self.uid != profileVC.id {
                        if postInfo.createdBy != self.uid && postInfo.privacyLevel == "invite" {
                            if !(postInfo.inviteList?.contains(where: {$0 == self.uid}) ?? false) {
                                self.docIndex += 1; if self.docIndex == docs.count {
                                    self.finishPostsLoad(); continue
                                } else { continue }
                            }
                        }
                    }
                    
                    spotIndex += 1

                    /// animate map to first post location if this isn't the active user
                    if spotIndex == 1 && self.postsList.isEmpty && self.uid != profileVC.id {
                        profileVC.mapVC.animateToProfileLocation(active: false, coordinate: CLLocationCoordinate2D(latitude: postInfo.postLat, longitude: postInfo.postLong))
                    }
                                        
                    /// set user data -- don't need another listener here because poster is same for all posts
                    postInfo.userInfo = profileVC.userInfo
                    self.getComments(post: postInfo, docCount: docs.count)
                    continue
                    
                } catch { self.docIndex += 1; if self.docIndex == docs.count { self.finishPostsLoad() }; continue }
            }
        }
    }
    
    func getComments(post: MapPost, docCount: Int) {
        
        var info = post
        var commentList: [MapComment] = []
        
       self.db.collection("posts").document(info.id!).collection("comments").order(by: "timestamp", descending: true).getDocuments { [weak self] (commentSnap, err) in
            
            guard let self = self else { return }
            
           if err != nil { self.docIndex += 1; if self.docIndex == docCount { self.finishPostsLoad() }; return }
            if commentSnap!.documents.count == 0 {
                self.docIndex += 1; if self.docIndex == docCount { self.finishPostsLoad() }
            }
            
            for doc in commentSnap!.documents {
                
                let lastComment = doc == commentSnap!.documents.last
                
                do {
                    
                    let commInfo = try doc.data(as: MapComment.self)
                    guard var commentInfo = commInfo else { if lastComment { info.commentList = commentList; self.loadPostToMap(post: info, docCount: docCount) }; continue }
                    
                    commentInfo.id = doc.documentID
                    commentInfo.seconds = commentInfo.timestamp.seconds
                    commentInfo.commentHeight = self.getCommentHeight(comment: commentInfo.comment)

                    if !commentList.contains(where: {$0.id == doc.documentID}) {
                        commentList.append(commentInfo)
                        commentList.sort(by: {$0.seconds < $1.seconds})
                    }

                     if lastComment {
                         info.commentList = commentList
                         self.loadPostToMap(post: info, docCount: docCount)
                         return
                     }
                    continue
                    
                } catch {
                    if lastComment {
                        info.commentList = commentList
                        self.loadPostToMap(post: info, docCount: docCount)
                    }
                    continue
                }
            }
        }
    }
    
    func finishPostsLoad() {
        
        loaded = true

        /// probably want to do 1 big refresh
        DispatchQueue.main.async { [weak self] in

            guard let self = self else { return }
            
            if self.postsIndicator.isAnimating() { self.postsIndicator.stopAnimating() }
            self.postsCollection.reloadData()
            
            self.postsCollection.performBatchUpdates(nil, completion: {
                (result) in
                
                guard let profileVC = self.profileVC else { return }
                
                if profileVC.selectedIndex == 1 {
                    
                    profileVC.shadowScroll.contentSize = CGSize(width: UIScreen.main.bounds.width, height: max(UIScreen.main.bounds.height - profileVC.sec0Height, self.postsCollection.contentSize.height + profileVC.sec0Height + 250))
                ///    if self.mapVC.customTabBar.view.frame.minY < 200 { profileVC.shadowScroll.isScrollEnabled = true }
                    
                }
            })
        }
    }
    
    func loadPostToMap(post: MapPost, docCount: Int) {
        
        if mapVC.deletedPostIDs.contains(post.id ?? "") { return }

        if postsList.contains(where: {$0.id == post.id}) {

            /// already contains post - active listener found a change, probably a comment or like
            if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {
                
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
            
        } else {
            
            postsList.append(post)
            
            let postDate = getDateTimestamp(seconds: post.actualTimestamp?.seconds ?? post.seconds)
            updatePostDates(date: postDate, seconds: post.seconds)
            
            var frameIndexes = post.frameIndexes ?? []
            if frameIndexes.isEmpty && !post.imageURLs.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }

            if !frameIndexes.isEmpty { for i in 0...frameIndexes.count - 1 { guestbookPreviews.append(GuestbookPreview(postID: post.id!, frameIndex: frameIndexes[i], imageIndex: i, imageURL: post.imageURLs[frameIndexes[i]], seconds: post.seconds, date: postDate)) } }
            guestbookPreviews.sort(by: {$0.seconds > $1.seconds})
            
            let annotation = CustomPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: post.postLat, longitude: post.postLong)
            annotation.postID = post.id!
            postAnnotations.append(annotation)
            
            postsList.sort(by: {$0.seconds > $1.seconds})
            docIndex += 1; if docIndex == docCount { finishPostsLoad() }

            if active {
                mapVC.postsList = postsList
                mapVC.mapView.addAnnotation(annotation)
            }
        }
    }
    
    func updatePostDates(date: String, seconds: Int64) {
        
        if let temp = postDates.last(where: {$0.date == date}) {
            /// new most recent post with this date
            if seconds > temp.seconds {
                postDates.removeAll(where: {$0.date == date})
                postDates.append((date: date, seconds: seconds))
            }
        } else { postDates.append((date: date, seconds: seconds)) }
        
        postDates.sort(by: {$0.seconds > $1.seconds})
    }

    func removeListeners() {
        
        if listener1 != nil { listener1.remove(); listener1 = nil }
                
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostTap"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("NewPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("EditPost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DeletePost"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
}

extension ProfilePostsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return postDates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "TimestampHeader", for: indexPath) as! TimestampHeader
        view.setUp(date: postDates[indexPath.section].date)
        return view
    }

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var count = 0
        for preview in guestbookPreviews {
            if preview.date == postDates[section].date { count += 1 }
        }
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GuestbookCell", for: indexPath) as? GuestbookCell else { return UICollectionViewCell() }
        
        /// break out guestbook previews  into subsets for each date
        var subset: [GuestbookPreview] = []
        for preview in guestbookPreviews {
            if preview.date == postDates[indexPath.section].date {
                subset.append(preview)
            }
        }

        if subset.count <= indexPath.row { return cell }
        cell.setUp(preview: subset[indexPath.row])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        guard let cell = cell as? GuestbookCell else { return }
        cell.imagePreview.image = UIImage()
        
        var subset: [GuestbookPreview] = []
        for preview in guestbookPreviews {
            if preview.date == postDates[indexPath.section].date {
                subset.append(preview)
            }
        }
        
        guard let preview = subset[safe: indexPath.row] else { return }
        
        let itemWidth = (UIScreen.main.bounds.width - 10.5) / 3
        let itemHeight = itemWidth * 1.374

        /// resize to aspect ratio * 2 + added padding for rounding errors
        let transformer = SDImageResizingTransformer(size: CGSize(width: itemWidth * 2, height: itemHeight * 2 + 5), scaleMode: .aspectFill)
        cell.imagePreview.sd_setImage(with: URL(string: preview.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer], progress: nil)
        
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let cell = cell as? GuestbookCell else { return }
        cell.imagePreview.sd_cancelCurrentImageLoad()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? GuestbookCell else { return }
        openPostPage(postID: cell.postID, imageIndex: cell.imageIndex)
    }

    func openPostPage(postID: String, imageIndex: Int) {
        
        if let vc = UIStoryboard(name: "SpotPage", bundle: nil).instantiateViewController(identifier: "Post") as? PostViewController {
            
            /// cancel downloads on visible images
            removeDownloads()
            
            let index = postsList.firstIndex(where: {$0.id == postID}) ?? 0
            vc.postsList = self.postsList
            vc.postsList[index].selectedImageIndex = imageIndex
            vc.selectedPostIndex = index
            
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
            
            mapVC.navigationItem.titleView = nil
    //        mapVC.navigationController?.setNavigationBarHidden(true, animated: false)

            profileVC.addChild(vc)
            profileVC.view.addSubview(vc.view)
            vc.didMove(toParent: profileVC)
            
            /// open from mapVC
            let infoPass = ["selectedPost": index, "firstOpen": true, "parentVC":  PostViewController.parentViewController.profile] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostOpen"), object: nil, userInfo: infoPass)
            
        }
    }
}
