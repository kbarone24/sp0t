//
//  UploadWindowMiddle.swift
//  Spot
//
//  Created by Kenny Barone on 12/13/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadWindowMiddle: UIView {
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "UploadWindowMiddle", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}

