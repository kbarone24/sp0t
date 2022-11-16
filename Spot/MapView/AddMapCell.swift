//
//  AddMapCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class AddMapCell: UICollectionViewCell {
    private lazy var newIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "NewMapButton")
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        contentView.addSubview(newIcon)
        newIcon.snp.makeConstraints {
            $0.leading.equalTo(10)
            $0.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
