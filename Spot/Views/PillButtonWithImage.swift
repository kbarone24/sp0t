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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
