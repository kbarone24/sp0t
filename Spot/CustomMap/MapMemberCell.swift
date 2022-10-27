//
//  MapMemberCell.swift
//  Spot
//
//  Created by Arnold on 8/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import UIKit

final class MapMemberCell: UICollectionViewCell {
    private lazy var userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 31
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
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
            userImageView.sd_setImage(
                with: URL(string: user.imageURL),
                placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .white),
                options: .highPriority,
                context: [.imageTransformer: transformer])
        } else {
            userImageView.image = UIImage(named: "AddMembers")
        }

        usernameLabel.text = user.username
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        userImageView.sd_cancelCurrentImageLoad()
    }
}

extension MapMemberCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        contentView.addSubview(userImageView)
        userImageView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.width.height.equalTo(62)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(userImageView.snp.bottom).offset(6)
            $0.height.equalTo(17)
        }
    }
}
