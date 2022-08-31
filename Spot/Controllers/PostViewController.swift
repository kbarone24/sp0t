//
//  PostController.swift
//  Spot
//
//  Created by kbarone on 1/8/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Firebase
import CoreLocation
import Mixpanel
import FirebaseUI
import Geofirestore
import FirebaseFunctions
import SnapKit

class PostController: UIViewController {
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    lazy var postsList: [MapPost] = []
    var spotObject: MapSpot!
    
    var postsCollection: UICollectionView!
    unowned var containerDrawerView: DrawerView? {
        didSet {
            configureDrawerView()
        }
    }
    var openComments = false
    
    lazy var deleteIndicator = CustomActivityIndicator()
    
    var selectedPostIndex = 0 {
        didSet {
            let post = postsList[selectedPostIndex]
            DispatchQueue.global().async {
                self.setSeen(post: self.postsList[self.selectedPostIndex])
                self.checkForUpdates(postID: post.id!, index: self.selectedPostIndex)
            }
        }
    }

    var dotView: UIView!
                            
    deinit {
        print("deinit post")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpNavBar()
        configureDrawerView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
        
        if openComments {
            openComments(row: selectedPostIndex, animated: true)
            openComments = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelDownloads()
    }
    
    
    func cancelDownloads() {
        
        // cancel image loading operations and reset map
        for op in PostImageModel.shared.loadingOperations {
            guard let imageLoader = PostImageModel.shared.loadingOperations[op.key] else { continue }
            imageLoader.cancel()
            PostImageModel.shared.loadingOperations.removeValue(forKey: op.key)
        }
        
        PostImageModel.shared.loadingQueue.cancelAllOperations()
    }
    
    func setUpNavBar() {
         navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    func configureDrawerView() {
        containerDrawerView?.swipeDownToDismiss = true
        containerDrawerView?.canInteract = true
        containerDrawerView?.showCloseButton = false
        DispatchQueue.main.async { self.containerDrawerView?.present(to: .Top) }
    }
    
    func setUpView() {
        
        postsCollection = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
            view.tag = 16
            view.backgroundColor = .black
            view.dataSource = self
            view.delegate = self
            view.prefetchDataSource = self
            view.isScrollEnabled = false
            view.layer.cornerRadius = 10
            view.register(PostCell.self, forCellWithReuseIdentifier: "PostCell")
            return view
        }()
        view.addSubview(postsCollection)
        postsCollection.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        selectedPostIndex = 0
        addNotifications()
    }
    
    func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostLike(_:)), name: NSNotification.Name("PostLike"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentChange(_:)), name: NSNotification.Name(("CommentChange")), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostDelete(_:)), name: NSNotification.Name("DeletePost"), object: nil)
    }
        
    @objc func notifyPostLike(_ notification: NSNotification) {
        if let info = notification.userInfo as? [String: Any] {
            if let post = info["post"] as? MapPost {
                guard let index = self.postsList.firstIndex(where: {$0.id == post.id}) else { return }
                self.postsList[index] = post
            }
        }
    }
    
    @objc func notifyCommentChange(_ notification: NSNotification) {
        guard let commentList = notification.userInfo?["commentList"] as? [MapComment] else { return }
        guard let postID = notification.userInfo?["postID"] as? String else { return }
        if let i = postsList.firstIndex(where: {$0.id == postID}) {
            postsList[i].commentCount = max(0, commentList.count - 1)
            postsList[i].commentList = commentList
            DispatchQueue.main.async { self.postsCollection.reloadData() }
        }
    }
    
    @objc func notifyPostDelete(_ notification: NSNotification) {
        guard let post = notification.userInfo?["post"] as? MapPost else { return }
        DispatchQueue.main.async {
            if let index = self.postsList.firstIndex(where: {$0.id == post.id}) {
                print("got index")
                self.deletePostLocally(index: index)
            } else {
                print("no index")
            }
        }
    }
    
    func openComments(row: Int, animated: Bool) {
        if presentedViewController != nil { return }
        if let commentsVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Comments") as? CommentsController {
            
            Mixpanel.mainInstance().track(event: "PostOpenComments")

            let post = self.postsList[selectedPostIndex]
            commentsVC.commentList = post.commentList
            commentsVC.post = post
            commentsVC.postVC = self
            present(commentsVC, animated: animated, completion: nil)
        }
    }
    
    func openProfile(user: UserProfile, openComments: Bool) {
        let profileVC = ProfileViewController(userProfile: user, presentedDrawerView: containerDrawerView)
        self.openComments = openComments
        DispatchQueue.main.async { self.navigationController!.pushViewController(profileVC, animated: true) }
    }
    
    func openMap(mapID: String) {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.id = mapID
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
        navigationController?.pushViewController(customMapVC, animated: true)
    }
}

extension PostController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDataSourcePrefetching, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        /// adjusted inset will always = 0 unless extending scroll view edges beneath inset again
        let adjustedInset = collectionView.adjustedContentInset.top + collectionView.adjustedContentInset.bottom
        return CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height - adjustedInset)
    }
            
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.zero
    }
              
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {

        let updateCellImage: ([UIImage]?) -> () = { [weak self] (images) in
            guard let self = self else { return }
            guard let post = self.postsList[safe: indexPath.row] else { return }
            guard let cell = cell as? PostCell else { return } /// declare cell within closure in case cancelled
            if post.imageURLs.count != images?.count { return } /// patch fix for wrong images getting called with a post -> crashing on image out of bounds on get frame indexes

            if let index = self.postsList.lastIndex(where: {$0.id == post.id}) { if indexPath.row != index { return }  }
        
            if indexPath.row == self.selectedPostIndex { PostImageModel.shared.currentImageSet = (id: post.id ?? "", images: images ?? []) }
                        
            cell.finishImageSetUp(images: images ?? [])
        }
        
        guard let post = postsList[safe: indexPath.row] else { return }
        
        /// Try to find an existing data loader
        if let dataLoader = PostImageModel.shared.loadingOperations[post.id ?? ""] {
            
            /// Has the data already been loaded?
            if dataLoader.images.count == post.imageURLs.count {
                guard let cell = cell as? PostCell else { return }
                cell.finishImageSetUp(images: dataLoader.images)
              //  loadingOperations.removeValue(forKey: post.id ?? "")
            } else {
                /// No data loaded yet, so add the completion closure to update the cell once the data arrives
                dataLoader.loadingCompleteHandler = updateCellImage
            }
        } else {
            
            /// Need to create a data loader for this index path
            if indexPath.row == self.selectedPostIndex && PostImageModel.shared.currentImageSet.id == post.id ?? "" {
                updateCellImage(PostImageModel.shared.currentImageSet.images)
                return
            }
                
            let dataLoader = PostImageLoader(post)
                /// Provide the completion closure, and kick off the loading operation
            dataLoader.loadingCompleteHandler = updateCellImage
            PostImageModel.shared.loadingQueue.addOperation(dataLoader)
            PostImageModel.shared.loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    ///https://medium.com/monstar-lab-bangladesh-engineering/tableview-prefetching-datasource-3de593530c4a
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PostCell", for: indexPath) as? PostCell else { return UICollectionViewCell() }
        let post = postsList[indexPath.row]
        cell.setUp(post: post, row: indexPath.row)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            
            if abs(indexPath.row - selectedPostIndex) > 3 { return }
            
            guard let post = postsList[safe: indexPath.row] else { return }
            if let _ = PostImageModel.shared.loadingOperations[post.id ?? ""] { return }

            let dataLoader = PostImageLoader(post)
            dataLoader.queuePriority = .high
            PostImageModel.shared.loadingQueue.addOperation(dataLoader)
            PostImageModel.shared.loadingOperations[post.id ?? ""] = dataLoader
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            /// I think due to the size of the table, prefetching was being cancelled for way too many rows, some like 1 or 2 rows away from the selected post index. This is kind of a hacky fix to ensure that fetching isn't cancelled when we'll need the image soon
            if abs(indexPath.row - selectedPostIndex) < 4 { return }

            guard let post = postsList[safe: indexPath.row] else { return }

            if let imageLoader = PostImageModel.shared.loadingOperations[post.id ?? ""] {
                imageLoader.cancel()
                PostImageModel.shared.loadingOperations.removeValue(forKey: post.id ?? "")
            }
        }
    }
        
    func exitPosts() {
        containerDrawerView?.closeAction()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
    }
    
    func setSeen(post: MapPost) {
        db.collection("posts").document(post.id!).updateData(["seenList" : FieldValue.arrayUnion([uid])])
        NotificationCenter.default.post(Notification(name: Notification.Name("PostOpen"), object: nil, userInfo: ["postID" : post.id as Any]))
    }
    
    func checkForUpdates(postID: String, index: Int) {
        /// update just the necessary info -> comments and likes
        getPost(postID: postID) { [weak self] post in
            guard let self = self else { return }
            if let i = self.postsList.firstIndex(where: {$0.id == postID}) {
                self.postsList[i].commentList = post.commentList
                self.postsList[i].commentCount = post.commentCount
                self.postsList[i].likers = post.likers
                if index != self.selectedPostIndex { return }
                /// update cell if this is the current post
                if let cell = self.postsCollection.cellForItem(at: IndexPath(item: index, section: 0)) as? PostCell {
                    DispatchQueue.main.async { cell.updatePost(post: self.postsList[i]) }
                }
            }
        }
    }
}
