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
    
    @IBOutlet weak var avatarView: ImageAvatarView!
    @IBOutlet weak var usernameView: UIView!
    
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var moreLabel: UILabel!
    @IBOutlet weak var timestamp: UILabel!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "FriendPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
    
    func resizeUsernameOnePoster() {
        let newWidth = username.bounds.width + timestamp.bounds.width + 10
        resizeView(usernameWidth: newWidth)
    }
    
    func resizeUsernameMultiplePosters() {
        let newWidth = max(moreLabel.frame.width, username.frame.width) + 8
        resizeView(usernameWidth: newWidth)
    }
    
    func resizeView(usernameWidth: CGFloat) {
        let viewWidth = max(usernameWidth, avatarView.bounds.width)
        frame = CGRect(x: 0, y: 0, width: viewWidth, height: bounds.height)
        
        let usernameHeight = moreLabel.isHidden ? username.bounds.height + 4 : usernameView.bounds.height
        usernameView.frame = CGRect(x: (bounds.width - usernameWidth)/2, y: usernameView.frame.minY, width: usernameWidth, height: usernameHeight)
        username.frame = CGRect(x: 4, y: 2, width: username.bounds.width, height: username.bounds.height)
        timestamp.frame = CGRect(x: username.frame.maxX + 2, y: 2.5, width: timestamp.bounds.width, height: timestamp.bounds.height)
        moreLabel.frame = CGRect(x: 4, y: username.bounds.maxY, width: moreLabel.bounds.width, height: moreLabel.bounds.height)
        
        backgroundImage.frame = CGRect(x: (bounds.width - backgroundImage.bounds.width)/2, y: backgroundImage.frame.minY, width: backgroundImage.bounds.width, height: backgroundImage.bounds.height)
        postImage.frame = CGRect(x: (bounds.width - postImage.bounds.width)/2, y: postImage.frame.minY, width: postImage.bounds.width, height: postImage.bounds.height)
        imageMask.frame = postImage.frame
        replayIcon.frame = CGRect(x: postImage.frame.minX + 15.5, y: postImage.frame.minY + 13, width: 27.7, height: 31)

        avatarView.frame = CGRect(x: (bounds.width - avatarView.bounds.width)/2, y: avatarView.frame.minY, width: avatarView.bounds.width, height: avatarView.frame.height)
    }
}
