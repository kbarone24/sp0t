//
//  AddedMapConfirmation.swift
//  Spot
//
//  Created by Kenny Barone on 3/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class AddMapConfirmationView: UIView {
    private lazy var checkmark = UIImageView(image: UIImage(named: "AddedMapCheckmark"))
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Map added to your world"
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Medium", size: 15)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hexString: "#404040")
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.592, green: 0.592, blue: 0.592, alpha: 1).cgColor
        layer.cornerRadius = 7

        addSubview(checkmark)
        checkmark.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.centerY.equalToSuperview()
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(7.5)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
