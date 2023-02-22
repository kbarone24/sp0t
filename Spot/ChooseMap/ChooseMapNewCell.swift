//
//  SideBarNewMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ChooseMapNewCell: UITableViewCell {
    private lazy var newMapView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
        view.layer.cornerRadius = 11
        return view
    }()
    private lazy var newMapImage = UIImageView(image: UIImage(named: "GreenAddButton"))
    private lazy var label: UILabel = {
        let label = UILabel()
        label.text = "New map"
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 18)
        return label
    }()
    private lazy var subLabel: UILabel = {
        let label = UILabel()
        label.text = "Start a movement"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        return label
    }()
    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(named: "SpotBlack")
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
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(newMapView.snp.trailing).offset(10)
            $0.bottom.equalTo(newMapView.snp.centerY).offset(-0.5)
        }

        contentView.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(label)
            $0.top.equalTo(newMapView.snp.centerY).offset(0.5)
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
