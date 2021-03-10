//
//  MapTarget.swift
//  Spot
//
//  Created by kbarone on 7/7/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class MapTarget: UIView {
    
    @IBOutlet weak var spotNameLabel: UILabel!
    @IBOutlet weak var spotBannerBackground: UIImageView!
    @IBOutlet weak var targetIcon: UIImageView!
    @IBOutlet weak var bannerTriangle: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "MapTarget", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }

    func resizeBanner(width: CGFloat) {
        
        let initialX = self.frame.minX
        let initialWidth = self.frame.width
        let widthAdjustment = initialWidth - width
                
        self.frame = CGRect(x: initialX + widthAdjustment/2 - 10, y: self.frame.minY, width: width + 20, height: self.frame.height)
        
        spotBannerBackground.frame = CGRect(x: 0, y: spotBannerBackground.frame.minY, width: self.frame.width, height: spotBannerBackground.frame.height)
        spotBannerBackground.layer.cornerRadius = 7.5
        
        spotNameLabel.frame = CGRect(x: 5, y: spotNameLabel.frame.minY, width: self.frame.width - 10, height: 16)
        
        targetIcon.frame = CGRect(x: 100 - widthAdjustment/2 + 10, y: 47, width: 23, height: 17)
        bannerTriangle.frame = CGRect(x: 108 - widthAdjustment/2 + 10, y: 47, width: 7.2, height: 5.75)
        bannerTriangle.transform = CGAffineTransform(translationX: 0.25, y: 0.25)
        self.bringSubviewToFront(bannerTriangle)
        
    }
}
