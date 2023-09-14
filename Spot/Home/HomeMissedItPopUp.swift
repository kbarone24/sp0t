//
//  HomeMissedItPopUp.swift
//  Spot
//
//  Created by Kenny Barone on 9/13/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeMissedItPopUp: UIView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "missed it💔 join the next p0p💖"
        label.textColor = .white
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 19.5)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 10
        layer.masksToBounds = true

        addSubview(label)
        label.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
