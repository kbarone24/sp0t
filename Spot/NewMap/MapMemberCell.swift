//
//  MapMemberCell.swift
//  Spot
//
//  Created by Arnold on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

final class MapMemberCell: UICollectionViewCell {
    private(set) lazy var profilePic: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 31
        imageView.clipsToBounds = true
        return imageView
    }()

    private(set) lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.masksToBounds = true
        imageView.contentMode = UIView.ContentMode.scaleAspectFill
        return imageView
    }()

    private(set) lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cellSetUp(user: UserProfile) {
        if user.imageURL != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(
                with: URL(string: user.imageURL),
                placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .darkGray),
                options: .highPriority,
                context: [.imageTransformer: transformer])

            let avatarURL = user.avatarURL ?? ""
            if avatarURL != "" {
                let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 69.4, height: 100), scaleMode: .aspectFill)
                avatarImage.sd_setImage(
                    with: URL(string: avatarURL),
                    placeholderImage: nil,
                    options: .highPriority,
                    context: [.imageTransformer: aviTransformer])
            }

        } else {
            profilePic.image = UIImage(named: "AddMembers")
            avatarImage.image = UIImage()
        }

        usernameLabel.text = user.username
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        profilePic.sd_cancelCurrentImageLoad()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}

extension MapMemberCell {
    private func viewSetup() {
        contentView.backgroundColor = nil

        contentView.addSubview(profilePic)
        profilePic.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.width.height.equalTo(62)
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.leading).offset(-3)
            $0.bottom.equalTo(profilePic.snp.bottom).offset(3)
            $0.width.equalTo(30.3)
            $0.height.equalTo(39.75)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(profilePic.snp.bottom).offset(6)
            $0.height.equalTo(17)
        }
    }
}
