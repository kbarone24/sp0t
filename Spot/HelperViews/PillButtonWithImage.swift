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
    enum IconOrientation {
        case left
        case right
    }

    private lazy var gradientView = UIView()
    private lazy var containerView = UIView()
    private lazy var icon = UIImageView()
    lazy var label: UILabel = UILabel()

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                alpha = 0.6
            } else {
                alpha = 1.0
            }
        }
    }

    init(backgroundColor: UIColor, image: UIImage?, title: String, titleColor: UIColor, iconOrientation: IconOrientation? = .left, font: UIFont? = SpotFonts.SFCompactRoundedBold.fontWith(size: 15)) {
        super.init(frame: .zero)

        layer.cornerRadius = 12
        layer.masksToBounds = true
        self.backgroundColor = backgroundColor

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        containerView.addSubview(label)
        label.text = title
        label.textColor = titleColor
        label.font = font

        containerView.addSubview(icon)
        icon.image = image

        switch iconOrientation {
        case .left:
            label.snp.makeConstraints {
                $0.trailing.centerY.equalToSuperview()
            }

            icon.snp.makeConstraints {
                $0.trailing.equalTo(label.snp.leading).offset(-8)
                $0.centerY.leading.equalToSuperview()
            }
        case .right:
            icon.snp.makeConstraints {
                $0.trailing.centerY.equalToSuperview()
            }

            label.snp.makeConstraints {
                $0.trailing.equalTo(icon.snp.leading).offset(-8)
                $0.leading.equalToSuperview()
                $0.centerY.equalToSuperview().offset(2)
            }
        default:
            return
        }
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
