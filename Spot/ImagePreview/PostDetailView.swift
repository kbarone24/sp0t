//
//  PostDetailView.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PostDetailView: UIView {
    lazy var bottomMask = UIView()
    override func layoutSubviews() {
        super.layoutSubviews()
        if bottomMask.superview != nil { return }
        bottomMask.isUserInteractionEnabled = false
        insertSubview(bottomMask, at: 0)
        bottomMask.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        let layer = CAGradientLayer()
        layer.frame = bounds
        layer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.4).cgColor,
          UIColor(red: 0, green: 0.0, blue: 0.0, alpha: 0.65).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.locations = [0, 0.5, 1]
        bottomMask.layer.addSublayer(layer)
    }
}
