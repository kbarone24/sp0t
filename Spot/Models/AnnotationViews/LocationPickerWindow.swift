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

    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var background: UIImageView!
    
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "LocationPickerWindow", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
