//
//  MapPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 8/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import FirebaseUI

class SpotPostAnnotationView: MKAnnotationView {
    var id = ""
    var spotName = ""
    var postIDs: [String] = []

    var unseenPost = false
    var spotCluster = false
    
    lazy var imageManager = SDWebImageManager()
    unowned var mapView: MKMapView?
    
    override var clusteringIdentifier: String? {
        didSet {
            displayPriority = .required
            /// get clustering id if clustering is turned off
         //   displayPriority = clusteringIdentifier != nil ? .required : unseenPost ? .required : .defaultHigh //.init(rawValue: getPostRank(unseenPost: unseenPost, spotName: spotName))
        }
    }
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = false
        collisionMode = .circle
        addTap()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(posts: [MapPost], spotName: String, id: String, spotCluster: Bool) {
        self.id = id
        self.spotName = spotName
        /// only include unseen posts in cluster
        self.unseenPost = posts.contains(where: {!$0.seen})
        self.spotCluster = spotCluster
        self.postIDs = unseenPost ? posts.filter({!$0.seen}).map{$0.id!} : posts.map({$0.id!})
        let postCount = postIDs.count
        
        let post = posts.first
        if post != nil {
            /// load friend view if multiple spots in the cluster
            let nibView = spotCluster ? loadClusterNib(post: post!, postCount: postCount, moreText: getMoreText(posts: posts)) : loadPostNib(post: post!, spotName: spotName, postCount: postCount, moreText: getMoreText(posts: posts))
            self.image = nibView.asImage()
            
            guard let url = URL(string: post!.imageURLs.first ?? "") else { image = nibView.asImage(); return }
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
                guard let self = self else { return }
                self.setPostImage(nibView: nibView, image: image ?? UIImage())
            }
            
            loadAvatarView(nibView: nibView, posts: posts)
        }
        
    }
    
    func loadAvatarView(nibView: UIView, posts: [MapPost]) {
        /// set up avatar for cluster
        var avatarURLs = [posts[0].userInfo?.avatarURL ?? ""]
        for i in 1..<posts.count {
            let url = posts[i].userInfo?.avatarURL ?? ""
            if !avatarURLs.contains(url) { avatarURLs.append(posts[i].userInfo?.avatarURL ?? "") }
        }
        if let nibView = nibView as? FriendPostView {
            nibView.avatarView.setUp(avatarURLs: avatarURLs, annotation: true) { success in
                nibView.bringSubviewToFront(nibView.avatarView)
                self.image = nibView.asImage()
            }
        } else if let nibView = nibView as? SpotPostView {
            nibView.avatarView.setUp(avatarURLs: avatarURLs, annotation: true) { success in
                nibView.bringSubviewToFront(nibView.avatarView)
                self.image = nibView.asImage()
            }
        }
    }
    
    func setPostImage(nibView: UIView, image: UIImage) {
        if let nibView = nibView as? SpotPostView {
            nibView.postImage.image = image
        } else if let nibView = nibView as? FriendPostView {
            nibView.postImage.image = image
        }
        self.image = nibView.asImage()
        self.centerOffset = CGPoint(x: 0, y: -20)
    }
    
    func loadPostNib(post: MapPost, spotName: String, postCount: Int, moreText: String) -> SpotPostView {
        let infoWindow = SpotPostView.instanceFromNib() as! SpotPostView
        infoWindow.clipsToBounds = false
        infoWindow.backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = post.seen ? 67/2 : 75/2
        
        infoWindow.imageMask.layer.cornerRadius = 67/2
        infoWindow.imageMask.isHidden = !post.seen
        infoWindow.replayIcon.isHidden = !post.seen
        
        if postCount > 1 {
            infoWindow.postCount.backgroundColor = post.seen ? .white : UIColor(named: "SpotGreen")
            infoWindow.postCount.layer.cornerRadius = 10
            infoWindow.postCount.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
            infoWindow.postCount.text = String(postCount)
        } else {
            infoWindow.postCount.isHidden = true
        }
        
        if spotName != "" {
            /// bordered text
            let attributes: [NSAttributedString.Key : Any] = [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3,
                NSAttributedString.Key.font: UIFont(name: "SFCompactText-Heavy", size: 13.5)!
            ]
            infoWindow.spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
            infoWindow.spotLabel.sizeToFit()

        } else {
            /// no spot attached to this post
            infoWindow.spotLabel.isHidden = true
            infoWindow.spotIcon.isHidden = true
        }
        
        infoWindow.usernameLabel.setUp(post: post, moreText: moreText, spotAnnotation: true)
        infoWindow.resizeView(seen: post.seen)
        return infoWindow
    }
    
    func loadClusterNib(post: MapPost, postCount: Int, moreText: String) -> FriendPostView {
        let infoWindow = FriendPostView.instanceFromNib() as! FriendPostView
        infoWindow.clipsToBounds = false
        
        infoWindow.backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = post.seen ? 67/2 : 75/2
        
        infoWindow.imageMask.layer.cornerRadius = 67/2
        infoWindow.imageMask.isHidden = !post.seen
        infoWindow.replayIcon.isHidden = !post.seen
        
        if postCount > 1 {
            infoWindow.postCount.backgroundColor = post.seen ? .white : UIColor(named: "SpotGreen")
            infoWindow.postCount.layer.cornerRadius = 10
            infoWindow.postCount.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
            infoWindow.postCount.text = String(postCount)
        } else {
            infoWindow.postCount.isHidden = true
        }
        
        infoWindow.usernameLabel.setUp(post: post, moreText: moreText, spotAnnotation: false)
        infoWindow.resizeView(seen: post.seen)
        return infoWindow
    }

    func getMoreText(posts: [MapPost]) -> String {
        let posters = posts.map{$0.posterID}.uniqued()
        var moreText = ""
        if posters.count > 2 {
            moreText = "+ \(posters.count - 1) more"
        } else if posters.count > 1 {
            if let otherPost = posts.first(where: {$0.posterID != posts.first?.posterID ?? ""}) {
                moreText = "& \(otherPost.userInfo?.username ?? "")"
            }
        }
        return moreText
    }
    
    func addTap() {
        /// prevent map lag on selection
        let tap = UITapGestureRecognizer()
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        addGestureRecognizer(tap)
    }
    
    func getPostRank(unseenPost: Bool, spotName: String) -> Float {
        return unseenPost ? 1000 : spotName != "" ? 950 : 900
    }
}

extension SpotPostAnnotationView: UIGestureRecognizerDelegate {

    func toggleZoom() {
        mapView?.isZoomEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.mapView?.isZoomEnabled = true
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        toggleZoom()
        return false
    }
}

class SpotAnnotation: MKPointAnnotation {
    var id = ""
    var type: AnnotationType!
    enum AnnotationType {
        case post
        case name
    }
    override init() {
        super.init()
    }
}
