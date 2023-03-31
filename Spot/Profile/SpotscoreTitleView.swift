//
//  SpotscoreTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 3/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotscoreTitleView: UIView {
    private(set) lazy var backgroundImage = UIImageView(image: UIImage(named: "SpotscoreBackground"))
    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Gameplay", size: 11.5)
        label.textColor = .white
        return label
    }()

    var score: Int = 0 {
        didSet {
            backgroundImage.isHidden = false
            label.text = String(max(score, 0))
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false

        addSubview(backgroundImage)
        backgroundImage.isHidden = true
        backgroundImage.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview()
        }

        backgroundImage.addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-16)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
