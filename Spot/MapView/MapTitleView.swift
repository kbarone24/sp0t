//
//  MapTitleView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class MapTitleView: UIView {
    private lazy var spotLogo: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(named: "HomeLogo")
        return view
    }()
    lazy var profileButton = ProfileButton()
    lazy var notificationsButton = NotificationsButton()
    lazy var searchButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(named: "FindFriendsNavIcon"), for: .normal)
        return button
    }()

    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(spotLogo)
        spotLogo.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.width.equalTo(83.37)
            $0.height.equalTo(36)
            $0.centerY.equalToSuperview()
        }

        addSubview(profileButton)
        profileButton.snp.makeConstraints {
            $0.trailing.equalTo(-22)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(39)
        }

        addSubview(notificationsButton)
        notificationsButton.snp.makeConstraints {
            $0.trailing.equalTo(profileButton.snp.leading).offset(-20)
            $0.centerY.equalToSuperview().offset(-3) // offset for noti indicator
            $0.height.equalTo(35)
            $0.width.equalTo(30)
        }

        addSubview(searchButton)
        searchButton.snp.makeConstraints {
            $0.trailing.equalTo(notificationsButton.snp.leading).offset(-20)
            $0.centerY.equalToSuperview().offset(2.5)
            $0.width.equalTo(45)
            $0.height.equalTo(33.75)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
