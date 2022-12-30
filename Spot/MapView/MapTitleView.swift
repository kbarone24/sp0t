//
//  MapTitleView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class MapTitleView: UIView {
    lazy var hamburgerMenu: UIButton = {
        let button = UIButton()
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.setImage(UIImage(named: "HamburgerMenu"), for: .normal)
        return button
    }()
    lazy var homeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 0.925, green: 0.925, blue: 0.925, alpha: 1)
        button.layer.cornerRadius = 9
        button.setTitle("Home", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 18.5)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        return button
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
        addSubview(hamburgerMenu)
        hamburgerMenu.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(-5)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(38)
            $0.width.equalTo(35.63)
        }

        addSubview(homeButton)
        homeButton.snp.makeConstraints {
            $0.leading.equalTo(hamburgerMenu.snp.trailing).offset(7)
            $0.width.equalTo(75)
            $0.height.equalTo(32)
            $0.centerY.equalToSuperview()
        }

        addSubview(profileButton)
        profileButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(7)
            $0.centerY.equalToSuperview().offset(-1)
            $0.width.height.equalTo(33)
        }

        addSubview(notificationsButton)
        notificationsButton.snp.makeConstraints {
            $0.trailing.equalTo(profileButton.snp.leading).offset(-22)
            $0.centerY.equalToSuperview().offset(-3) // offset for noti indicator
            $0.height.equalTo(35)
            $0.width.equalTo(30)
        }

        addSubview(searchButton)
        searchButton.snp.makeConstraints {
            $0.trailing.equalTo(notificationsButton.snp.leading).offset(-22)
            $0.centerY.equalToSuperview().offset(1.5)
            $0.width.equalTo(32)
            $0.height.equalTo(25.43)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
