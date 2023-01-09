//
//  SideBarNewMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class SideBarNewMapCell: UITableViewCell {
    private lazy var newMapView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.975, green: 0.975, blue: 0.975, alpha: 1)
        view.layer.cornerRadius = 11
        return view
    }()
    private lazy var newMapImage = UIImageView(image: UIImage(named: "NewMapButton"))
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Create a map"
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

        contentView.addSubview(newMapView)
        newMapView.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(55)
        }

        newMapView.addSubview(newMapImage)
        newMapImage.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.width.equalTo(35.9)
            $0.height.equalTo(24.1)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(newMapView.snp.trailing).offset(10)
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
