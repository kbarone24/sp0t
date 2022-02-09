//
//  TextPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 2/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import SDWebImage

class TextPostAnnotationView: MKAnnotationView {
    
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
        let nibView = loadSmallNib()
        
        self.isEnabled = true
        centerOffset = CGPoint(x: 0, y: -5)

        // load post image
        let tagImage = post.tag ?? "" == "" ? UIImage(named: "FeedSpotIcon") : Tag(name: post.tag!).image
        
        if tagImage == UIImage() && post.tag != "" && post.tag != nil {
            loadTagImage(tag: post.tag!) { [weak self] image in
                guard let self = self else { return }
                nibView.tagImage.image = image
                let nibImage = nibView.asImage()
                self.image = nibImage
            }

        } else {
            nibView.tagImage.image = tagImage
            let nibImage = nibView.asImage()
            self.image = nibImage
        }
    }
    
    func updateLargeImage(post: MapPost, animated: Bool) {
        postID = post.id!
        self.post = post
        
        centerOffset = CGPoint(x: 0, y: -45)
        
        let nibView = loadLargeNib()
        image = nibView.asImage()
        
        UIView.animate(withDuration: animated ? 0.3 : 0.0) {
            self.transform = .identity
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

    func loadSmallNib() -> TextPostWindow {
        let infoWindow = TextPostWindow.instanceFromNib() as! TextPostWindow
        infoWindow.clipsToBounds = true
        return infoWindow
    }
    
    func loadLargeNib() -> TextPostWindowLarge {
        
        let infoWindow = TextPostWindowLarge.instanceFromNib() as! TextPostWindowLarge
        infoWindow.clipsToBounds = true
        
        infoWindow.username.text = post.userInfo.username
        infoWindow.username.layer.cornerRadius = 5
        infoWindow.username.sizeToFit()
        infoWindow.username.frame = CGRect(x: infoWindow.username.frame.minX - 4, y: infoWindow.username.frame.minY - 1, width: infoWindow.username.frame.width + 8, height: infoWindow.username.frame.height + 2)

        infoWindow.caption.text = post.caption
        
        let commentCount = max(post.commentList.count - 1, 0)
        infoWindow.numComments.text = String(commentCount)
        
        infoWindow.numLikes.text = String(post.likers.count)
        
        let liked = post.likers.contains(UserDataModel.shared.uid)
        let likeImage = liked ? UIImage(named: "MapLikeFilled") : UIImage(named: "MapLike")
        infoWindow.likeButton.setImage(likeImage, for: .normal)
        
        return infoWindow
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if (hitView != nil) {  self.superview?.bringSubviewToFront(self) }
        return hitView
    }
        
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        
        if event?.timestamp == lastTapTimestamp { return false }
        if self.bounds.height < 50 { return false }

        /// check if point is inside like or comment frame
        print("x", point.x, "y", point.y)
        if point.x > 210 && point.x < 255 && point.y > 20 && point.y < 55 {
            print("like")
            // like tap
            lastTapTimestamp = event?.timestamp ?? 0
            let uid = UserDataModel.shared.uid
            if post.likers.contains(uid) { post.likers.removeAll(where: {$0 == uid})} else { post.likers.append(uid) }
            let infoPass = ["post": self.post as Any, "id": "map" as Any] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("PostLike"), object: nil, userInfo: infoPass)
            return true
            
        } else if point.x > 210 && point.x < 255 && point.y > 60 && point.y < 100 {
            // comment tap
            print("comment")
            lastTapTimestamp = event?.timestamp ?? 0
            guard let mapVC = viewContainingController() as? MapViewController else { return false }
            mapVC.openPosts(row: mapVC.selectedFeedIndex, openComments: true)
            return true
            
        } else if point.x > 40 && point.x < 210 && point.y > 17 && point.y < 106 {
            print("open")
            // post frame tap
            lastTapTimestamp = event?.timestamp ?? 0
            guard let mapVC = viewContainingController() as? MapViewController else { return false }
            mapVC.openPosts(row: mapVC.selectedFeedIndex, openComments: false)
            return true
        }
        return false
    }

}
