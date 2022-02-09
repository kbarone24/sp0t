//
//  UploadWindowUp.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/21.
//  Copyright © 2021 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class UploadWindowUp: UIView {
    class func instanceFromNib() -> UIView {
        return UINib(nibName: "UploadWindowUp", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }
}
