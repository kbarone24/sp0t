//
//  SinglePost.swift
//  Spot
//
//  Created by kbarone on 7/28/20.
//  Copyright © 2020 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SinglePostWindow: UIView {
    
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var postBackground: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SinglePost", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
