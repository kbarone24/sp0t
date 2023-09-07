//
//  MyWorldEmptyState.swift
//  Spot
//
//  Created by Kenny Barone on 3/22/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class SpotEmptyState: UIView {
    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.text = "No one has posted here yet."
        label.textColor = UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 19)
        return label
    }()

    private(set) lazy var sublabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 0.88)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SpotColors.SpotBlack.color

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label.snp.bottom).offset(8)
        }
    }

    func configure(spot: Spot) {
        if !spot.isPop {
            sublabel.text = "Be the first to claim this spot!"
        } else {
            sublabel.text = "Get the conversation started!"

        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
