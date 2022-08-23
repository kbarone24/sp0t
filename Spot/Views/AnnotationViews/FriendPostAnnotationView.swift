//
//  FriendPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 7/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import FirebaseUI

class FriendPostAnnotationView: MKAnnotationView {
    var id = ""
    var postIDs: [String] = []
    
    lazy var imageManager = SDWebImageManager()
    unowned var mapView: MKMapView?
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
        addTap()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateImage(posts: [MapPost]) {
        let cluster = posts.count > 1
        let post = posts.first!
        let posters = posts.map{$0.posterID}.uniqued()
        
        var moreText = ""
        if posters.count > 2 {
            moreText = "+ \(posters.count - 1) more"
        } else if posters.count > 1 {
            if let otherPost = posts.first(where: {$0.posterID != post.posterID}) {
                moreText = "& \(otherPost.userInfo?.username ?? "")"
            }
        }
        
        let nibView = loadNib(post: post, postCount: posts.count, moreText: moreText)
        id = post.id!
        postIDs = posts.map{$0.id ?? ""}
        
        // load images
        guard let url = URL(string: post.imageURLs.first ?? "") else { image = nibView.asImage(); return }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, data, err, cache, download, url) in
            guard let self = self else { return }
            nibView.postImage.image = image
            self.image = nibView.asImage()
        }
        
        var avatarURLs = [post.userInfo?.avatarURL ?? ""]
        if cluster {
            for i in 1...posts.count - 1 {
                let url = posts[i].userInfo?.avatarURL ?? ""
                if !avatarURLs.contains(url) { avatarURLs.append(posts[i].userInfo?.avatarURL ?? "") }
            }
        }
        
        nibView.avatarView.setUp(avatarURLs: avatarURLs, annotation: true) { success in
            nibView.bringSubviewToFront(nibView.avatarView)
            self.image = nibView.asImage()
        }
        
        self.image = nibView.asImage()
    }
        
    func loadNib(post: MapPost, postCount: Int, moreText: String) -> FriendPostView {
        let infoWindow = FriendPostView.instanceFromNib() as! FriendPostView
        infoWindow.clipsToBounds = false
        
        infoWindow.backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = 57/2
        infoWindow.usernameView.layer.cornerRadius = 5
        
        infoWindow.imageMask.layer.cornerRadius = 57/2
        infoWindow.imageMask.isHidden = !post.seen
        infoWindow.replayIcon.isHidden = !post.seen
        
        infoWindow.username.text = post.userInfo!.username
        infoWindow.username.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
        infoWindow.username.numberOfLines = 1
        infoWindow.username.sizeToFit()
        
        if postCount > 1 {
            infoWindow.postCount.backgroundColor = post.seen ? .white : UIColor(named: "SpotGreen")
            infoWindow.postCount.layer.cornerRadius = 10
            infoWindow.postCount.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
            infoWindow.postCount.text = String(postCount)
        } else {
            infoWindow.postCount.isHidden = true
        }
        
        /// adjust for cluster
        let moreShowing = moreText != ""
        if moreShowing {
            infoWindow.timestamp.isHidden = true
            infoWindow.moreLabel.text = moreText
            infoWindow.moreLabel.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
            infoWindow.moreLabel.numberOfLines = 1
            infoWindow.moreLabel.sizeToFit()
            infoWindow.resizeUsernameMultiplePosters()
            
        } else {
            infoWindow.timestamp.toTimeString(timestamp: post.timestamp)
            infoWindow.timestamp.font = UIFont(name: "SFCompactText-Semibold", size: 10.5)
            infoWindow.timestamp.sizeToFit()
            infoWindow.moreLabel.isHidden = true
            infoWindow.resizeUsernameOnePoster()
        }
        
        return infoWindow
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
}

extension FriendPostAnnotationView: UIGestureRecognizerDelegate {

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

class PostAnnotation: MKPointAnnotation {
    var postID: String = ""
    override init() {
        super.init()
    }
}
