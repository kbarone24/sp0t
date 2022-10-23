//
//  ProfileButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ProfileButton: UIButton {
    var profileImage: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 39 / 2
        layer.borderColor = UIColor.black.cgColor
        layer.borderWidth = 2

        profileImage = UIImageView {
            $0.layer.cornerRadius = 33 / 2
            $0.layer.masksToBounds = true
            addSubview($0)
        }
        profileImage.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(3)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
