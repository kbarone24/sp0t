//
//  HomeScreenEmptyState.swift
//  Spot
//
//  Created by Kenny Barone on 8/14/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class HomeScreenEmptyState: UIView {
    private(set) lazy var image = UIImageView(image: UIImage(named: "LocationAccessIcon"))

    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.text = "There are no spots nearby"
        label.textColor = SpotColors.SpotBlack.color
        label.font = SpotFonts.UniversCE.fontWith(size: 17)
        label.textAlignment = .center
        return label
    }()

    private(set) lazy var sublabel: UILabel = {
        let label = UILabel()
        label.text = "If you think this is wrong, try refreshing your location."
        label.textColor = SpotColors.SpotBlack.color.withAlphaComponent(0.8)
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private(set) lazy var accessButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = SpotColors.SpotBlack.color
        button.layer.cornerRadius = 9
        button.setTitle("Enable location access to find spots near you", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 16)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.isHidden = true
        button.addTarget(self, action: #selector(accessTap), for: .touchUpInside)
        return button
    }()

    lazy var topMask = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(image)
        image.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.top.equalTo(image.snp.bottom).offset(15)
        }

        addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.top.equalTo(label.snp.bottom).offset(8)
        }

        addSubview(accessButton)
        accessButton.snp.makeConstraints {
            $0.top.equalTo(image.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(240)
            $0.height.equalTo(60)
        }
    }

    func configureNoAccess() {
        label.isHidden = true
        sublabel.isHidden = true
        accessButton.isHidden = false
    }

    func configureNoPosts() {
        label.isHidden = false
        sublabel.isHidden = false
        accessButton.isHidden = true
    }

    @objc private func accessTap() {
        guard let settingsString = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsString, options: [:], completionHandler: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
