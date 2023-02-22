//
//  ChooseSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ChooseSpotCell: UITableViewCell {
    private lazy var topLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        return view
    }()
    private lazy var distanceLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.textColor = UIColor(red: 0.808, green: 0.808, blue: 0.808, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.sizeToFit()
        return label
    }()
    private lazy var spotName: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        return label
    }()
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        return view
    }()
    private var postsLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        return label
    }()

    private var spotID = ""

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpView() {
        selectionStyle = .none

        contentView.addSubview(topLine)
        topLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }

        contentView.addSubview(distanceLabel)
        distanceLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(13)
            $0.top.equalTo(21)
            $0.height.equalTo(15)
        }

        contentView.addSubview(spotName)

        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.top.equalTo(spotName.snp.bottom).offset(2)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(descriptionLabel.snp.trailing).offset(5)
            $0.top.equalTo(descriptionLabel.snp.centerY).offset(-1)
            $0.width.height.equalTo(3)
        }

        contentView.addSubview(postsLabel)
    }

    func setUp(spot: MapSpot) {
        backgroundColor = spot.selected ?? false ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.4) : UIColor(named: "SpotBlack")
        spotID = spot.id ?? ""

        distanceLabel.text = spot.distance.getLocationString()
        spotName.text = spot.spotName

        descriptionLabel.isHidden = spot.spotDescription.isEmpty
        descriptionLabel.text = spot.spotDescription

        separatorView.isHidden = spot.postIDs.isEmpty || spot.spotDescription.isEmpty

        var postsText = "\(spot.postIDs.count) post"
        if spot.postIDs.count > 1 { postsText += "s" }
        postsLabel.text = postsText
        postsLabel.isHidden = spot.postIDs.isEmpty

        postsLabel.snp.removeConstraints()
        postsLabel.snp.updateConstraints {
            $0.top.equalTo(spotName.snp.bottom).offset(2)
            $0.width.equalTo(100)
            if spot.spotDescription == "" {
                $0.leading.equalTo(20)
            } else {
                $0.leading.equalTo(separatorView.snp.trailing).offset(5)
            }
        }

        // slide spotName down if no description label
        spotName.snp.removeConstraints()
        spotName.snp.updateConstraints {
            $0.leading.equalTo(20)
            $0.trailing.equalTo(distanceLabel.snp.leading).offset(-5)
            $0.height.equalTo(17)
            if spot.postIDs.isEmpty && spot.spotDescription.isEmpty {
                $0.top.equalTo(19)
            } else {
                $0.top.equalTo(11)
            }
        }
    }
}
