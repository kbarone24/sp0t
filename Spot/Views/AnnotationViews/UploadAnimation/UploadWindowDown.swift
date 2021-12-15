//
//  UploadWindowDown.swift
//  Spot
//
//  Created by Kenny Barone on 12/10/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadWindowDown: UIView {
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "UploadWindowDown", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}

