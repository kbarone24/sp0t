//
//  ChooseSpotCell.swift
//  Spot
//
//  Created by Kenny Barone on 10/2/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
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
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14)
        label.sizeToFit()
        return label
    }()
    private lazy var spotName: UILabel = {
        let label = UILabel()
        label.clipsToBounds = true
        label.lineBreakMode = .byTruncatingTail
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 16)
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        return label
    }()
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = SpotColors.SublabelGray.color
        return view
    }()
    private var postsLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14)
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
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(spotName)

        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.top.equalTo(spotName.snp.bottom).offset(2)
            $0.trailing.lessThanOrEqualTo(distanceLabel.snp.leading).offset(-8)
        }

        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(descriptionLabel.snp.trailing).offset(5)
            $0.top.equalTo(descriptionLabel.snp.centerY).offset(-1)
            $0.width.height.equalTo(3)
        }

        contentView.addSubview(postsLabel)
    }

    func configure(spot: Spot, isSelectedSpot: Bool) {
        backgroundColor = isSelectedSpot ? SpotColors.SpotGreen.color.withAlphaComponent(0.25) : SpotColors.SpotBlack.color
        spotID = spot.id ?? ""

        distanceLabel.text = spot.distance.getLocationString(allowFeet: true)
        spotName.text = spot.spotName

        if spot.privacyLevel != "public" && spot.poiCategory ?? "" == "" {
            // show founder
            descriptionLabel.text = spot.posterUsername == "" ? "" : "By \(spot.posterUsername ?? "")"
        } else {
            // show poi category for public
            descriptionLabel.text = spot.poiCategory ?? ""
        }

        let hideDescription = descriptionLabel.text?.isEmpty ?? true
        descriptionLabel.isHidden = hideDescription

        separatorView.isHidden = spot.postIDs.isEmpty || hideDescription

        var postsText = "\(spot.postIDs.count) post"
        if spot.postIDs.count > 1 { postsText += "s" }
        postsLabel.text = postsText
        postsLabel.isHidden = spot.postIDs.isEmpty

        postsLabel.snp.removeConstraints()
        postsLabel.snp.makeConstraints {
            $0.top.equalTo(spotName.snp.bottom).offset(2)
            $0.width.equalTo(100)
            if descriptionLabel.text?.isEmpty ?? true {
                $0.leading.equalTo(20)
            } else {
                $0.leading.equalTo(separatorView.snp.trailing).offset(5)
            }
        }

        // slide spotName down if no description label
        spotName.snp.removeConstraints()
        spotName.snp.makeConstraints {
            $0.leading.equalTo(20)
            $0.trailing.equalTo(distanceLabel.snp.leading).offset(-8)
            if spot.postIDs.isEmpty && hideDescription {
                $0.top.equalTo(19)
            } else {
                $0.top.equalTo(11)
            }
        }
    }
}
