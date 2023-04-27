//
//  SpotscoreTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 4/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SpotscoreTitleView: UIView {
    private(set) lazy var spotscoreBackground = UIImageView(image: UIImage(named: "SpotscoreBackground"))
    private(set) lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Gameplay", size: 11.5)
        label.textColor = .white
        return label
    }()

    private(set) lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Gameplay", size: 12)
        label.textColor = .white
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        let attString = NSMutableAttributedString(string: "Post sp0ts, add friends & join maps to get sp0tsc0re", attributes: [.kern: 0.84])
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        attString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, attString.length))
        label.attributedText = attString
        return label
    }()

    init(score: Int) {
        super.init(frame: .zero)

        addSubview(spotscoreBackground)
        spotscoreBackground.snp.makeConstraints {
            $0.leading.equalTo(18)
            $0.centerY.equalToSuperview()
        }

        scoreLabel.text = String(score)
        spotscoreBackground.addSubview(scoreLabel)
        scoreLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(0.5)
            $0.bottom.equalToSuperview().offset(-4.5)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.leading.equalTo(spotscoreBackground.snp.trailing).offset(15)
            $0.centerY.equalToSuperview().offset(-2)
            $0.trailing.lessThanOrEqualTo(-18)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
