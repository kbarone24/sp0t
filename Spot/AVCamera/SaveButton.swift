//
//  SaveButton.swift
//  Spot
//
//  Created by Kenny Barone on 4/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SaveButton: UIButton {
    let symbolConfig = UIImage.SymbolConfiguration(weight: .bold)
    private lazy var icon = UIImageView(image: UIImage(systemName: "arrow.down",  withConfiguration: symbolConfig))
    lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Save"
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Bold", size: 16)
        return label
    }()

    var saved: Bool = false {
        didSet {
            if saved {
                icon.image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
                label.text = "Saved"
            } else {
                isEnabled = true
                icon.image = UIImage(systemName: "arrow.down", withConfiguration: symbolConfig)
                label.text = "Save"
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(icon)
        icon.tintColor = .white
        icon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(5)
            $0.centerY.equalToSuperview()
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(6.8)
            $0.trailing.equalToSuperview().offset(-5)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
