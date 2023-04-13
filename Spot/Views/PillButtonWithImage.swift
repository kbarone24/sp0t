//
//  PillButtonWithImage.swift
//  Spot
//
//  Created by Kenny Barone on 10/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PillButtonWithImage: UIButton {
    private lazy var gradientView = UIView()
    private lazy var containerView = UIView()
    private lazy var icon = UIImageView()
    lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        layer.cornerRadius = 12
        layer.masksToBounds = true

        gradientView.isHidden = true
        addSubview(gradientView)
        gradientView.isUserInteractionEnabled = false
        gradientView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        containerView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }

        containerView.addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing).offset(8)
            $0.centerY.trailing.equalToSuperview()
        }
    }

    func setUp(image: UIImage?, title: String, titleColor: UIColor) {
        icon.image = image
        label.text = title
        label.textColor = titleColor
    }

    func addGradient() {
        if gradientView.isHidden, !gradientView.bounds.isEmpty {
            let layer = CAGradientLayer()
            layer.frame = gradientView.bounds
            layer.colors = [
                UIColor(red: 0.379, green: 0.926, blue: 1, alpha: 1).cgColor,
                UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1).cgColor,
                UIColor(red: 0.225, green: 0.767, blue: 1, alpha: 1).cgColor,
            ]
            layer.locations = [0, 0.53, 1]
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
            gradientView.layer.addSublayer(layer)
            gradientView.isHidden = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
