//
//  PaddedNextButton.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class PaddedNextButton: UIButton {
    private lazy var contentArea: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotGreen")
        view.layer.cornerRadius = 9
        view.isUserInteractionEnabled = false
        return view
    }()
    private lazy var nextLabel: UILabel = {
        let label = UILabel()
        label.text = "Next"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(contentArea)
        contentArea.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(5)
        }

        contentArea.addSubview(nextLabel)
        nextLabel.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
