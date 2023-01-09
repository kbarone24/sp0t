//
//  CustomActivityIndicator.swift
//  Spot
//
//  Created by kbarone on 10/23/19.
//  Copyright © 2019 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class CustomActivityIndicator: UIView {

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView(image: nil)
    }

    init(image: UIImage) {
        super.init(frame: .zero)
        setUpView(image: image)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Has not been implemented.")
    }

    func setUpView(image: UIImage?) {
        imageView.frame = frame
        imageView.image = image == nil ? UIImage(named: "LoadingIndicator") : image
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }

    func startAnimating(duration: CFTimeInterval? = 0.7) {
        isHidden = false
        rotate(duration: duration ?? 0.7)
    }

    func isAnimating() -> Bool {
        return !isHidden
    }

    func stopAnimating() {
        isHidden = true
        removeRotation()
    }

    func rotate(duration: CFTimeInterval) {
        let rotation: CABasicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = duration
        rotation.isCumulative = true
        rotation.repeatCount = Float.greatestFiniteMagnitude
        self.imageView.layer.add(rotation, forKey: "rotationAnimation")
    }

    func removeRotation() {
        self.imageView.layer.removeAnimation(forKey: "rotationAnimation")
    }
}
