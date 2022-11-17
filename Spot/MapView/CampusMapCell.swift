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
        view.layer.cornerRadius = 16
        view.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        return view
    }()

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Bold", size: 20)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        let attString = NSAttributedString(string: "UNC Maps").shrinkLineHeight(multiple: 0.75, kern: -1.2)
        label.attributedText = attString
        return label
    }()

    private lazy var mapCoverImage: UIImageView = {
        let view = UIImageView(image: UIImage(named: "UNCMapsOverview"))
        view.layer.cornerRadius = 2
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white

        contentView.addSubview(contentArea)
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }

        contentArea.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(32)
            $0.centerY.equalToSuperview().offset(2)
            $0.height.lessThanOrEqualTo(35)
        }

        contentArea.addSubview(mapCoverImage)
        mapCoverImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        layoutIfNeeded()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
