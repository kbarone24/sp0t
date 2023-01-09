//
//  SideBarCampusMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 1/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SideBarCampusMapCell: UITableViewCell {
    private lazy var newMapImage = UIImageView(image: UIImage(named: "UNCMapsImage") ?? UIImage())
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "UNC maps"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Bold", size: 17.5)
        return label
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none

        newMapImage.contentMode = .scaleAspectFit
        contentView.addSubview(newMapImage)
        newMapImage.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(55)
            $0.height.equalTo(55)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(newMapImage.snp.trailing).offset(10)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
