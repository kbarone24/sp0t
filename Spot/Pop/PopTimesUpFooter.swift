//
//  PopTimesUpFooter.swift
//  Spot
//
//  Created by Kenny Barone on 8/31/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PopTimesUpFooter: UIView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15.5)
        label.textAlignment = .center
        label.text = "😔 don’t cry because it popped smile because it was poppin 🔥"
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SpotColors.HeaderGray.color

        addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalTo(20)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(255)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
