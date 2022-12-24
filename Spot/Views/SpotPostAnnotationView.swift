//
//  MapPostAnnotationView.swift
//  Spot
//
//  Created by Kenny Barone on 8/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import MapKit
import UIKit
import SDWebImage

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

    func updateImage(posts: [MapPost], spotName: String, id: String, poiCategory: POICategory?, spotCluster: Bool) {
        self.id = id
        self.spotName = spotName
        /// only include unseen posts in cluster
        self.unseenPost = posts.contains(where: { !$0.seen })
        self.spotCluster = spotCluster
        self.postIDs = unseenPost ? posts.filter({ !$0.seen }).map { $0.id ?? "" } : posts.map({ $0.id ?? "" })
        let postCount = postIDs.count

        let post = posts.first
        if let post {
            /// load friend view if multiple spots in the cluster
            let nibView = spotCluster ? loadClusterNib(post: post, postCount: postCount, moreText: getMoreText(posts: posts)) :
            loadPostNib(post: post, spotName: spotName, poiCategory: poiCategory, postCount: postCount, moreText: getMoreText(posts: posts))
            if let nibView {
                self.image = nibView.asImage()

                guard let url = URL(string: post.imageURLs.first ?? "") else { image = nibView.asImage(); return }
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                self.imageManager.loadImage(with: url, options: .highPriority, context: [.imageTransformer: transformer], progress: nil) { [weak self] (image, _, _, _, _, _) in
                    guard let self = self else { return }
                    self.setPostImage(nibView: nibView, image: image ?? UIImage())
                }

                loadAvatarView(nibView: nibView, posts: posts)
            }
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
            nibView.setAvatarView(avatarURLs: avatarURLs) { _ in
                self.image = nibView.asImage()
            }
        } else if let nibView = nibView as? SpotPostView {
            nibView.setAvatarView(avatarURLs: avatarURLs) { _ in
                self.image = nibView.asImage()
            }
        }
    }

    func setPostImage(nibView: UIView, image: UIImage) {
        if let nibView = nibView as? SpotPostView {
            nibView.setPostImage(image: image)
        } else if let nibView = nibView as? FriendPostView {
            nibView.setPostImage(image: image)
        }
        self.image = nibView.asImage()
        self.centerOffset = CGPoint(x: 0, y: -20)
    }

    func loadPostNib(post: MapPost, spotName: String, poiCategory: POICategory?, postCount: Int, moreText: String) -> SpotPostView? {
        let infoWindow = SpotPostView.instanceFromNib() as? SpotPostView
        infoWindow?.setValues(post: post, spotName: spotName, poiCategory: poiCategory, count: postCount, moreText: moreText)
        infoWindow?.clipsToBounds = false
        return infoWindow
    }

    func loadClusterNib(post: MapPost, postCount: Int, moreText: String) -> FriendPostView? {
        let infoWindow = FriendPostView.instanceFromNib() as? FriendPostView
        infoWindow?.clipsToBounds = false
        infoWindow?.setValues(post: post, count: postCount, moreText: moreText)
        return infoWindow
    }

    func getMoreText(posts: [MapPost]) -> String {
        let posters = posts.map { $0.posterID }.uniqued()
        var moreText = ""
        if posters.count > 2 {
            moreText = "+ \(posters.count - 1) more"
        } else if posters.count > 1 {
            if let otherPost = posts.first(where: { $0.posterID != posts.first?.posterID ?? "" }) {
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
        return unseenPost ? 1_000 : spotName != "" ? 950 : 900
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
    lazy var id = ""
    lazy var type: AnnotationType = .name
    enum AnnotationType {
        case post
        case name
    }
    override init() {
        super.init()
    }
}
