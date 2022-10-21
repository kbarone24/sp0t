//
//  SpotNameView.swift
//  Spot
//
//  Created by Kenny Barone on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotNameView: UIView {
    @IBOutlet weak var spotLabel: UILabel!
    @IBOutlet weak var spotIcon: UIImageView!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SpotNameView", bundle: nil).instantiate(withOwner: self, options: nil).first as! UIView
    }

    func resizeView() {
        frame = CGRect(x: 0, y: 0, width: spotLabel.bounds.width, height: bounds.height)
        spotLabel.frame = CGRect(x: 0, y: 8.5, width: spotLabel.bounds.width, height: spotLabel.bounds.height)
        spotIcon.frame = CGRect(x: spotLabel.bounds.width / 2 - 9, y: 0, width: spotIcon.bounds.width, height: spotIcon.bounds.height)
    }
}
