//
//  File.swift
//  Spot
//
//  Created by Kenny Barone on 1/18/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import SDWebImage

class StandardPostAnnotationView: MKAnnotationView {
    
    var smallImage: UIImage!
    var postID = ""
    var post: MapPost!
    var imageManager: SDWebImageManager!
    var lastTapTimestamp: TimeInterval = 0
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .none
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSmallImage(post: MapPost) {
                
        postID = post.id!
        self.post = post
        
        imageManager = SDWebImageManager()
        let nibView = loadSmallPostNib()
        
        isEnabled = true
        centerOffset = CGPoint(x: 0, y: -21)
        image = nibView.asImage() /// set image immediately to avoid lag on post frame load
        
        var count = 0

        // load tagImage if not stored locally
        let tagImage = post.tag ?? "" == "" ? UIImage() : Tag(name: post.tag!).image
        if tagImage == UIImage() && post.tag != "" && post.tag != nil {
            loadTagImage(tag: post.tag!) { [weak self] image in
                guard let self = self else { return }
                nibView.tagImage.image = image
                count += 1
                if count == 2 { let nibImage = nibView.asImage(); self.image = nibImage }
            }
            
        } else {
            nibView.tagImage.image = tagImage
            count += 1
        }

        // load post image
        loadPostAnnotationImage(post: post) { [weak self] (image) in
            guard let self = self else { return }
            self.smallImage = image
            nibView.galleryImage.image = image
            count += 1
            if count == 2 { let nibImage = nibView.asImage(); self.image = nibImage }
        }
    }
    
    func updateLargeImage(post: MapPost, animated: Bool) {
        
        postID = post.id!
        self.post = post
        
        imageManager = SDWebImageManager()
        let nibView = loadLargePostNib()
        nibView.galleryImage.image = smallImage != nil ? smallImage : UIImage() /// set to small image for image expand then
    
        self.isEnabled = true
        
        /// set large image to complete
        setLargeImage(nibView: nibView, animated: animated)

        // load post image
        var count = 0
        let tagImage = post.tag ?? "" == "" ? UIImage(named: "FeedSpotIcon") : Tag(name: post.tag!).image
        
        if tagImage == UIImage() && post.tag != "" && post.tag != nil {
            loadTagImage(tag: post.tag!) { [weak self] image in
                guard let self = self else { return }
                nibView.tagImage.image = image
                count += 1
                if count == 2 { self.setLargeImage(nibView: nibView, animated: animated) }
            }
            
        } else {
            nibView.tagImage.image = tagImage
            count += 1
        }

        // load post image
        loadPostAnnotationImage(post: post) { [weak self] (image) in
            guard let self = self else { return }
            
            nibView.galleryImage.image = image
            count += 1
            self.setLargeImage(nibView: nibView, animated: animated)
        }
    }
    
    func setLargeImage(nibView: UIView, animated: Bool) {
        
        let nibImage = nibView.asImage()
        self.image = nibImage

        UIView.animate(withDuration: animated ? 0.25 : 0.0, delay: 0.0, options: [.beginFromCurrentState, .curveLinear]) {
            self.transform = .identity.translatedBy(x: 0, y: -43.5)
        }
        smallImage = nil
    }
    
    func loadPostAnnotationImage(post: MapPost, completion: @escaping (_ image: UIImage) -> Void) {
        
        guard let url = URL(string: post.imageURLs.first ?? "") else { completion(UIImage()); return }
        if imageManager == nil { imageManager = SDWebImageManager() }
        
        let width: CGFloat = 100
        let transformer = SDImageResizingTransformer(size: CGSize(width: width, height: width * 1.5), scaleMode: .aspectFill)
        imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
            let image = image ?? UIImage()
            completion(image)
        }
    }
    
    func loadTagImage(tag: String, completion: @escaping (_ image: UIImage) -> Void) {
        
        let tag = Tag(name: tag)
        /// get tag image url from db and update image
        tag.getImageURL { [weak self] urlString in
            guard let self = self else { return }

            if self.imageManager == nil { self.imageManager = SDWebImageManager() }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 60, height: 60), scaleMode: .aspectFill)
            self.imageManager.loadImage(with: URL(string: urlString), options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard self != nil else { return }
                let image = image ?? UIImage()
                completion(image)
            }
        }
    }
    
    func loadSmallPostNib() -> MapPostWindow {
        
        let infoWindow = MapPostWindow.instanceFromNib() as! MapPostWindow
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.layer.cornerRadius = 3
        infoWindow.galleryImage.clipsToBounds = true
        infoWindow.bringSubviewToFront(infoWindow.tagImage)
        return infoWindow
    }
    
    func loadLargePostNib() -> MapPostWindowLarge {
        
        let infoWindow = MapPostWindowLarge.instanceFromNib() as! MapPostWindowLarge
        infoWindow.clipsToBounds = true
        
        infoWindow.galleryImage.contentMode = .scaleAspectFill
        infoWindow.galleryImage.layer.cornerRadius = 14
        infoWindow.galleryImage.clipsToBounds = true
        
        infoWindow.username.text = post.userInfo.username
        infoWindow.username.layer.cornerRadius = 5
        infoWindow.username.sizeToFit()
        infoWindow.username.frame = CGRect(x: infoWindow.username.frame.minX - 4, y: infoWindow.username.frame.minY - 1, width: infoWindow.username.frame.width + 8, height: infoWindow.username.frame.height + 2)
        
        let strokeTextAttributes = [
          NSAttributedString.Key.strokeColor : UIColor.black,
          NSAttributedString.Key.foregroundColor : UIColor.white,
          NSAttributedString.Key.strokeWidth : -0.7]
          as [NSAttributedString.Key : Any]
        infoWindow.spotName.attributedText = NSMutableAttributedString(string: post.spotName ?? "", attributes: strokeTextAttributes)
        infoWindow.spotName.sizeToFit()
        if infoWindow.spotName.frame.width > infoWindow.bounds.width - 45 { infoWindow.spotName.frame = CGRect(x: infoWindow.spotName.frame.minX, y: infoWindow.spotName.frame.minY, width: infoWindow.bounds.width - 45, height: infoWindow.spotName.bounds.height)}

        let totalWidth = 23 + infoWindow.spotName.frame.width
        infoWindow.tagImage.frame = CGRect(x: (infoWindow.frame.width - totalWidth) / 2, y: infoWindow.tagImage.frame.minY, width: infoWindow.tagImage.frame.width, height: infoWindow.tagImage.frame.height)
        infoWindow.spotName.frame = CGRect(x: infoWindow.tagImage.frame.maxX + 4, y: infoWindow.spotName.frame.minY, width: infoWindow.spotName.frame.width, height: infoWindow.spotName.frame.height)
        
        let commentCount = max(post.commentList.count - 1, 0)
        infoWindow.numComments.text = String(commentCount)
        
        infoWindow.numLikes.text = String(post.likers.count)
        
        let liked = post.likers.contains(UserDataModel.shared.uid)
        let likeImage = liked ? UIImage(named: "MapLikeFilled") : UIImage(named: "MapLike")
        infoWindow.likeButton.setImage(likeImage, for: .normal)

      ///  infoWindow.bringSubviewToFront(infoWindow.tagImage)
        return infoWindow
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        if imageManager != nil { imageManager.cancelAll(); imageManager = nil }
        if smallImage != nil { smallImage = UIImage() }
        if image != nil { image = nil }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if (hitView != nil) {  self.superview?.bringSubviewToFront(self) }
        return hitView
    }
        
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        if event?.timestamp == lastTapTimestamp { return false }
        if self.bounds.height < 60 { return false }
        
        /// check if point is inside like or comment frame
        if point.x > 136 && point.x < 176 && point.y > 63 && point.y < 99 {
            // like tap
            lastTapTimestamp = event?.timestamp ?? 0
            let uid = UserDataModel.shared.uid
            if post.likers.contains(uid) { post.likers.removeAll(where: {$0 == uid})} else { post.likers.append(uid) }
            let infoPass = ["post": self.post as Any, "id": "map" as Any] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
            return true
            
        } else if point.x > 136 && point.x < 176 && point.y > 105 && point.y < 141 {
            // comment tap
            lastTapTimestamp = event?.timestamp ?? 0
            guard let mapVC = viewContainingController() as? MapViewController else { return false }
            mapVC.openPosts(row: mapVC.selectedFeedIndex, openComments: true)
            return true
            
        } else if point.x > 52 && point.x < 143 && point.y > 23 && point.y < 138 {
            // post frame tap
            lastTapTimestamp = event?.timestamp ?? 0
            guard let mapVC = viewContainingController() as? MapViewController else { return false }
            mapVC.openPosts(row: mapVC.selectedFeedIndex, openComments: false)
            return true
        }
        return false
    }
}
