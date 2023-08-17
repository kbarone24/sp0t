//
//  ProfileButton.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class ProfileButton: UIButton {
    private lazy var circleView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 33 / 2
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 2
        view.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.5, radius: 4, offset: CGSize(width: 0, height: 1))
        return view
    }()

    private lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.layer.masksToBounds = true
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        return image
    }()

    private(set) lazy var shadowButton = UIButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = nil

        addSubview(circleView)
        circleView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(5)
        }

        addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.bottom.equalTo(circleView).offset(-2)
            $0.centerX.equalTo(circleView)
            $0.height.equalTo(39.38)
            $0.width.equalTo(35)
        }

        addSubview(shadowButton)
        shadowButton.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(setAvatarImage), name: Notification.Name(rawValue: "UserProfileLoad"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func setAvatarImage() {
        profileImage.image = UserDataModel.shared.userInfo.getAvatarImage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
