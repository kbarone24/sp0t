//
//  GradientLabel.swift
//  Spot
//
//  Created by Kenny Barone on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class GradientLabel: UILabel {
    @IBInspectable var topColor: UIColor = .black {
        didSet { setNeedsLayout() }
    }

    @IBInspectable var bottomColor: UIColor = .white {
        didSet { setNeedsLayout() }
    }

    init(topColor: UIColor, bottomColor: UIColor, font: UIFont?) {
        super.init(frame: .zero)
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.font = font
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTextColor()
    }

    private func updateTextColor() {
        let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
            let colors = [topColor.cgColor, bottomColor.cgColor]
            guard let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: nil) else { return }
            context.cgContext.drawLinearGradient(gradient,
                                                 start: CGPoint(x: bounds.midX, y: bounds.minY),
                                                 end: CGPoint(x: bounds.midX, y: bounds.maxY),
                                                 options: [])
        }

        textColor = UIColor(patternImage: image)
    }
}
// source: https://stackoverflow.com/questions/55923582/custom-uilabel-with-gradient-text-colour-always-become-black
