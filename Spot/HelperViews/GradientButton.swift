//
//  GradientButton.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class GradientButton: UIButton {
    private lazy var gradientBackground = UIView()
    private lazy var pillBackground: UIView = {
        let view = UIView()
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()
    private lazy var icon = UIImageView()
    lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .black
        return label
    }()
    private let baseLayer: CAGradientLayer

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                alpha = 0.6
            } else {
                alpha = 1.0
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        addGradient()
    }

    init(layer: CAGradientLayer, image: UIImage?, text: String, cornerRadius: CGFloat, font: UIFont? = SpotFonts.SFCompactRoundedBold.fontWith(size: 15)) {
        baseLayer = layer
        super.init(frame: .zero)

        pillBackground.layer.cornerRadius = cornerRadius
        addSubview(pillBackground)
        pillBackground.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        pillBackground.addSubview(gradientBackground)
        gradientBackground.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        pillBackground.addSubview(label)
        label.text = text
        label.font = font
        let offset = image == nil ? 0 : 23/2
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(offset)
            $0.centerY.equalToSuperview()
        }

        if let image {
            pillBackground.addSubview(icon)
            icon.image = image
            icon.snp.makeConstraints {
                $0.trailing.equalTo(label.snp.leading).offset(-8)
                $0.centerY.equalTo(label)
            }
        }
    }

    private func addGradient() {
        layoutIfNeeded()
        for layer in gradientBackground.layer.sublayers ?? [] { layer.removeFromSuperlayer() }
        let layer = baseLayer
        layer.frame = gradientBackground.bounds
        gradientBackground.layer.insertSublayer(layer, at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
