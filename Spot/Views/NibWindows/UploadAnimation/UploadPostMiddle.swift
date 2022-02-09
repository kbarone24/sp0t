//
//  UploadPostMiddle.swift
//  Spot
//
//  Created by Kenny Barone on 12/15/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadPostMiddle: UIView {
    
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var postBackground: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "UploadPostMiddle", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
