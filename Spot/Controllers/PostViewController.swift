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

class PostController: UIViewController {
    
    let db: Firestore! = Firestore.firestore()
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    lazy var postsList: [MapPost] = []
    var spotObject: MapSpot!
    
    var postsCollection: UICollectionView!
    var parentVC: parentViewController = .feed
    unowned var mapVC: MapController!
    
    var selectedPostIndex = 0 /// current row in posts table
    var commentNoti = false /// present commentsVC if opened from notification comment
    
    var dotView: UIView!
    var userView: UIView!
    var timestamp: UILabel!
                    
    enum parentViewController {
        case feed
        case spot
        case profile
        case notifications
    }
    
    deinit {
        print("deinit")
    }
  
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
        setUpTable()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    
    func setUpTable() {
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: view.bounds.height)

        postsCollection = UICollectionView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: view.bounds.height), collectionViewLayout: layout)
        postsCollection.layer.cornerRadius = 10
        postsCollection.tag = 16
        postsCollection.backgroundColor = .black
        postsCollection.dataSource = self
        postsCollection.delegate = self
        postsCollection.prefetchDataSource = self
        postsCollection.isScrollEnabled = false
        postsCollection.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        postsCollection.register(PostCell.self, forCellWithReuseIdentifier: "PostCell")
        view.addSubview(postsCollection)
        
        DispatchQueue.main.async {  self.postsCollection.reloadData() }
                
        addPullLineAndNotifications()
        
        if commentNoti {
            openComments(row: 0)
            commentNoti = false
        }

        setUpNavBar()
        
        dotView = UIView(frame: CGRect(x: 12, y: 5, width: UIScreen.main.bounds.width - 24, height: 2.5))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        setDotView()
        
        userView = UIView(frame: CGRect(x: 0, y: 13, width: UIScreen.main.bounds.width, height: 45))
        view.addSubview(userView)
        
        let post = postsList[selectedPostIndex]
        
        let username = UILabel(frame: CGRect(x: 13, y: 0, width: 200, height: 19))
        username.text = post.userInfo == nil ? "" : post.userInfo!.username
        username.textColor = .white
        username.font = UIFont(name: "SFCompactText-Bold", size: 16)
        userView.addSubview(username)
        
        timestamp = UILabel(frame: CGRect(x: 13, y: username.frame.maxY + 3, width: 150, height: 15))
        timestamp.text = getTimestamp(postTime: post.timestamp)
        timestamp.textColor = UIColor.white.withAlphaComponent(0.8)
        timestamp.font = UIFont(name: "SFCompactText-Medium", size: 12)
        userView.addSubview(timestamp)
    }
    
    func setTimestamp() {
        let post = postsList[selectedPostIndex]
        timestamp.text = getTimestamp(postTime: post.timestamp)
    }
    
    func setDotView() {
        
        if dotView != nil { for sub in dotView.subviews { sub.removeFromSuperview() }}
        
        let post = postsList[selectedPostIndex]
        let frameIndexes = post.frameIndexes ?? []
        
        if frameIndexes.count > 1 {
            
            let gapSize: CGFloat = 4
            let gapWidth: CGFloat = CGFloat(frameIndexes.count - 1) * gapSize
            let dotWidth: CGFloat = (dotView.bounds.width - gapWidth) / CGFloat(frameIndexes.count)
            
            print("index", post.selectedImageIndex)
            var offset: CGFloat = 0
            for i in 0...frameIndexes.count - 1 {
                let dot = UIView(frame: CGRect(x: offset, y: 0, width: dotWidth, height: 2.5))
                dot.backgroundColor = i <= post.selectedImageIndex ? UIColor(named: "SpotGreen") : UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
                dot.layer.cornerRadius = 2
                dot.layer.cornerCurve = .continuous
                dotView.addSubview(dot)
                
                offset += dotWidth + gapSize
            }
        }
    }
        
    func addPullLineAndNotifications() {
        /// broken out into its own function so it can be called on transition from tutorial to regular view
        
        NotificationCenter.default.addObserver(self, selector: #selector(notifyIndexChange(_:)), name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyPostLike(_:)), name: NSNotification.Name("PostLike"), object: nil)
    }
        
    @objc func notifyPostLike(_ sender: NSNotification) {
        
        if let info = sender.userInfo as? [String: Any] {
            if let post = info["post"] as? MapPost {
                guard let index = self.postsList.firstIndex(where: {$0.id == post.id}) else { return }
                self.postsList[index] = post
            }
        }
    }
    
    @objc func notifyIndexChange(_ sender: NSNotification) {

    }
    
    func setUpNavBar() {
        
        mapVC.navigationItem.leftBarButtonItem = nil
        mapVC.navigationItem.rightBarButtonItem = nil
        
      //  mapVC.setOpaqueNav()

        if parentVC == .feed {
            mapVC.setOpaqueNav()
            mapVC.navigationItem.titleView = nil
            mapVC.navigationItem.title = "Friend Posts"
        }
        
        /// add exit button over top of feed for profile and spot page
        let backButton = UIBarButtonItem(image: UIImage(named: "CircleBackButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(exitPosts(_:)))
        backButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
        mapVC.navigationItem.leftBarButtonItem = backButton
        mapVC.navigationItem.rightBarButtonItem = nil
    }
    
    func openComments(row: Int) {
        
        if presentedViewController != nil { return }
        if let commentsVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Comments") as? CommentsController {
            
            Mixpanel.mainInstance().track(event: "PostOpenComments")

            let post = self.postsList[selectedPostIndex]
            commentsVC.commentList = post.commentList
            commentsVC.post = post
            commentsVC.postVC = self
            commentsVC.postIndex = row
            present(commentsVC, animated: true, completion: nil)
        }
    }
    
    func getCommentsCaptionHeight(caption: String) -> CGFloat {
        
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 31, height: 20))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCompactText-Regular", size: 13)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        return tempLabel.frame.height
    }
        
    @objc func exitPosts(_ sender: UIBarButtonItem) {
        exitPosts()
    }
}

extension PostController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsList.count
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
        cell.setUp(post: post, row: indexPath.row, cellHeight: view.bounds.height)
        if indexPath.row == selectedPostIndex { setSeen(post: post) }
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
        
        /// posts will always be a child of feed vc
        self.willMove(toParent: nil)
        view.removeFromSuperview()
        
        if let mapVC = parent as? MapController { mapVC.resetFeed() }
        
        removeFromParent()
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
    }
    
    func setSeen(post: MapPost) {
        
        db.collection("posts").document(post.id!).updateData(["seenList" : FieldValue.arrayUnion([uid])])
        guard let mapVC = parent as? MapController else { return }
        if post.seenList == nil { return }
        
        var newPost = post
        if !newPost.seenList!.contains(uid) {
            newPost.seenList!.append(uid)
            mapVC.friendsPostsDictionary[post.id!] = post
        }
    }
}

class PostCell: UICollectionViewCell {
    
    var post: MapPost!
    var selectedSpotID: String!
            
    var spotView: UIView!
    var username: UILabel!
    var usernameDetail: UIView!
    
    var spotNameBanner: UIView!
    var spotIcon: UIImageView!
    var spotNameLabel: UILabel!
    var cityLabel: UILabel!

    var timestamp: UILabel!
    var postCaption: UILabel!
    
    var likeButton, commentButton: UIButton!
    var numLikes, numComments: UILabel!
    var buttonView: UIView!
    
    var imageView: PostImageView!
    
    var vcid: String!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
        
    let cellWidth: CGFloat = UIScreen.main.bounds.width
    var cellHeight: CGFloat = 0
    var userViewMaxY: CGFloat = 0
    
    var imageManager: SDWebImageManager!
    var globalRow = 0 /// row in table
    
    var nextButton, previousButton: UIButton!
    var swipe: UIPanGestureRecognizer!
    
    var offScreen = false /// off screen to avoid double interactions with first cell being pulled down
    var offCell = false
    var originalOffset: CGFloat = 0
    
    func setUp(post: MapPost, row: Int, cellHeight: CGFloat) {
        
        resetTextInfo()
        self.backgroundColor = nil

        imageManager = SDWebImageManager()
        
        self.cellHeight = cellHeight
        self.userViewMaxY = UIScreen.main.bounds.height - cellHeight + 13
        
        self.post = post
        self.selectedSpotID = post.spotID
        self.tag = 16
        globalRow = row
        
        spotView = UIView(frame: CGRect(x: 0, y: cellHeight - 118, width: UIScreen.main.bounds.width, height: 43))
        contentView.addSubview(spotView)
        
        spotIcon = UIImageView(frame: CGRect(x: 13, y: 0, width: 18, height: 18))
        spotIcon.image = UIImage(named: "FeedSpotIcon")
        spotView.addSubview(spotIcon)
        
        spotNameLabel = UILabel(frame: CGRect(x: spotIcon.frame.maxX + 6, y: 1, width: UIScreen.main.bounds.width - 72 - spotIcon.frame.maxX, height: 16))
        spotNameLabel.text = post.spotName ?? ""
        spotNameLabel.textColor = .white
        spotNameLabel.isUserInteractionEnabled = false
        spotNameLabel.font = UIFont(name: "SFCompactText-Bold", size: 16)
        spotView.addSubview(spotNameLabel)

        cityLabel = UILabel(frame: CGRect(x: 13, y: spotIcon.frame.maxY + 8, width: UIScreen.main.bounds.width - 30, height: 18))
        cityLabel.text = post.city ?? ""
        cityLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        cityLabel.isUserInteractionEnabled = false
        cityLabel.font = UIFont(name: "SFCompactText-Medium", size: 15)
        spotView.addSubview(cityLabel)
        
        /// font 14.7 = 18 pt line exactly
        let noImage = post.imageURLs.isEmpty
        let fontSize: CGFloat = noImage ? 30 : 18
        
        let tempHeight = getCaptionHeight(caption: post.caption, fontSize: fontSize)
        let overflow = tempHeight > post.captionHeight

        let bigFrameY = userViewMaxY + (spotView.frame.minY - post.captionHeight - userViewMaxY)/2
        let minY = noImage ? bigFrameY : spotView.frame.minY - 15 - post.captionHeight
        
        postCaption = UILabel(frame: CGRect(x: 13, y: minY, width: UIScreen.main.bounds.width - 83, height: post.captionHeight + 0.5))
        postCaption.text = post.caption
        postCaption.textColor = UIColor(red: 0.946, green: 0.946, blue: 0.946, alpha: 1)
        postCaption.font = UIFont(name: "SFCompactText-Regular", size: fontSize)
        
        let numberOfLines = overflow ? Int(post.captionHeight/21) : 0
        postCaption.numberOfLines = numberOfLines
        postCaption.lineBreakMode = overflow ? .byClipping : .byWordWrapping
        postCaption.isUserInteractionEnabled = true
        
        postCaption.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap(_:))))
        
        if overflow {
            postCaption.addTrailing(with: "... ", moreText: "more", moreTextFont: UIFont(name: "SFCompactText-Semibold", size: fontSize)!, moreTextColor: .white)
            addSubview(self.postCaption)
        } else { contentView.addSubview(postCaption) }
        
                
        buttonView = UIView(frame: CGRect(x: UIScreen.main.bounds.width - 62, y: cellHeight - 198, width: 43, height: 134))
        addSubview(buttonView)
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")
        
        likeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 42.2, height: 38.8))
        liked ? likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside) : likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.setImage(likeImage, for: .normal)
        likeButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        buttonView.addSubview(likeButton)
        
        numLikes = UILabel(frame: CGRect(x: 0, y: likeButton.frame.maxY + 3, width: 43, height: 15))
        numLikes.text = String(post.likers.count)
        numLikes.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
        numLikes.textColor = .white
        numLikes.textAlignment = .center
        buttonView.addSubview(numLikes)

        commentButton = UIButton(frame: CGRect(x: 0, y: numLikes.frame.maxY + 15, width: 43.2, height: 41.9))
        commentButton.setImage(UIImage(named: "CommentButton"), for: .normal)
        commentButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        commentButton.addTarget(self, action: #selector(commentsTap(_:)), for: .touchUpInside)
        buttonView.addSubview(commentButton)
        
        numComments = UILabel(frame: CGRect(x: 0, y: commentButton.frame.maxY + 1, width: 43, height: 15))
        let commentCount = max(post.commentList.count - 1, 0)
        numComments.text = String(commentCount)
        numComments.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
        numComments.textColor = .white
        numComments.textAlignment = .center
        buttonView.addSubview(numComments)
        
        let buttonHeight = buttonView.frame.minY - userViewMaxY - 20
        nextButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 100, y: userViewMaxY + 10, width: 100, height: buttonHeight))
        nextButton.addTarget(self, action: #selector(nextTap(_:)), for: .touchUpInside)
        contentView.addSubview(nextButton)
        
        previousButton = UIButton(frame: CGRect(x: 0, y: userViewMaxY + 10, width: 100, height: buttonHeight))
        previousButton.addTarget(self, action: #selector(previousTap(_:)), for: .touchUpInside)
        contentView.addSubview(previousButton)
        
        swipe = UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
        contentView.addGestureRecognizer(swipe)
    }
    
    func finishImageSetUp(images: [UIImage]) {
                
        resetImageInfo()
        
        let imageAspect = post.imageHeight / UIScreen.main.bounds.width
        let imageY: CGFloat = imageAspect > 1.8 ? 0 : imageAspect > 1.5 ? userViewMaxY : (cellHeight - post.imageHeight)/2
        
        var frameIndexes = post.frameIndexes ?? []
        if post.imageURLs.count == 0 { return }
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }
        post.frameIndexes = frameIndexes

        if images.isEmpty { return }
        post.postImage = images

        imageView = PostImageView(frame: CGRect(x: 0, y: imageY, width: UIScreen.main.bounds.width, height: post.imageHeight))
        imageView.layer.cornerRadius = 15
        imageView.tag = globalRow
        imageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(tap)
        
        contentView.addSubview(imageView)

        setCurrentImage()
        
        if imageAspect > 1.5 { imageView.addBottomMask() }
        if imageAspect > 1.7 { imageView.addTopMask() }
            
        /// bring subviews and tap areas above masks
        if postCaption != nil { contentView.bringSubviewToFront(postCaption) }
        if buttonView != nil { contentView.bringSubviewToFront(buttonView) }
        if spotView != nil { contentView.bringSubviewToFront(spotView) }
        if previousButton != nil { contentView.bringSubviewToFront(previousButton) }
        if nextButton != nil { contentView.bringSubviewToFront(nextButton) }
    }
    
    func setCurrentImage() {
        
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        guard let still = images[safe: frameIndexes[post.selectedImageIndex]] else { return }
        
        let imageAspect = still.size.height / still.size.width
        imageView.contentMode = (imageAspect + 0.01 < (post.imageHeight / UIScreen.main.bounds.width)) && imageAspect < 1.1  ? .scaleAspectFit : .scaleAspectFill
        if imageView.contentMode == .scaleAspectFit { imageView.roundCornersForAspectFit(radius: 15) }

        imageView.image = still
        imageView.stillImage = still

        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex)
        imageView.animationImages = animationImages
        imageView.animationIndex = 0
                
        if !animationImages.isEmpty && !imageView.activeAnimation {
            animationImages.count == 5 && post.frameIndexes!.count == 1 ? imageView.animate5FrameAlive(directionUp: true, counter: imageView.animationIndex) : imageView.animateGIF(directionUp: true, counter: imageView.animationIndex, alive: post.gif ?? false)  /// use old animation for 5 frame alives
        }
    }
    
    func resetTextInfo() {
        /// reset for fields that are set before image fetch
        if spotNameLabel != nil { spotNameLabel.text = "" }
        if cityLabel != nil { cityLabel.text = "" }
        if username != nil { username.text = "" }
        if timestamp != nil { timestamp.text = "" }
        if postCaption != nil { postCaption.text = "" }
        if commentButton != nil { commentButton.setImage(UIImage(), for: .normal) }
        if numComments != nil { numComments.text = "" }
        if likeButton != nil { likeButton.setImage(UIImage(), for: .normal) }
        if numLikes != nil { numLikes.text = "" }
        if buttonView != nil { for sub in buttonView.subviews { sub.removeFromSuperview() }}
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0; imageView.removeFromSuperview() }
    }
    
    func resetImageInfo() {
        /// reset for fields that are set after image fetch (right now just called on cell init)
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0; imageView.removeFromSuperview() }
    }
    
    override func prepareForReuse() {
        
        super.prepareForReuse()
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
    }
        
    
    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow)
        }
    }
    
    @objc func commentsTap(_ sender: UIButton) {
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow)
        }
    }
        
    func getCaptionHeight(caption: String, fontSize: CGFloat) -> CGFloat {
                
        let tempLabel = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 83, height: cellHeight))
        tempLabel.text = caption
        tempLabel.font = UIFont(name: "SFCompactText-Regular", size: fontSize)
        tempLabel.numberOfLines = 0
        tempLabel.lineBreakMode = .byWordWrapping
        tempLabel.sizeToFit()
        
        return tempLabel.frame.height
    }

    @objc func nextTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }

        if (post.selectedImageIndex < (post.frameIndexes?.count ?? 0) - 1) && !post.postImage.isEmpty {
            nextImage()
            
        } else if postVC.selectedPostIndex < postVC.postsList.count - 1 {
            nextPost()
            
        } else {
            exitPosts()
        }
    }
    
    @objc func previousTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }

        if post.selectedImageIndex > 0 {
            previousImage()
            
        } else if postVC.selectedPostIndex > 0 {
            previousPost()
        
        } else {
            exitPosts()
        }
    }
    
    @objc func swipe(_ sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: self)
        let velocity = sender.velocity(in: self)
        
        if abs(translation.y) > abs(translation.x) || offScreen {
            if translation.y > 0  || offScreen {
                exitSwipe(sender: sender)
            } else if translation.y < 0 && velocity.y < 300 {
                commentSwipe(sender: sender)
            }
        } else {
            nextSwipe(sender: sender)
        }
    }
    
    func exitSwipe(sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: self)
        let velocity = sender.velocity(in: self)

        switch sender.state {
        case .began:
            offScreen = true
        case .changed:
            offScreen = true
            offsetVertical(translation: translation.y)
            
        case .ended, .cancelled:
            guard let postVC = viewContainingController() as? PostController else { return }
            postVC.view.frame.minY > 80 && velocity.y > -1 ? exitPosts() : resetFrame()
        default:
            resetFrame()
        }
    }
    
    func commentSwipe(sender: UIPanGestureRecognizer) {
        if sender.state == .ended {
            guard let postVC = viewContainingController() as? PostController else { return }
            postVC.openComments(row: globalRow)
        }
    }
    
    func offsetVertical(translation: CGFloat) {
        
        guard let postVC = viewContainingController() as? PostController else { return }
        guard let mapVC = postVC.parent as? MapController else { return }
        
        let offsetY: CGFloat = translation/2.5
        let alphaMultiplier = (1 - (cellHeight-offsetY)/cellHeight)/2
        let alpha = 1.0 - alphaMultiplier
        let maskAlpha = max(0, 1.0 - alphaMultiplier * 10)
        
        let originalY: CGFloat = UIScreen.main.bounds.height - cellHeight
        postVC.view.frame = CGRect(x: 0, y: max(originalY + offsetY, originalY), width: UIScreen.main.bounds.width, height: cellHeight)
        postVC.view.alpha = alpha
        postVC.postsCollection.alpha = alpha
        mapVC.statusBarMask.alpha = maskAlpha
    }
    
    func nextSwipe(sender: UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: self)
        let velocity = sender.velocity(in: self)

        guard let postVC = viewContainingController() as? PostController else { return }
        guard let collection = superview as? UICollectionView else { return }
        
        switch sender.state {
        case .began:
            offCell = true
            originalOffset = collection.contentOffset.x
            
        case .changed:
            collection.setContentOffset(CGPoint(x: originalOffset - translation.x, y: 0), animated: false)
            
        case .ended, .cancelled:
            
            let actualOffset = collection.contentOffset.x - velocity.x/2 - originalOffset
            // left swipe
            if actualOffset + translation.x > 0 {
                let leftBorder = cellWidth/4
                /// advance next
                if actualOffset > leftBorder  {
                    if postVC.selectedPostIndex == postVC.postsList.count - 1 { self.exitPosts(); return } /// could also reset frame
                    nextPost()
                } else {
                    resetFrame()
                }
                
            } else {
            // right swipe
                let rightBorder = -cellWidth/4
                
                if actualOffset < rightBorder {
                    /// previous
                    if postVC.selectedPostIndex == 0 { self.exitPosts(); return }
                    previousPost()
                } else {
                    resetFrame()
                }
            }
            
        default:
            resetFrame()
        }
    }
        
    func resetFrame() {

        UIView.animate(withDuration: 0.2, animations: {
            
            guard let postVC = self.viewContainingController() as? PostController else { return }
            guard let mapVC = postVC.parent as? MapController else { return }

            postVC.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - self.cellHeight, width: UIScreen.main.bounds.width, height: self.cellHeight)
            postVC.view.alpha = 1.0
            postVC.postsCollection.alpha = 1.0
            mapVC.statusBarMask.alpha = 1.0
            
            postVC.postsCollection.contentOffset.x = self.originalOffset /// reset horizontal swipe
            
        }) { [weak self] _ in
            guard let self = self else { return }
            self.offScreen = false
        }
    }
    
    func exitPosts() {
        
        Mixpanel.mainInstance().track(event: "PostPageRemove")
        
        guard let postVC = self.viewContainingController() as? PostController else { return }
        guard let mapVC = postVC.parent as? MapController else { return }
                
        UIView.animate(withDuration: 0.2, animations: {
            
            postVC.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: self.cellHeight)
            postVC.view.alpha = 0.0
            postVC.postsCollection.alpha = 0.0
            mapVC.statusBarMask.alpha = 0.0
                        
        }, completion: { _ in
            postVC.exitPosts()
        })
    }
    
    func nextImage() {
        incrementImage(index: 1)
    }
    
    func previousImage() {
        incrementImage(index: -1)
    }
    
    func incrementImage(index: Int) {
        post.selectedImageIndex += index
        setCurrentImage()
        
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.postsList[postVC.selectedPostIndex].selectedImageIndex += index
        postVC.setDotView()
    }
    
    func nextPost() {
        incrementPost(index: 1)
    }
    
    func previousPost() {
        incrementPost(index: -1)
    }
    
    func incrementPost(index: Int) {
        
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.selectedPostIndex += index
        postVC.postsCollection.scrollToItem(at: IndexPath(row: postVC.selectedPostIndex, section: 0), at: .left, animated: true)
        
        postVC.setTimestamp()
        postVC.setDotView()
    }
        
    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        if post.likers.contains(uid) { return }
        likePost()
    }
    
    @objc func likePost(_ sender: UIButton) {
        likePost()
    }
    
    func likePost() {
        
        guard let postVC = viewContainingController() as? PostController else { return }
        
        post.likers.append(self.uid)
        likeButton.removeTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        
        let likeImage =  UIImage(named: "LikeButtonFilled")
        likeButton.setImage(likeImage, for: .normal)
        
        layoutLikesAndComments()
        
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": postVC.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
        DispatchQueue.global().async {
            if self.post.id == "" { return }
            self.db.collection("posts").document(self.post.id!).updateData(["likers" : FieldValue.arrayUnion([self.uid])])
            
            let functions = Functions.functions()
            functions.httpsCallable("likePost").call(["likerID": self.uid, "username": UserDataModel.shared.userInfo.username, "postID": self.post.id!, "imageURL": self.post.imageURLs.first ?? "", "spotID": self.post.spotID ?? "", "addedUsers": self.post.addedUsers ?? [], "posterID": self.post.posterID, "posterUsername": self.post.userInfo.username]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    @objc func unlikePost(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }

        post.likers.removeAll(where: {$0 == self.uid})
        likeButton.removeTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        
        let likeImage = UIImage(named: "LikeButton")
        likeButton.setImage(likeImage, for: .normal)
                
        //update main data source -- send notification to map, update comments
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": postVC.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
        
        if post.id == "" { return }
        let updatePost = post! /// local object
        
        DispatchQueue.global().async {
            self.db.collection("posts").document(updatePost.id!).updateData(["likers" : FieldValue.arrayRemove([self.uid])])
            let functions = Functions.functions()
            functions.httpsCallable("unlikePost").call(["postID": updatePost.id!, "posterID": updatePost.posterID, "likerID": self.uid]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    func layoutLikesAndComments() {
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = String(post.likers.count)
        numLikes.textColor = liked ? UIColor(red: 0.18, green: 0.817, blue: 0.817, alpha: 1) : UIColor(red: 0.471, green: 0.471, blue: 0.471, alpha: 1)
        
        likeButton.setImage(likeImage, for: .normal)
        
        let commentCount = max(post.commentList.count - 1, 0)
        numComments.text = String(commentCount)
    }

    
    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int], imageIndex: Int) -> [UIImage] {

        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }
        
        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }
}
