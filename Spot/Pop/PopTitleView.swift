//
//  PopTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 8/28/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SnapKit

class PopTitleView: UIView {
    private lazy var popNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.UniversCE.fontWith(size: 19.5)
        return label
    }()

    private lazy var homeSpotIcon = UIImageView(image: UIImage(named: "HomeSpotIcon"))

    private lazy var homeSpotLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 12)
        return label
    }()

    init(popName: String, hostSpot: String) {
        super.init(frame: .zero)
        backgroundColor = nil
        clipsToBounds = false

        addSubview(popNameLabel)
        popNameLabel.text = popName
        popNameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-2)
     //       $0.height.greaterThanOrEqualTo(16)
            $0.centerX.equalToSuperview()
        }

        let containerView = UIView()
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.equalTo(popNameLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-2)
        }

        containerView.addSubview(homeSpotIcon)
        homeSpotIcon.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
        }

        containerView.addSubview(homeSpotLabel)
        homeSpotLabel.text = hostSpot
        homeSpotLabel.snp.makeConstraints {
            $0.leading.equalTo(homeSpotIcon.snp.trailing).offset(3.5)
            $0.trailing.equalToSuperview()
     //       $0.height.greaterThanOrEqualTo(14)
            $0.top.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
