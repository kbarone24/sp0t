//
//  HomeScreenTitleView.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class HomeScreenTitleView: UIView {
    private lazy var gradientView = UIView()

    private lazy var cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 28)
        label.lineBreakMode = .byTruncatingTail
        label.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.4, radius: 4, offset: CGSize(width: 0, height: 1))
        return label
    }()

    lazy var profileButton = ProfileButton()

    lazy var notificationsButton = NotificationsButton()

    lazy var searchButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "SearchNavIcon"), for: .normal)
        button.addShadow(shadowColor: UIColor.black.cgColor, opacity: 0.4, radius: 4, offset: CGSize(width: 0, height: 1))
        return button
    }()

    override var intrinsicContentSize: CGSize {
        return UIView.layoutFittingExpandedSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutIfNeeded()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        addSubview(gradientView)
        gradientView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(profileButton)
        profileButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(2)
            $0.centerY.equalToSuperview().offset(-3)
            $0.width.height.equalTo(43)
        }

        addSubview(notificationsButton)
        notificationsButton.snp.makeConstraints {
            $0.trailing.equalTo(profileButton.snp.leading).offset(-12)
            $0.centerY.equalToSuperview().offset(-5) // offset for noti indicator
            $0.height.equalTo(44)
            $0.width.equalTo(39)
        }

        addSubview(searchButton)
        searchButton.snp.makeConstraints {
            $0.trailing.equalTo(notificationsButton.snp.leading).offset(-16)
            $0.centerY.equalToSuperview().offset(-0.5)
            $0.width.equalTo(35)
            $0.height.equalTo(35)
        }

        // doesnt make sense to show user's city anymore
        addSubview(cityLabel)
        cityLabel.text = "sp0t"
        cityLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(5)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(searchButton.snp.leading).offset(-5)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
