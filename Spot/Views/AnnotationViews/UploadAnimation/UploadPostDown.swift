//
//  UploadPostDown.swift
//  Spot
//
//  Created by Kenny Barone on 12/10/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadPostDown: UIView {
    
    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var postBackground: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "UploadPostDown", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
