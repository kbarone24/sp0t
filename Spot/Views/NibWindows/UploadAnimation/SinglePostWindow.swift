//
//  SinglePostWindow.swift
//  Spot
//
//  Created by Kenny Barone on 1/17/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
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
