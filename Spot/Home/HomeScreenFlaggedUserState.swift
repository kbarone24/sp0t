//
//  HomeScreenFlaggedUserState.swift
//  Spot
//
//  Created by Kenny Barone on 8/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class HomeScreenFlaggedUserState: UIView {
    private lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "HomeScreenBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Your account has been flagged :("
        label.textColor = SpotColors.SpotBlack.color
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 20)
        return label
    }()

    private(set) lazy var sublabel0: UILabel = {
        let label = UILabel()
        label.text = "You've been reported by a lot of sp0tters."
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.8)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15)
        label.textAlignment = .center
        return label
    }()

    private(set) lazy var sublabel1: UILabel = {
        let label = UILabel()
        label.text = "If you've been wrongfully accused, you can plead your case to the sp0tb0t in inbox."
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.8)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 15)
        label.textAlignment = .center
        return label
    }()


    lazy var topMask = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-120)
        }

        addSubview(sublabel0)
        sublabel0.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.top.equalTo(label.snp.bottom).offset(8)
        }

        addSubview(sublabel1)
        sublabel1.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(24)
            $0.top.equalTo(sublabel0.snp.bottom).offset(6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
