//
//  LocationPickerWindow.swift
//  Spot
//
//  Created by Kenny Barone on 7/7/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class LocationPickerWindow: UIView {

    @IBOutlet weak var postImage: UIImageView!
    @IBOutlet weak var postBackground: UIImageView!
    @IBOutlet weak var postAddress: UILabel!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "LocationPickerWindow", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
