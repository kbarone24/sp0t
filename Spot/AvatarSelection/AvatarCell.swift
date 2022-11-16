//
//  AvatarCell.swift
//  Spot
//
//  Created by Kenny Barone on 11/15/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class AvatarCell: UICollectionViewCell {
    var avatar: String?
    private lazy var scaled = false
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.alpha = 0.5
        view.contentMode = .scaleToFill
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(avatarImage)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(avatar: String) {
        self.avatar = avatar
        scaled = false
        avatarImage.image = UIImage(named: avatar)

        avatarImage.snp.removeConstraints()
        avatarImage.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            // bunny is small so need to make a little bigger
            if avatar == "bunny" {
                $0.width.equalTo(55)
                $0.height.equalTo(77.08)
            } else {
                $0.width.equalTo(50)
                $0.height.equalTo(72.08)
            }
            $0.centerX.equalToSuperview()
        }
    }

    func transformToLarge() {
        scaled = true
        avatarImage.snp.removeConstraints()
        UIView.animate(withDuration: 0.1) {
            self.avatarImage.snp.makeConstraints {
                $0.height.equalTo(89.4)
                $0.width.equalTo(62)
            }
        }
        avatarImage.alpha = 1.0
    }

    func transformToStandard() {
        avatarImage.alpha = 1.0
        avatarImage.snp.removeConstraints()
        avatarImage.snp.makeConstraints {
            $0.height.equalTo(72.8)
            $0.width.equalTo(50)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.alpha = 0.5
    }
}
