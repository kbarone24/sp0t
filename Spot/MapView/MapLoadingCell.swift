//
//  MapLoadingCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class MapLoadingCell: UICollectionViewCell {
    private(set) lazy var activityIndicator = CustomActivityIndicator()
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Loading maps"
        label.textColor = .black.withAlphaComponent(0.5)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 12)
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        activityIndicator.startAnimating()
        contentView.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-10)
            $0.width.height.equalTo(30)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalTo(activityIndicator.snp.bottom).offset(5)
            $0.centerX.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
