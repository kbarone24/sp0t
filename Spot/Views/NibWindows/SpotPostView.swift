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
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var imageMask: UIView!
    @IBOutlet weak var replayIcon: UIImageView!
    @IBOutlet weak var postCount: UILabel!
    @IBOutlet weak var spotIcon: UIImageView!
    @IBOutlet weak var spotLabel: UILabel!
    
    @IBOutlet weak var avatarView: RightAlignedAvatarView!
    @IBOutlet weak var usernameLabel: UsernameLabel!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SpotPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
    
    func resizeView(seen: Bool) {
        if seen {
            backgroundImage.frame = CGRect(x: backgroundImage.frame.minX, y: backgroundImage.frame.minY, width: backgroundImage.frame.width - 8, height: backgroundImage.frame.height - 8)
            postImage.frame = CGRect(x: postImage.frame.minX, y: postImage.frame.minY, width: postImage.frame.width - 8, height: postImage.frame.height - 8)
        }
        let viewWidth = max(spotLabel.bounds.width, backgroundImage.bounds.width, (usernameLabel.bounds.width + 24.5) * 2)
        let viewHeight = backgroundImage.isHidden ? 16 : bounds.height
        frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        
        backgroundImage.frame = CGRect(x: (bounds.width - backgroundImage.bounds.width)/2, y: backgroundImage.frame.minY, width: backgroundImage.bounds.width, height: backgroundImage.bounds.height)
        spotIcon.frame = CGRect(x: backgroundImage.frame.midX - spotIcon.bounds.width/2, y: backgroundImage.frame.maxY - 4.23, width: spotIcon.bounds.width, height: spotIcon.bounds.height)
        postImage.frame = CGRect(x: (bounds.width - postImage.bounds.width)/2, y: postImage.frame.minY, width: postImage.bounds.width, height: postImage.bounds.height)
        imageMask.frame = postImage.frame
        replayIcon.frame = CGRect(x: postImage.frame.minX + 15.5, y: postImage.frame.minY + 13, width: 27.7, height: 31)
        postCount.frame = CGRect(x: backgroundImage.frame.minX + 39, y: postCount.frame.minY, width: postCount.frame.width, height: postCount.frame.height)
                

        let spotY = backgroundImage.isHidden ? 0 : spotIcon.frame.maxY + 2
        spotLabel.frame = CGRect(x: (bounds.width - spotLabel.bounds.width)/2, y: spotY, width: spotLabel.bounds.width, height: spotLabel.bounds.height)
        avatarView.frame = CGRect(x: (spotIcon.frame.maxX + 25) - avatarView.frame.width, y: spotIcon.frame.maxY - 40, width: avatarView.frame.width, height: avatarView.frame.height)
        usernameLabel.repositionSubviews(minX: avatarView.frame.maxX - 12, minY: avatarView.frame.minY + 7)
    }
}
