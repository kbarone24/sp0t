//
//  TextPostWindow.swift
//  Spot
//
//  Created by Kenny Barone on 2/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class TextPostWindow: UIView {
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var tagImage: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "TextPostWindow", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}

