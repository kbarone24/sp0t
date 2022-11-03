//
//  FriendsMapButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class FriendsMapButton: UIButton {
    private lazy var friendsMapIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "FriendsMapIcon")
        view.contentMode = .scaleAspectFill
        return view
    }()
    private lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.text = "Friends map"
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 18)
        return label
    }()
    private lazy var detailLabel: UILabel = {
        let label = UILabel()
        label.text = "You and your friends shared world"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()
    private lazy var selectedImage = UIImageView()

    var buttonSelected: Bool = true {
        didSet {
            let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
            selectedImage.image = buttonImage
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        addSubview(friendsMapIcon)
        friendsMapIcon.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.width.equalTo(60)
            $0.height.equalTo(62)
        }

        addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(friendsMapIcon.snp.trailing).offset(4)
            $0.top.equalTo(18)
        }

        let buttonImage = buttonSelected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
        selectedImage.image = buttonImage
        addSubview(selectedImage)
        selectedImage.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(22)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }

        addSubview(detailLabel)
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
