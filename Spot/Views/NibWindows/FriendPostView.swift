//
//  FriendPostView.swift
//  Spot
//
//  Created by Kenny Barone on 7/29/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class FriendPostView: UIView {
    @IBOutlet private weak var backgroundImage: UIImageView!
    @IBOutlet private weak var postImage: UIImageView!
    @IBOutlet private weak var imageMask: UIView!
    @IBOutlet private weak var replayIcon: UIImageView!
    @IBOutlet private weak var postCount: UILabel!

    @IBOutlet private weak var avatarView: ImageAvatarView!
    @IBOutlet private weak var usernameLabel: UsernameLabel!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "FriendPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView ?? UIView()
    }

    func setValues(post: MapPost, count: Int, moreText: String) {
        backgroundImage.image = post.seen ? UIImage(named: "SeenPostBackground") : UIImage(named: "NewPostBackground")
        postImage.layer.cornerRadius = post.seen ? 67 / 2 : 75 / 2

        imageMask.layer.cornerRadius = 67 / 2
        imageMask.isHidden = !post.seen
        replayIcon.isHidden = !post.seen

        if count > 1 {
            postCount.backgroundColor = post.seen ? .white : UIColor(named: "SpotGreen")
            postCount.layer.cornerRadius = 10
            postCount.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
            postCount.text = String(count)
        } else {
            postCount.isHidden = true
        }

        usernameLabel.setUp(post: post, moreText: moreText, spotAnnotation: false)
        resizeView(seen: post.seen)
    }

    func setAvatarView(avatarURLs: [String], completion: @escaping(_ success: Bool) -> Void) {
        avatarView.setUp(avatarURLs: avatarURLs, annotation: true) { _ in
            self.bringSubviewToFront(self.avatarView)
            completion(true)
            return
        }
    }

    func setPostImage(image: UIImage) {
        postImage.image = image
    }

    func resizeView(seen: Bool) {
        if seen {
            backgroundImage.frame = CGRect(x: backgroundImage.frame.minX, y: backgroundImage.frame.minY, width: backgroundImage.frame.width - 8, height: backgroundImage.frame.height - 8)
            postImage.frame = CGRect(x: postImage.frame.minX, y: postImage.frame.minY, width: postImage.frame.width - 8, height: postImage.frame.height - 8)
        }

        let viewWidth = max(usernameLabel.bounds.width, avatarView.bounds.width)
        frame = CGRect(x: 0, y: 0, width: viewWidth, height: bounds.height)

        backgroundImage.frame = CGRect(x: (bounds.width - backgroundImage.bounds.width) / 2, y: backgroundImage.frame.minY, width: backgroundImage.bounds.width, height: backgroundImage.bounds.height)
        postImage.frame = CGRect(x: (bounds.width - postImage.bounds.width) / 2, y: postImage.frame.minY, width: postImage.bounds.width, height: postImage.bounds.height)
        imageMask.frame = postImage.frame
        replayIcon.frame = CGRect(x: postImage.frame.midX - 27.7 / 2, y: postImage.frame.midY - 15.5, width: 27.7, height: 31)
        postCount.frame = CGRect(x: backgroundImage.frame.minX + 49, y: postCount.frame.minY, width: postCount.frame.width, height: postCount.frame.height)

        //  need to slide up avatar view in case post already seen (smaller post frame)
        avatarView.frame = CGRect(x: (bounds.width - avatarView.bounds.width) / 2, y: backgroundImage.frame.maxY - 2, width: avatarView.bounds.width, height: avatarView.frame.height)
        usernameLabel.repositionSubviews(minX: (viewWidth - usernameLabel.bounds.width) / 2, minY: avatarView.frame.maxY - 5)
    }
}
