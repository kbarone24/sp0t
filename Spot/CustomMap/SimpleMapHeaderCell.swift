//
//  SimpleMapHeaderCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class SimpleMapHeaderCell: UICollectionViewCell {
    private lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
        label.adjustsFontSizeToFitWidth = true
        label.text = ""
        return label
    }()

    var mapText: String = "" {
        didSet {
            mapLabel.text = mapText
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func viewSetup() {
        contentView.addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.top.equalToSuperview().inset(-5)
        }
    }
}
