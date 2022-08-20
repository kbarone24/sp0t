//
//  PostCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import FirebaseUI
import Mixpanel

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
    
    var dotView: UIView!

    var buttonView: UIView!
    var likeButton, commentButton: UIButton!
    var numLikes, numComments: UILabel!
    
    var captionLabel: UILabel!
    var tagRect: [(rect: CGRect, username: String)] = []

    var userView: UIView!
    var profileImage: UIImageView!
    var usernameLabel: UILabel!
    var timestampLabel: UILabel!
    var elipsesButton: UIButton!
                
    var nextButton, previousButton: UIButton!
    var swipe: UIPanGestureRecognizer!
    
    var offScreen = false /// off screen to avoid double interactions with first cell being pulled down
    var offCell = false
    var imageFetched = false
    var overflow = false
    var originalOffset: CGFloat = 0
    
    let cellHeight = UIScreen.main.bounds.height
    let cellWidth = UIScreen.main.bounds.width
    var bottomInset: CGFloat {
        return (UIScreen.main.bounds.height - (UserDataModel.shared.maxAspect * UIScreen.main.bounds.width))/2 - 10
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }
        
    func setUp(post: MapPost, row: Int) {
        self.post = post
        self.tag = 16
        self.backgroundColor = nil

        globalRow = row
        imageFetched = false
        resetTextInfo()
        
        addImageView()
        addButtonView()
        addDetailView()
        addCaption()
        addUserView()
        addTapButtons()
    }
    
    func updatePost(post: MapPost) {
        /// update on new likers/comments fetch
        self.post.commentList = post.commentList
        self.post.likers = post.likers
        numComments.text = String(max(post.commentList.count - 1, 0))
        numLikes.text = String(post.likers.count)
    }
    
    func addImageView() {
        imageView = PostImageView {
            $0.layer.cornerRadius = 19
            contentView.addSubview($0)
        }
    }
    
    func addButtonView() {
        buttonView = UIView {
            contentView.addSubview($0)
        }
        buttonView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(15)
            $0.bottom.equalToSuperview().inset(bottomInset)
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
            $0.bottom.equalTo(numComments.snp.top).offset(-1)
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
            $0.bottom.equalTo(numLikes.snp.top).offset(-1)
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
    
    func addDotView() {
        if dotView != nil { for sub in dotView.subviews {sub.removeFromSuperview()}}
        dotView = UIView {
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        dotView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalTo(detailView.snp.bottom).offset(15)
            $0.height.equalTo(2)
        }
        
        if post.frameIndexes?.count ?? 0 < 2 { return }
        let spaces = CGFloat(7 * post.frameIndexes!.count - 1)
        let dotWidth = (UIScreen.main.bounds.width - 32 - spaces) / CGFloat(post.frameIndexes!.count)
        var offset: CGFloat = 0
        for i in 0...(post.frameIndexes!.count) - 1 {
            let line = UIView {
                $0.backgroundColor = i <= post.selectedImageIndex! ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.65) : UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
                $0.layer.cornerRadius = 1
                dotView.addSubview($0)
            }
            /// constraints were breaking when snapping current view's leading to previous view's trailing
            line.snp.makeConstraints {
                $0.top.bottom.equalToSuperview()
                $0.leading.equalToSuperview().offset(offset)
                $0.width.equalTo(dotWidth)
            }
            offset += 7 + dotWidth
        }
    }
    
    func addCaption() {
        /// font 14.7 = 18 pt line exactly
        let tempHeight = getCaptionHeight(caption: post.caption, fontSize: 14.5, maxCaption: 0)
        overflow = tempHeight > post.captionHeight!
        
        captionLabel = UILabel {
            let attString = NSAttributedString(string: post.caption)
            $0.attributedText = attString
            $0.textColor = .white
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.numberOfLines = overflow ? 3 : 0
            $0.lineBreakMode = overflow ? .byClipping : .byWordWrapping
            $0.isUserInteractionEnabled = true
            $0.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap(_:))))
            contentView.addSubview($0)
        }
        addCaptionAttString()
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
    
    func addCaptionAttString() {
        if !(post.taggedUsers?.isEmpty ?? true) {
            let attString = self.getAttString(caption: post.caption, taggedFriends: post.taggedUsers!, font: captionLabel.font, maxWidth: UIScreen.main.bounds.width - 71.4)
            captionLabel.attributedText = attString.0
            tagRect = attString.1
        }
    }
    
    func addMoreIfNeeded() {
        if overflow {
            captionLabel.addTrailing(with: "... ", moreText: "more", moreTextFont: UIFont(name: "SFCompactText-Semibold", size: 14.5)!, moreTextColor: .white)
        }
    }
    
    func addUserView() {
        userView = UIView {
            $0.isUserInteractionEnabled = true
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
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(userTap))
            $0.addGestureRecognizer(tap)
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
            let tap = UITapGestureRecognizer(target: self, action: #selector(userTap))
            $0.addGestureRecognizer(tap)
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
        
        elipsesButton = UIButton {
            $0.setImage(UIImage(named: "Elipses"), for: .normal)
            $0.addTarget(self, action: #selector(elipsesTap), for: .touchUpInside)
            $0.imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            userView.addSubview($0)
        }
        elipsesButton.snp.makeConstraints {
            $0.leading.equalTo(timestampLabel.snp.trailing)
            $0.width.equalTo(34)
            $0.height.equalTo(20)
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
    }
    
    func finishImageSetUp(images: [UIImage]) {
        resetImageInfo()
        
        var frameIndexes = post.frameIndexes ?? []
        if post.imageURLs.count == 0 { return }
        if frameIndexes.isEmpty { for i in 0...post.imageURLs.count - 1 { frameIndexes.append(i)} }
        post.frameIndexes = frameIndexes

        if images.isEmpty { return }
        post.postImage = images
        
        addDotView()
        setCurrentImage()
    }
    
    func setCurrentImage() {
        imageFetched = true
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []
        
        guard let still = images[safe: frameIndexes[post.selectedImageIndex!]] else { return }
        imageView.image = still
        imageView.stillImage = still
        contentView.sendSubviewToBack(imageView)

        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes!, imageIndex: post.selectedImageIndex!)
        imageView.animationImages = animationImages
        imageView.animationIndex = 0
        
        let rawAspect = min(still.size.height/still.size.width, UserDataModel.shared.maxAspect)
        let currentAspect = getRoundedAspectRatio(aspect: rawAspect)
        let currentHeight = currentAspect * UIScreen.main.bounds.width
        imageView.currentAspect = currentAspect

        imageView.snp.removeConstraints()
        imageView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(currentHeight)
            if currentAspect > 1.45 {
                $0.bottom.equalTo(dotView.snp.bottom).offset(5)
            } else if currentAspect > 1.1 {
                $0.bottom.equalTo(buttonView.snp.top).offset(-5)
            } else {
                $0.centerY.equalToSuperview()
            }
        }

        if !animationImages.isEmpty && !imageView.activeAnimation {
            animationImages.count == 5 && post.frameIndexes!.count == 1 ? imageView.animate5FrameAlive(directionUp: true, counter: imageView.animationIndex) : imageView.animateGIF(directionUp: true, counter: imageView.animationIndex)  /// use old animation for 5 frame alives
        }
    }
    
    func layoutLikesAndComments() {
        let liked = post.likers.contains(uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = String(post.likers.count)
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
        if captionLabel != nil { captionLabel.attributedText = nil; captionLabel.removeFromSuperview() }
        if profileImage != nil { profileImage.image = UIImage(); profileImage.removeFromSuperview(); profileImage.sd_cancelCurrentImageLoad() }
        if usernameLabel != nil { usernameLabel.text = ""; usernameLabel.removeFromSuperview() }
        if timestampLabel != nil { timestampLabel.text = ""; timestampLabel.removeFromSuperview() }
        if elipsesButton != nil { elipsesButton.setImage(UIImage(), for: .normal); elipsesButton.removeFromSuperview() }
        if imageView != nil { for sub in imageView.subviews { sub.removeFromSuperview() }}
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0; imageView.removeFromSuperview() }
        if dotView != nil { for sub in dotView.subviews {sub.removeFromSuperview()}}
    }
    
    func resetImageInfo() {
        /// reset for fields that are set after image fetch (right now just called on cell init)
        if imageView != nil { imageView.image = UIImage(); imageView.animationImages?.removeAll(); imageView.animationIndex = 0 }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageManager.cancelAll()
    }
}

/// action methods
extension PostCell {
    @objc func userTap() {
        if post.userInfo == nil { return }
        openProfile(user: post.userInfo!)
    }
    
    @objc func spotTap() {
        if let postVC = viewContainingController() as? PostController {
            let spotVC = SpotPageController(mapPost: post, presentedDrawerView: postVC.containerDrawerView)
            postVC.containerDrawerView?.showCloseButton = false
            postVC.navigationController?.pushViewController(spotVC, animated: true)
        }
    }
    
    @objc func mapTap() {
        if post.mapID ?? "" == "" { return }
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openMap(mapID: post.mapID!)
        }
    }
    
    func openProfile(user: UserProfile) {
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openProfile(user: user, openComments: false)
        }
    }
    
    @objc func captionTap(_ sender: UITapGestureRecognizer) {
        if tapInTagRect(sender: sender) {
            return
        } else if overflow {
            expandCaption()
        } else if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow, animated: true)
        }
    }
    
    func tapInTagRect(sender: UITapGestureRecognizer) -> Bool {
        for r in tagRect {
            if r.rect.contains(sender.location(in: sender.view)) {
                /// open tag from friends list
                if let friend = UserDataModel.shared.userInfo.friendsList.first(where: {$0.username == r.username}) {
                    openProfile(user: friend)
                    return true
                } else {
                    /// pass blank user object to open func, run get user func on profile load
                    let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                    self.openProfile(user: user)
                }
            }
        }
        return false
    }
    
    func expandCaption() {
        let newHeight = getCaptionHeight(caption: post.caption, fontSize: 14.5, maxCaption: 0)
        captionLabel.numberOfLines = 0
        captionLabel.lineBreakMode = .byWordWrapping
        captionLabel.snp.updateConstraints { $0.height.equalTo(newHeight) }
        overflow = false
        addCaptionAttString()
    }
    
    @objc func commentsTap(_ sender: UIButton) {
        if let postVC = self.viewContainingController() as? PostController {
            postVC.openComments(row: globalRow, animated: true)
        }
    }
        
    @objc func nextTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }
        if (post.selectedImageIndex! < (post.frameIndexes?.count ?? 0) - 1) && imageFetched {
            nextImage()
            
        } else if postVC.selectedPostIndex < postVC.postsList.count - 1 {
            nextPost()
            
        } else {
            exitPosts()
        }
    }
    
    @objc func previousTap(_ sender: UIButton) {
        
        guard let postVC = viewContainingController() as? PostController else { return }

        if post.selectedImageIndex! > 0 {
            previousImage()
            
        } else if postVC.selectedPostIndex > 0 {
            previousPost()
        
        } else {
            exitPosts()
        }
    }
    
    func exitPosts() {
        Mixpanel.mainInstance().track(event: "PostPageRemove")

        guard let postVC = self.viewContainingController() as? PostController else { return }
        postVC.exitPosts()
    }
    
    func nextImage() {
        incrementImage(index: 1)
    }
    
    func previousImage() {
        incrementImage(index: -1)
    }
    
    func incrementImage(index: Int) {
        post.selectedImageIndex! += index
        setCurrentImage()
        
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.postsList[postVC.selectedPostIndex].selectedImageIndex! += index
        addDotView()
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
    }
        
    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        if post.likers.contains(uid) { return }
        likePost()
    }
    
    @objc func likePost(_ sender: UIButton) {
        likePost()
    }
    
    func likePost() {
        post.likers.append(self.uid)
        likeButton.removeTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        layoutLikesAndComments()
        
        guard let postVC = viewContainingController() as? PostController else { return }
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": postVC.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
        
        DispatchQueue.global().async { self.likePostDB(post: self.post) }
    }
    
    @objc func unlikePost(_ sender: UIButton) {
        post.likers.removeAll(where: {$0 == self.uid})
        likeButton.removeTarget(self, action: #selector(unlikePost(_:)), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(likePost(_:)), for: .touchUpInside)
        layoutLikesAndComments()
        //update main data source -- send notification to map, update comments
        guard let postVC = viewContainingController() as? PostController else { return }
        let infoPass = ["post": self.post as Any, "id": vcid as Any, "index": postVC.selectedPostIndex as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
        
        let updatePost = post! /// local object
        /// run unlike function from functions
        DispatchQueue.global().async {
            self.db.collection("posts").document(updatePost.id!).updateData(["likers" : FieldValue.arrayRemove([self.uid])])
            let functions = Functions.functions()
            functions.httpsCallable("unlikePost").call(["postID": updatePost.id!, "posterID": updatePost.posterID, "likerID": self.uid]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
        incrementTopFriends(friendID: post.posterID, increment: -1)
    }
    
    @objc func elipsesTap() {
        /// action sheet with delete post or report post showing
        addActionSheet()
    }
}

/// database methods
extension PostCell {
    func likePostDB(post: MapPost) {
        db.collection("posts").document(post.id!).updateData(["likers" : FieldValue.arrayUnion([self.uid])])
        if post.posterID == uid { return }
        
        var likeNotiValues: [String: Any] = [
            "imageURL": post.imageURLs.first ?? "",
            "originalPoster": post.userInfo?.username ?? "",
            "postID": post.id ?? "",
            "seen": false,
            "senderID": self.uid,
            "senderUsername": UserDataModel.shared.userInfo.username,
            "spotID": post.spotID ?? "",
            "timestamp": Timestamp(date: Date()),
            "type": "like"
        ] as [String: Any]
        db.collection("users").document(post.posterID).collection("notifications").addDocument(data: likeNotiValues)
        likeNotiValues["type"] = "likeOnAdd"
        for user in post.taggedUserIDs ?? [] {
            db.collection("users").document(user).collection("notifications").addDocument(data: likeNotiValues)
        }
        
        incrementTopFriends(friendID: post.posterID, increment: 1)
    }
}