//
//  HomeScreenTableFooter.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeScreenTableFooter: UIView {
    private lazy var gradientView = UIView()

    lazy var button = PillButtonWithImage(
        backgroundColor: SpotColors.SpotBlack.color.withAlphaComponent(0.7),
        image: UIImage(named: "RefreshLocationIcon") ?? UIImage(),
        title: "Refresh Location",
        titleColor: .white)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        addSubview(gradientView)
        gradientView.isUserInteractionEnabled = false
        gradientView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(button)
        button.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.width.equalTo(200)
            $0.height.equalTo(44)
            $0.top.equalTo(50)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutIfNeeded()
        for layer in gradientView.layer.sublayers ?? [] {
            layer.removeFromSuperlayer()
        }

        let layer = CAGradientLayer()
        layer.frame = gradientView.bounds
        layer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.white.withAlphaComponent(1.0).cgColor,
        ]
        layer.locations = [0, 0.4, 0.75]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientView.layer.addSublayer(layer)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // avoid stealing touches from tableView
        return point.y > button.frame.minY - 5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class HomeScreenFooterGradientLayer: CAGradientLayer {
    override init() {
        super.init()
        colors = [
            UIColor(red: 0.225, green: 0.721, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.142, green: 0.897, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.379, green: 0.926, blue: 1, alpha: 1).cgColor
        ]
        locations = [0, 0.53, 1]
        startPoint = CGPoint(x: 0.5, y: 0.0)
        endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
