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

    private(set) lazy var addButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "AddButton"), for: .normal)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(gradientView)
        gradientView.isUserInteractionEnabled = false
        gradientView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.bottom.trailing.equalTo(-20)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        /*
        layoutIfNeeded()
        for layer in gradientView.layer.sublayers ?? [] {
            layer.removeFromSuperlayer()
        }

        let layer = CAGradientLayer()
        layer.frame = gradientView.bounds
        layer.colors = [
            SpotColors.SpotBlack.color.withAlphaComponent(0.0).cgColor,
            SpotColors.SpotBlack.color.withAlphaComponent(0.3).cgColor,
            SpotColors.SpotBlack.color.withAlphaComponent(0.5).cgColor,
        ]
        layer.locations = [0, 0.3, 0.75]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientView.layer.addSublayer(layer)
        */
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // avoid stealing touches from tableView
        return point.y > addButton.frame.minY - 5
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
