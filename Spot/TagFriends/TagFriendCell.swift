//
//  TagFriendCell.swift
//  Spot
//
//  Created by Kenny Barone on 4/27/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI

final class TagFriendCell: UICollectionViewCell {
    private lazy var username: UILabel = {
        let label = UILabel()
        label.textColor = textColor
        label.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        label.textAlignment = .center
        label.lineBreakMode = .byCharWrapping
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()

    var textColor: UIColor = .black {
        didSet {
            username.textColor = textColor
        }
    }

    func setUp(user: UserProfile) {
        let image = user.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else {
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: user.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: aviTransformer])
        }

        username.text = user.username
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.height.equalTo(54)
            $0.width.equalTo(48)
        }

        contentView.addSubview(username)
        username.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(avatarImage.snp.bottom).offset(6)
         //   $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
