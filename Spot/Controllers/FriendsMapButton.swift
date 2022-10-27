//
//  FriendsMapButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class FriendsMapButton: UIButton {
    var friendsMapIcon: UIImageView!
    var mapLabel: UILabel!
    var detailLabel: UILabel!
    var selectedImage: UIImageView!
    var buttonSelected: Bool = true {
        didSet {
            let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
            selectedImage.image = buttonImage
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        friendsMapIcon = UIImageView {
            $0.image = UIImage(named: "FriendsMapIcon")
            $0.contentMode = .scaleAspectFill
            addSubview($0)
        }
        friendsMapIcon.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.width.equalTo(60)
            $0.height.equalTo(62)
        }

        mapLabel = UILabel {
            $0.text = "Friends map"
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 18)
            addSubview($0)
        }
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(friendsMapIcon.snp.trailing).offset(4)
            $0.top.equalTo(18)
        }

        let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage = UIImageView {
            $0.image = buttonImage
            addSubview($0)
        }
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(22)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }

        detailLabel = UILabel {
            $0.text = "You and your friends shared world"
            $0.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14)
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.7
            addSubview($0)
        }
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(mapLabel.snp.leading)
            $0.top.equalTo(mapLabel.snp.bottom).offset(1)
            $0.trailing.lessThanOrEqualTo(selectedImage.snp.leading).offset(-8)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
