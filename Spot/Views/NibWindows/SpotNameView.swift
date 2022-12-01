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
    @IBOutlet private weak var spotLabel: UILabel!
    @IBOutlet private weak var spotIcon: UIImageView!

    class func instanceFromNib() -> UIView {
        return UINib(nibName: "SpotNameView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView ?? UIView()
    }

    func setUp(spotName: String, poiCategory: POICategory?) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.strokeColor: UIColor.white,
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.strokeWidth: -3.8,
            NSAttributedString.Key.font: UIFont(name: "UniversLT-ExtraBlack", size: 13) as Any
        ]
        spotLabel.attributedText = NSAttributedString(string: spotName, attributes: attributes)
        spotLabel.sizeToFit()

        var iconWidth: CGFloat = 0
        var iconWithSpacing: CGFloat = 0
        if let poiCategory {
            iconWidth = 17
            iconWithSpacing = 20.5
            spotIcon.image = POIImageFetcher().getPOIImage(category: poiCategory)
        } else {
            spotIcon.image = UIImage()
        }

        frame = CGRect(x: 0, y: 0, width: spotLabel.bounds.width + iconWithSpacing, height: bounds.height)
        spotIcon.frame = CGRect(x: 0, y: 0, width: iconWidth, height: iconWidth)
        spotLabel.frame = CGRect(x: iconWithSpacing, y: 1.5, width: spotLabel.bounds.width, height: spotLabel.bounds.height)
    }
}
