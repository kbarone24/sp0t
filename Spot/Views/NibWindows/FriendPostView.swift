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
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var imageMask: UIView!
    @IBOutlet weak var replayIcon: UIImageView!
    @IBOutlet weak var postCount: UILabel!

    @IBOutlet weak var avatarView: ImageAvatarView!
    @IBOutlet weak var usernameLabel: UsernameLabel!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "FriendPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
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

        ///  need to slide up avatar view in case post already seen (smaller post frame)
        avatarView.frame = CGRect(x: (bounds.width - avatarView.bounds.width) / 2, y: backgroundImage.frame.maxY - 2, width: avatarView.bounds.width, height: avatarView.frame.height)
        usernameLabel.repositionSubviews(minX: (viewWidth - usernameLabel.bounds.width) / 2, minY: avatarView.frame.maxY - 5)
    }
}
