//
//  CustomActivityIndicator.swift
//  Spot
//
//  Created by kbarone on 10/23/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CustomActivityIndicator: UIView {
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame = frame
        imageView.image = UIImage(named: "LoadingIndicator")
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
    
    func startAnimating() {
        isHidden = false
        rotate()
    }
    func isAnimating() -> Bool {
        if !isHidden {
            return true
        } else {
            return false
        }
    }
    
    func stopAnimating() {
        isHidden = true
        removeRotation()
    }
    
    func rotate() {
        let rotation : CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 0.7
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        self.imageView.layer.add(rotation, forKey: "rotationAnimation")
    }
    
    func removeRotation() {
        self.imageView.layer.removeAnimation(forKey: "rotationAnimation")
    }

}
