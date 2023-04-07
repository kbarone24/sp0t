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
        titleLabel?.font = UIFont(name: "SFCompactText-Heavy", size: 17)
        backgroundColor = UIColor(red: 0.225, green: 1, blue: 0.535, alpha: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
