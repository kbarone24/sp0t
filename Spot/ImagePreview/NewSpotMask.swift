//
//  NewSpotMask.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class NewSpotMask: UIView {
    private lazy var bottomMask = UIView()
    override func layoutSubviews() {
        if bottomMask.superview != nil { return }

        addSubview(bottomMask)
        bottomMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let layer = CAGradientLayer()
        layer.frame = bounds
        layer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor,
            UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.8).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.locations = [0, 0.2, 1]
        bottomMask.layer.addSublayer(layer)
    }
}

