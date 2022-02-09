//
//  TextPostWindowLarge.swift
//  Spot
//
//  Created by Kenny Barone on 2/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class TextPostWindowLarge: UIView {
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var numLikes: UILabel!
    @IBOutlet weak var commentButton: UIButton!
    @IBOutlet weak var numComments: UILabel!
    @IBOutlet weak var caption: UILabel!
    @IBOutlet weak var username: UILabel!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "TextPostWindowLarge", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}

