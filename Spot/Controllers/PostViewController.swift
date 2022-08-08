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
    
    var selectedPostIndex = 0 /// current row in posts table
    var commentNoti = false /// present commentsVC if opened from notification comment
    
    var dotView: UIView!
                        
    deinit {
        print("deinit")
    }
  
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "PostPageOpen")
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
                        
        addPullLineAndNotifications()
        
        if commentNoti {
            openComments(row: 0)
            commentNoti = false
        }

        setUpNavBar()
        
        /*
        dotView = UIView(frame: CGRect(x: 12, y: 5, width: UIScreen.main.bounds.width - 24, height: 2.5))
        dotView.backgroundColor = nil
        view.addSubview(dotView)
        setDotView() */
    }
    
    func setDotView() {
        
        /*
        if dotView != nil { for sub in dotView.subviews { sub.removeFromSuperview() }}
        
        let post = postsList[selectedPostIndex]
        let frameIndexes = post.frameIndexes ?? []
        
        if frameIndexes.count > 1 {
            
            let gapSize: CGFloat = 4
            let gapWidth: CGFloat = CGFloat(frameIndexes.count - 1) * gapSize
            let dotWidth: CGFloat = (dotView.bounds.width - gapWidth) / CGFloat(frameIndexes.count)
            
            var offset: CGFloat = 0
            for i in 0...frameIndexes.count - 1 {
                let dot = UIView(frame: CGRect(x: offset, y: 0, width: dotWidth, height: 2.5))
                dot.backgroundColor = i <= post.selectedImageIndex! ? UIColor(named: "SpotGreen") : UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)
                dot.layer.cornerRadius = 2
                dot.layer.cornerCurve = .continuous
                dotView.addSubview(dot)
                
                offset += dotWidth + gapSize
            }
        } */
    }
        
    func addPullLineAndNotifications() {
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
        
        /*
        mapVC.navigationItem.leftBarButtonItem = nil
        mapVC.navigationItem.rightBarButtonItem = nil
                
        /// add exit button over top of feed for profile and spot page
        let backButton = UIBarButtonItem(image: UIImage(named: "CircleBackButton")?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(exitPosts(_:)))
        backButton.imageInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 0)
        mapVC.navigationItem.leftBarButtonItem = backButton
        mapVC.navigationItem.rightBarButtonItem = nil */
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
        
    //    if let mapVC = parent as? MapController { mapVC.resetFeed() }
        
        removeFromParent()
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostIndexChange"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PostLike"), object: nil)
    }
    
    func setSeen(post: MapPost) {
        
        /*
        db.collection("posts").document(post.id!).updateData(["seenList" : FieldValue.arrayUnion([uid])])
        guard let mapVC = parent as? MapController else { return }
        if post.seenList == nil { return }
        
        var newPost = post
        if !newPost.seenList!.contains(uid) {
            newPost.seenList!.append(uid)
            mapVC.friendsPostsDictionary[post.id!] = post
        } */
    }
}

class PostCell: UICollectionViewCell {
    
    lazy var imageManager = SDWebImageManager()
    var globalRow = 0 /// row in table
    var post: MapPost!
    
    var vcid: String!
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()

    var imageView: PostImageView!
    
    var detailView: UIView!
    var mapIcon: UIImageView!
    var mapName: UILabel!
    var separatorLine: UIView!
    var spotIcon: UIImageView!
    var spotLabel: UILabel!
    var cityLabel: UILabel!

    var buttonView: UIView!
    var likeButton, commentButton: UIButton!
    var numLikes, numComments: UILabel!
    
    var captionLabel: UILabel!
    
    var userView: UIView!
    var profileImage: UIImageView!
    var usernameLabel: UILabel!
    var timestampLabel: UILabel!
                
    var nextButton, previousButton: UIButton!
    var swipe: UIPanGestureRecognizer!
    
    var offScreen = false /// off screen to avoid double interactions with first cell being pulled down
    var offCell = false
    var imageFetched = false
    var overflow = false
    var originalOffset: CGFloat = 0
    
    let cellHeight = UIScreen.main.bounds.height
    let cellWidth = UIScreen.main.bounds.width

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }
        
    func setUp(post: MapPost, row: Int) {
        self.post = post
        self.tag = 16
        globalRow = row
        imageFetched = false
        
        resetTextInfo()
        self.backgroundColor = nil
        
        addImageView()
        addButtonView()
        addDetailView()
        addCaption()
        addUserView()
        addTapButtons()
    }
    
    func addImageView() {
        imageView = PostImageView {
            $0.layer.cornerRadius = 15
            $0.tag = globalRow
            $0.isUserInteractionEnabled = true
            contentView.addSubview($0)
        }
         imageView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(post.imageHeight!)
            $0.centerY.equalToSuperview()
        }
    }
    
    func addButtonView() {
        buttonView = UIView {
            contentView.addSubview($0)
        }
        buttonView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.bottom.equalToSuperview().inset(87)
            $0.width.equalTo(41.4)
            $0.height.equalTo(127)
        }
        
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")
        
        numComments = UILabel {
            $0.text = String(max(post.commentList.count - 1, 0))
            $0.font = UIFont(name: "SFCompactText-Bold", size: 12)
            $0.textColor = .white
            buttonView.addSubview($0)
        }
        numComments.snp.makeConstraints {
            $0.bottom.equalToSuperview()
            $0.centerX.equalToSuperview()
        }
        
        commentButton = UIButton {
            $0.setImage(UIImage(named: "CommentButton"), for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(commentsTap(_:)), for: .touchUpInside)
            buttonView.addSubview($0)
        }
        commentButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(numComments.snp.top).offset(-2)
            $0.height.equalTo(41.4)
        }
        
        numLikes = UILabel {
            $0.text = String(post.likers.count)
            $0.font = UIFont(name: "SFCompactText-Bold", size: 12)
            $0.textColor = .white
            buttonView.addSubview($0)
        }
        numLikes.snp.makeConstraints {
            $0.bottom.equalTo(commentButton.snp.top).offset(-20)
            $0.centerX.equalToSuperview()
        }
        
        likeButton = UIButton {
            liked ? $0.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside) : $0.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
            $0.setImage(likeImage, for: .normal)
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            buttonView.addSubview($0)
        }
        likeButton.snp.makeConstraints {
            $0.bottom.equalTo(numLikes.snp.top).offset(-2)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(36.8)
        }
        
    }
    
    func addDetailView() {
        detailView = UIView {
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        detailView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.trailing.equalTo(buttonView.snp.leading).offset(-15)
            $0.bottom.equalTo(buttonView.snp.bottom)
            $0.height.equalTo(16.55)
        }
        
        if post.mapID ?? "" != "" {
            mapIcon = UIImageView {
                $0.image = UIImage(named: "FeedMapIcon")
                detailView.addSubview($0)
            }
            mapIcon.snp.makeConstraints {
                $0.leading.equalTo(13)
                $0.bottom.equalToSuperview().inset(1)
                $0.width.equalTo(15.2)
                $0.height.equalTo(15)
            }

            mapName = UILabel {
                $0.text = post.mapName ?? ""
                $0.textColor = .white
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 15.5)
                detailView.addSubview($0)
            }
            mapName.snp.makeConstraints {
                $0.leading.equalTo(mapIcon.snp.trailing).offset(5)
                $0.trailing.lessThanOrEqualToSuperview()
                $0.bottom.equalToSuperview()
            }
            
            let mapButton = UIButton {
                $0.addTarget(self, action: #selector(mapTap), for: .touchUpInside)
                detailView.addSubview($0)
            }
            mapButton.snp.makeConstraints {
                $0.leading.equalTo(mapIcon.snp.leading)
                $0.trailing.equalTo(mapName.snp.trailing)
                $0.height.equalToSuperview()
            }
            
            if post.spotID ?? "" != "" {
                separatorLine = UIView {
                    $0.backgroundColor = UIColor.white.withAlphaComponent(0.4)
                    $0.layer.cornerRadius = 1
                    detailView.addSubview($0)
                }
                separatorLine.snp.makeConstraints {
                    $0.leading.equalTo(mapName.snp.trailing).offset(8)
                    $0.bottom.equalToSuperview()
                    $0.width.equalTo(2)
                    $0.height.equalTo(14)
                }
            }
        }
        
        if post.spotID ?? "" != "" {
            spotIcon = UIImageView {
                $0.image = UIImage(named: "FeedSpotIcon")
                detailView.addSubview($0)
            }
            spotIcon.snp.makeConstraints {
                $0.bottom.equalToSuperview().inset(1)
                $0.width.equalTo(12.8)
                $0.height.equalTo(15.55)
                if post.mapID ?? "" == "" {
                    $0.leading.equalTo(13)
                } else {
                    $0.leading.equalTo(separatorLine.snp.trailing).offset(8)
                }
            }
            
            spotLabel = UILabel {
                $0.text = post.spotName ?? ""
                $0.textColor = .white
                $0.font = UIFont(name: "SFCompactText-Semibold", size: 15.5)
                detailView.addSubview($0)
            }
            spotLabel.snp.makeConstraints {
                $0.leading.equalTo(spotIcon.snp.trailing).offset(5)
                $0.trailing.lessThanOrEqualToSuperview()
                $0.bottom.equalToSuperview()
            }
            
            let spotButton = UIButton {
                $0.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
                detailView.addSubview($0)
            }
            spotButton.snp.updateConstraints {
                $0.leading.equalTo(spotIcon.snp.leading)
                $0.trailing.equalTo(spotLabel.snp.trailing)
                $0.height.equalToSuperview()
            }
            
            if post.mapID ?? "" == "" {
                cityLabel = UILabel {
                    $0.text = post.city ?? ""
                    $0.textColor = UIColor.white.withAlphaComponent(0.6)
                    $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
                    detailView.addSubview($0)
                }
                cityLabel.snp.makeConstraints {
                    $0.leading.equalTo(spotLabel.snp.trailing).offset(4)
                    $0.trailing.lessThanOrEqualToSuperview()
                    $0.bottom.equalToSuperview()
                }
            }
        }
    }
    
    func addCaption() {
        /// font 14.7 = 18 pt line exactly
        let tempHeight = getCaptionHeight(caption: post.caption, fontSize: 14.5, maxCaption: 0)
        overflow = tempHeight > post.captionHeight!
        
        captionLabel = UILabel {
            $0.text = post.caption
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.numberOfLines = overflow ? 3 : 0
            $0.lineBreakMode = overflow ? .byClipping : .byWordWrapping
            $0.isUserInteractionEnabled = true
            $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap(_:))))
            contentView.addSubview($0)
        }
        captionLabel.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.trailing.equalTo(buttonView.snp.leading).offset(-15)
            $0.height.equalTo(post.captionHeight!)
            
            if post.spotID ?? "" != "" || post.mapID ?? "" != "" {
                $0.bottom.equalTo(detailView.snp.top).offset(-16)
            } else {
                $0.bottom.equalTo(buttonView.snp.bottom)
            }
        }
    }
    
    func addMoreIfNeeded() {
        if overflow {
            captionLabel.addTrailing(with: "... ", moreText: "more", moreTextFont: UIFont(name: "SFCompactText-Semibold", size: 14.5)!, moreTextColor: .white)
        }
    }
    
    func addUserView() {
        userView = UIView {
            contentView.addSubview($0)
        }
        userView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.trailing.equalTo(buttonView.snp.leading).offset(-15)
            $0.bottom.equalTo(captionLabel.snp.top).offset(-7)
            $0.height.equalTo(25)
        }
        
        profileImage = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.backgroundColor = .gray
            $0.layer.cornerRadius = 25/2
            userView.addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.width.height.equalTo(25)
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: post.userInfo?.imageURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        usernameLabel = UILabel {
            $0.text = post.userInfo?.username ?? ""
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15.5)
            userView.addSubview($0)
        }
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(profileImage.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
        }
        
        timestampLabel = UILabel {
            $0.text = getTimestamp(postTime: post.timestamp)
            $0.textColor = UIColor.white.withAlphaComponent(0.6)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            userView.addSubview($0)
        }
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
        }
    }
    
    func addTapButtons() {
        nextButton = UIButton {
            $0.addTarget(self, action: #selector(nextTap(_:)), for: .touchUpInside)
            contentView.addSubview($0)
        }
        nextButton.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalTo(50)
            $0.bottom.equalTo(buttonView.snp.top)
            $0.width.equalTo(100)
        }
        
        previousButton = UIButton {
            $0.addTarget(self, action: #selector(previousTap(_:)), for: .touchUpInside)
            contentView.addSubview($0)
        }
        previousButton.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalTo(50)
            $0.bottom.equalTo(buttonView.snp.top)
            $0.width.equalTo(100)
        }
        
        swipe = UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
       // contentView.addGestureRecognizer(swipe)
    }
    
    func finishImageSetUp(images: [UIImage]) {
        resetImageInfo()
        
        let imageAspect = post.imageHeight! / UIScreen.main.bounds.width
    //    let imageY: CGFloat = imageAspect > 1.8 ? 0 : imageAspect > 1.5 ? userViewMaxY : (cellHeight - post.imageHeight!)/2
        
        var frameIndexes = post.frameIndexes ?? []
        if post.imageURLs.count == 0 { return }
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }
        post.frameIndexes = frameIndexes

        if images.isEmpty { return }
        post.postImage = images

        /*
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(tap) */
        
        setCurrentImage()
        
        if imageAspect > 1.3 { imageView.addBottomMask() }
    }
    
    func setCurrentImage() {
        imageFetched = true
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        guard let still = images[safe: frameIndexes[post.selectedImageIndex!]] else { return }
        imageView.image = still
        imageView.stillImage = still

        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex!)
        imageView.animationImages = animationImages
        imageView.animationIndex = 0
                        
        if !animationImages.isEmpty && !imageView.activeAnimation {
            animationImages.count == 5 && post.frameIndexes!.count == 1 ? imageView.animate5FrameAlive(directionUp: true, counter: imageView.animationIndex) : imageView.animateGIF(directionUp: true, counter: imageView.animationIndex)  /// use old animation for 5 frame alives
        }
    }
    
    @objc func spotTap() {
        if let postVC = viewContainingController() as? PostController {
            print("add spot page from here")
        }
    }
    
    @objc func mapTap() {
        print("map tap")
    }
    
    func resetTextInfo() {
        if mapIcon != nil { mapIcon.removeFromSuperview() }
        if mapName != nil { mapName.text = ""; mapName.removeFromSuperview() }
        if separatorLine != nil { separatorLine.removeFromSuperview() }
        if spotIcon != nil { spotIcon.removeFromSuperview() }
        if spotLabel != nil { spotLabel.text = ""; spotLabel.removeFromSuperview() }
        if cityLabel != nil { cityLabel.text = ""; cityLabel.removeFromSuperview() }
        if likeButton != nil { likeButton.removeFromSuperview() }
        if commentButton != nil { commentButton.removeFromSuperview() }
        if numLikes != nil { numLikes.text = ""; numLikes.removeFromSuperview() }
        if numComments != nil { numComments.text = ""; numComments.removeFromSuperview() }
        if captionLabel != nil { captionLabel.text = ""; captionLabel.removeFromSuperview() }
        if profileImage != nil { profileImage.image = UIImage(); profileImage.removeFromSuperview(); profileImage.sd_cancelCurrentImageLoad() }
        if usernameLabel != nil { usernameLabel.text = ""; usernameLabel.removeFromSuperview() }
        if timestampLabel != nil { timestampLabel.text = ""; timestampLabel.removeFromSuperview() }
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0; imageView.removeFromSuperview() }
    }
    
    func resetImageInfo() {
        /// reset for fields that are set after image fetch (right now just called on cell init)
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0 }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageManager.cancelAll()
    }
        
    
    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        if overflow {
            let newHeight = getCaptionHeight(caption: post.caption, fontSize: 14.5, maxCaption: 0)
            captionLabel.text = post.caption
            captionLabel.numberOfLines = 0
            captionLabel.lineBreakMode = .byWordWrapping
            captionLabel.snp.updateConstraints { $0.height.equalTo(newHeight) }
            overflow = false
            
        } else if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow)
        }
    }
    
    @objc func commentsTap(_ sender: UIButton) {
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow)
        }
    }
        
    @objc func nextTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }
        if (post.selectedImageIndex! < (post.frameIndexes?.count ?? 0) - 1) && imageFetched {
            nextImage()
            
        } else if postVC.selectedPostIndex < postVC.postsList.count - 1 {
            nextPost()
            
        } else {
         //   exitPosts()
        }
    }
    
    @objc func previousTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }

        if post.selectedImageIndex! > 0 {
            previousImage()
            
        } else if postVC.selectedPostIndex > 0 {
            previousPost()
        
        } else {
         //   exitPosts()
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

            postVC.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - self.cellHeight, width: UIScreen.main.bounds.width, height: self.cellHeight)
            postVC.view.alpha = 1.0
            postVC.postsCollection.alpha = 1.0
            
            postVC.postsCollection.contentOffset.x = self.originalOffset /// reset horizontal swipe
            
        }) { [weak self] _ in
            guard let self = self else { return }
            self.offScreen = false
        }
    }
    
    func exitPosts() {
        
        Mixpanel.mainInstance().track(event: "PostPageRemove")
        
        guard let postVC = self.viewContainingController() as? PostController else { return }
                
        UIView.animate(withDuration: 0.2, animations: {
            
            postVC.view.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width: UIScreen.main.bounds.width, height: self.cellHeight)
            postVC.view.alpha = 0.0
            postVC.postsCollection.alpha = 0.0
                        
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
        print("increment image")
        post.selectedImageIndex! += index
        setCurrentImage()
        
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.postsList[postVC.selectedPostIndex].selectedImageIndex! += index
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
            functions.httpsCallable("likePost").call(["likerID": self.uid, "username": UserDataModel.shared.userInfo.username, "postID": self.post.id!, "imageURL": self.post.imageURLs.first ?? "", "spotID": self.post.spotID ?? "", "addedUsers": self.post.addedUsers ?? [], "posterID": self.post.posterID, "posterUsername": self.post.userInfo?.username ?? ""]) { result, error in
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
