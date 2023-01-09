//
//  ProfileButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ProfileButton: UIButton {
    lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.layer.cornerRadius = 27 / 2
        image.layer.masksToBounds = true
        return image
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 33 / 2
        layer.borderColor = UIColor.black.cgColor
        layer.borderWidth = 2

        addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(3)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
