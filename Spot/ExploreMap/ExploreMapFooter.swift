//
//  StartMapButton.swift
//  Spot
//
//  Created by Kenny Barone on 3/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol ExploreMapFooterDelegate: AnyObject {
    func buttonAction()
}

class ExploreMapFooter: UIView {
    weak var delegate: ExploreMapFooterDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let button = StartMapButton()
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        addSubview(button)

        button.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.height.equalTo(55)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    @objc func tap() {
        delegate?.buttonAction()
    }
}

class StartMapButton: UIButton {
    lazy var gradientLayer = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 7
        layer.masksToBounds = true

        setTitle("Start a map", for: .normal)
        setTitleColor(.black, for: .normal)
        titleLabel?.font = UIFont(name: "UniversCE-Black", size: 17)

        layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.colors = [
            UIColor(red: 1, green: 0.447, blue: 0.843, alpha: 1).cgColor,
            UIColor(red: 1, green: 0.867, blue: 0.396, alpha: 1).cgColor,
            UIColor(red: 0.224, green: 1, blue: 0.627, alpha: 1).cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
