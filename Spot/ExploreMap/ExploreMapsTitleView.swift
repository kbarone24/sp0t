//
//  ExploreMapsTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 4/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ExploreMapsTitleView: UIView {
    private(set) lazy var titleLabel: UILabel = {
        // TODO: replace with real font (UniversCE55-MediumBold)
        let label = UILabel()
        label.font = UIFont(name: "UniversCE-Black", size: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "❤️‍🔥Hot maps❤️‍🔥"
        return label
    }()

    private(set) lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Join trending communities"
        label.font = UIFont(name: "SFCompactText-Bold", size: 12.5)
        label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        return label
    }()

    init() {
        super.init(frame: .zero)
        clipsToBounds = false

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

