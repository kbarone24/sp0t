//
//  MapPostWindowLarge.swift
//  Spot
//
//  Created by Kenny Barone on 1/31/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation

import UIKit

class MapPostWindowLarge: UIView {

    @IBOutlet weak var galleryImage: UIImageView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var tagImage: UIImageView!
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var spotName: UILabel!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var numLikes: UILabel!
    @IBOutlet weak var commentButton: UIButton!
    @IBOutlet weak var numComments: UILabel!
        
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "MapPostWindowLarge", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
