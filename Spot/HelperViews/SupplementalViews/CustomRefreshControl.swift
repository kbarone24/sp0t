//
//  CustomRefreshControl.swift
//  Spot
//
//  Created by kbarone on 10/23/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CustomRefreshControl: UIRefreshControl {

    fileprivate let maxPullDistance: CGFloat = 150
    let imageView = UIImageView()

    override init() {
        super.init()
        imageView.frame = self.frame
        imageView.image = UIImage(named: "CustomActivityIndicator")
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func beginRefreshing() {
        isHidden = false
        rotate()
    }
    override func endRefreshing() {
        isHidden = true
        removeRotation()
    }

    func isRefreshing() -> Bool {
        if !isHidden {
            return true
        } else {
            return false
        }
    }
    private func rotate() {
        let rotation: CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        self.imageView.layer.add(rotation, forKey: "rotationAnimation")
    }

    private func removeRotation() {
        self.imageView.layer.removeAnimation(forKey: "rotationAnimation")
    }

}
