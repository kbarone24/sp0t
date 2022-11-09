//
//  UNCMapsCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/8/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class CampusMapCell: UICollectionViewCell {
    private lazy var contentArea: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
        view.layer.cornerRadius = 16
        return view
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "UNC maps"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont(name: "SFCompactText-Bold", size: 16)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(contentArea)
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }

        contentArea.addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
