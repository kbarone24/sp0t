//
//  MapPrivacyView.swift
//  Spot
//
//  Created by Kenny Barone on 2/22/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

enum UploadPrivacyLevel: Int {
    case Community = 0
    case Creator = 1
    case Private = 2
}

class MapPrivacyView: UIView {
    private(set) lazy var icon = UIImageView(image: UIImage(named: "CommunityMapIcon"))
    private(set) lazy var mapTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Community"
        label.textColor = UIColor(red: 0.225, green: 1, blue: 0.628, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 17)
        return label
    }()
    private(set) lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Anyone can add to map"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Medium", size: 14)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.centerY.equalToSuperview()
        }

        addSubview(mapTypeLabel)
        mapTypeLabel.snp.makeConstraints {
            // hard code leading constraint so it doesnt move with updates
            $0.leading.equalTo(52)
            $0.top.equalToSuperview()
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints {
            $0.leading.equalTo(mapTypeLabel)
            $0.top.equalTo(mapTypeLabel.snp.bottom).offset(3)
        }
    }

    func set(privacyLevel: UploadPrivacyLevel) {
        switch privacyLevel {
        case .Community:
            icon.image = UIImage(named: "CommunityMapIcon")
            mapTypeLabel.text = "Community"
            mapTypeLabel.textColor = UIColor(red: 0.225, green: 1, blue: 0.628, alpha: 1)
            descriptionLabel.text = "Anyone can add to map"
        case .Creator:
            icon.image = UIImage(named: "CreatorMapIcon")
            mapTypeLabel.text = "Creator"
            mapTypeLabel.textColor = UIColor(red: 0.946, green: 0.713, blue: 0.26, alpha: 1)
            descriptionLabel.text = "Anyone can follow map"
        case .Private:
            icon.image = UIImage(named: "PrivateMapIcon")
            mapTypeLabel.text = "Private"
            mapTypeLabel.textColor = UIColor(red: 1, green: 0.446, blue: 0.845, alpha: 1)
            descriptionLabel.text = "Only invited sp0tters can see and post"
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
