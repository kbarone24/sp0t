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
    var avatar: AvatarProfile?
    private lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.alpha = 0.5
        view.contentMode = .scaleToFill
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.addSubview(avatarImage)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(avatar: AvatarProfile, selected: Bool) {
        self.avatar = avatar
        avatarImage.alpha = selected ? 1.0 : 0.5
        avatarImage.image = UIImage(named: avatar.avatarName)

        avatarImage.snp.removeConstraints()
        avatarImage.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            if selected {
                $0.height.equalTo(77.62)
                $0.width.equalTo(69)
            } else {
                $0.height.equalTo(56.78)
                $0.width.equalTo(50.47)
            }
        }
    }
}
