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
    var mapLabel: UILabel!
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
        mapLabel = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 20.5)
            $0.adjustsFontSizeToFitWidth = true
            $0.text = ""
            contentView.addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.top.equalToSuperview().inset(-5)
        }
    }
}
