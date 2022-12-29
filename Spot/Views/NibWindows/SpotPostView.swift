//
//  MapPostView.swift
//  Spot
//
//  Created by Kenny Barone on 8/1/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotPostView: UIView {
    @IBOutlet private weak var backgroundImage: UIImageView!
    @IBOutlet private weak var postImage: UIImageView!
    @IBOutlet private weak var imageMask: UIView!
    @IBOutlet private weak var replayIcon: UIImageView!
    @IBOutlet private weak var postCount: UILabel!
    @IBOutlet private weak var spotIcon: UIImageView!
    @IBOutlet private weak var spotLabel: UILabel!

    @IBOutlet private weak var avatarView: RightAlignedAvatarView!
    @IBOutlet private weak var usernameLabel: UsernameLabel!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SpotPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView ?? UIView()
    }

    func setValues(post: MapPost, spotName: String, poiCategory: POICategory?, count: Int, moreText: String) {
        backgroundImage.image =
        post.seen ? UIImage(named: "SeenPostBackground") :
        post.privacyLevel == "invite" ? UIImage(named: "SecretPostBackground") :
        UIImage(named: "FriendsPostBackground")

        postImage.layer.cornerRadius = post.seen ? 67 / 2 : 75 / 2

        imageMask.layer.cornerRadius = 67 / 2
        imageMask.isHidden = !post.seen
        replayIcon.isHidden = !post.seen

        if count > 1 {
            postCount.backgroundColor =
            post.seen ? .white :
            post.privacyLevel == "invite" ? UIColor(named: "SpotPink") :
            UIColor(named: "SpotGreen")

            postCount.layer.cornerRadius = 10
            postCount.font = UIFont(name: "SFCompactText-Heavy", size: 12.5)
            postCount.text = String(count)
        } else {
            postCount.isHidden = true
        }

        if spotName != "" {
            /// bordered text
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key.strokeColor: UIColor.white,
                NSAttributedString.Key.foregroundColor: UIColor.black,
                NSAttributedString.Key.strokeWidth: -3.8,
                NSAttributedString.Key.font: UIFont(name: "UniversLT-ExtraBlack", size: 13) as Any
            ]
            spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
            spotLabel.sizeToFit()

            if let poiCategory {
                spotIcon.image = POIImageFetcher().getPOIImage(category: poiCategory)
            } else {
                spotIcon.image = UIImage()
            }

        } else {
            /// no spot attached to this post
            spotLabel.isHidden = true
            spotIcon.isHidden = true
        }

        usernameLabel.setUp(post: post, moreText: moreText, spotAnnotation: true)
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
            backgroundImage.frame = CGRect(x: backgroundImage.frame.minX, y: backgroundImage.frame.minY, width: backgroundImage.frame.width - 12, height: backgroundImage.frame.height - 12)
            postImage.frame = CGRect(x: postImage.frame.minX, y: postImage.frame.minY, width: postImage.frame.width - 12, height: postImage.frame.height - 12)
        }
        let iconWidth: CGFloat = spotIcon.isHidden || spotIcon.image == UIImage() ? 0 : 17
        let iconWithSpacing = iconWidth == 0 ? 0 : iconWidth + 3.5
        let viewWidth = max(spotLabel.bounds.width + iconWithSpacing, backgroundImage.bounds.width, (usernameLabel.bounds.width + 24.5) * 2)
        frame = CGRect(x: 0, y: 0, width: viewWidth, height: bounds.height)

        backgroundImage.frame = CGRect(x: (bounds.width - backgroundImage.bounds.width) / 2, y: 0, width: backgroundImage.bounds.width, height: backgroundImage.bounds.height)
        postImage.frame = CGRect(x: (bounds.width - postImage.bounds.width) / 2, y: 1.5, width: postImage.bounds.width, height: postImage.bounds.height)
        imageMask.frame = postImage.frame
        replayIcon.frame = CGRect(x: postImage.frame.midX - 27.7 / 2, y: postImage.frame.midY - 31 / 2, width: 27.7, height: 31)
        postCount.frame = CGRect(x: backgroundImage.frame.minX + 49, y: 0, width: postCount.frame.width, height: postCount.frame.height)

        let spotY = backgroundImage.frame.maxY + 4
        spotIcon.frame = CGRect(x: (bounds.width - spotLabel.bounds.width - iconWithSpacing) / 2, y: spotY, width: iconWidth, height: iconWidth)
        spotLabel.frame = CGRect(x: spotIcon.frame.minX + iconWithSpacing, y: spotY + 1.5, width: spotLabel.bounds.width, height: spotLabel.bounds.height)
        avatarView.frame = CGRect(x: (backgroundImage.frame.midX + 32) - avatarView.frame.width, y: backgroundImage.frame.maxY - 34, width: avatarView.frame.width, height: avatarView.frame.height)
        usernameLabel.repositionSubviews(minX: avatarView.frame.maxX - 12, minY: avatarView.frame.minY + 9)
    }
}
