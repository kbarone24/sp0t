//
//  MyWorldEmptyState.swift
//  Spot
//
//  Created by Kenny Barone on 3/22/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class MyWorldEmptyState: UIView {
    private(set) lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var image = UIImageView(image: UIImage(named: "EmptyStateFace"))

    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Your world is empty"
        label.textColor = .black.withAlphaComponent(0.6)
        label.font = UIFont(name: "UniversCE-Black", size: 15)
        return label
    }()

    private(set) lazy var sublabel: UILabel = {
        let label = UILabel()
        label.text = "Maps and sp0tters you add will show here"
        label.textColor = UIColor(red: 0.483, green: 0.483, blue: 0.483, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        return label
    }()

    lazy var topMask = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(image)
        image.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(image.snp.bottom).offset(15)
        }

        addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label.snp.bottom).offset(8)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if topMask.superview == nil { addTopMask() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addTopMask() {
        topMask = UIView()
        insertSubview(topMask, aboveSubview: backgroundImage)
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(100)
        }
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 160)
        layer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.3).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer.endPoint = CGPoint(x: 0.5, y: 0.0)
        layer.locations = [0, 1]
        topMask.layer.addSublayer(layer)
    }
}
