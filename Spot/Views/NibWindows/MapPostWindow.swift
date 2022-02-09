//
//  MapPostWindow.swift
//  Spot
//
//  Created by Kenny Barone on 1/18/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class MapPostWindow: UIView {

    @IBOutlet weak var galleryImage: UIImageView!
    @IBOutlet weak var tagImage: UIImageView!
    @IBOutlet weak var backgroundImage: UIImageView!
        
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "MapPostWindow", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
    
}
