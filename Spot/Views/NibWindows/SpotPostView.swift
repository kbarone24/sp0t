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
    @IBOutlet weak var spotLabel: UILabel!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SpotPostView", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
    
    func resizeView() {
        let viewWidth = max(spotLabel.bounds.width, backgroundImage.bounds.width)
        let viewHeight = backgroundImage.isHidden ? 16 : bounds.height
        frame = CGRect(x: 0, y: 0, width: viewWidth, height: viewHeight)
        
        backgroundImage.frame = CGRect(x: (bounds.width - backgroundImage.bounds.width)/2, y: backgroundImage.frame.minY, width: backgroundImage.bounds.width, height: backgroundImage.bounds.height)
        postImage.frame = CGRect(x: (bounds.width - postImage.bounds.width)/2, y: postImage.frame.minY, width: postImage.bounds.width, height: postImage.bounds.height)
        
        let spotY = backgroundImage.isHidden ? 0 : spotLabel.frame.minY
        spotLabel.frame = CGRect(x: (bounds.width - spotLabel.bounds.width)/2, y: spotY, width: spotLabel.bounds.width, height: spotLabel.bounds.height)
    }
}
