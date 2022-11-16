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
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Bold", size: 14.5)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1)

        let containerView = UIView {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }

        containerView.addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }

        containerView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(6)
            $0.centerY.trailing.equalToSuperview()
        }
    }

    func setUp(image: UIImage, str: String, cornerRadius: CGFloat) {
        icon.image = image
        label.text = str
        layer.cornerRadius = cornerRadius
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
