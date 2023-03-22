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
    private(set) lazy var addImage = UIImageView(image: UIImage(named: "AddMembers"))
    private(set) lazy var avatarImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
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
        avatarImage.image = UIImage()
        let image = user.getAvatarImage()
        if image != UIImage() {
            avatarImage.image = image
        } else if user.avatarURL ?? "" != "" {
            avatarImage.isHidden = false
            addImage.isHidden = true
            let aviTransformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(
                with: URL(string: user.avatarURL ?? ""),
                placeholderImage: nil,
                options: .highPriority,
                context: [.imageTransformer: aviTransformer])

        } else {
            addImage.isHidden = false
            avatarImage.isHidden = true
        }

        usernameLabel.text = user.username
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.sd_cancelCurrentImageLoad()
    }
}

extension MapMemberCell {
    private func viewSetup() {
        contentView.backgroundColor = nil

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.width.equalTo(48)
            $0.height.equalTo(54)
        }

        contentView.addSubview(addImage)
        addImage.isHidden = true
        addImage.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.width.equalTo(54)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(avatarImage.snp.bottom).offset(6)
            $0.height.equalTo(17)
        }
    }
}
