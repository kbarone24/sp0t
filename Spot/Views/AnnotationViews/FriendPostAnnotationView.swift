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
    lazy var imageManager = SDWebImageManager()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        canShowCallout = false
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
        
        let nibView = loadNib(post: post, cluster: cluster, moreText: moreText)
        id = post.id!
        
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
        
    func loadNib(post: MapPost, cluster: Bool, moreText: String) -> FriendPostView {
        let infoWindow = FriendPostView.instanceFromNib() as! FriendPostView
        infoWindow.clipsToBounds = false
        
        infoWindow.backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        infoWindow.postImage.layer.cornerRadius = 57/2
        infoWindow.usernameView.layer.cornerRadius = 5
        
        infoWindow.username.text = post.userInfo!.username
        infoWindow.username.font = UIFont(name: "SFCompactText-Bold", size: 11.5)
        infoWindow.username.numberOfLines = 1
        infoWindow.username.sizeToFit()
        
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
}

class PostAnnotation: MKPointAnnotation {
    var postID: String = ""
    override init() {
        super.init()
    }
}
