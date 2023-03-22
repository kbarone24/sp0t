//
//  GridPostTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 3/17/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class GridPostTitleView: UIView {
    private(set) lazy var titleLabel: UILabel = {
        // TODO: replace with real font (UniversCE55-MediumBold)
        let label = UILabel()
        label.font = UIFont(name: "UniversCE-Black", size: 16)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private(set) lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Bold", size: 12.5)
        label.textColor = UIColor(red: 0.829, green: 0.829, blue: 0.829, alpha: 1)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    init(title: String, subtitle: String) {
        super.init(frame: .zero)
        clipsToBounds = true

        titleLabel.text = title
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        subtitleLabel.text = subtitle
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
