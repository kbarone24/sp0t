//
//  NearbyPostsEmptyState.swift
//  Spot
//
//  Created by Kenny Barone on 3/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class NearbyPostsEmptyState: UIView {
    private(set) lazy var backgroundImage: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "LandingPageBackground"))
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private(set) lazy var image = UIImageView(image: UIImage(named: "LocationAccessIcon"))

    private(set) lazy var label: UILabel = {
        let label = UILabel()
        label.text = "There are no posts nearby"
        label.textColor = .black.withAlphaComponent(0.6)
        label.font = UIFont(name: "UniversCE-Black", size: 15)
        return label
    }()

    private(set) lazy var sublabel: UILabel = {
        let label = UILabel()
        label.text = "Be the first to post in your city!"
        label.textColor = UIColor(red: 0.483, green: 0.483, blue: 0.483, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        return label
    }()

    private(set) lazy var accessButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = UIColor(named: "SpotGreen")
        button.layer.cornerRadius = 9
        button.setTitle("Enable location access to view nearby feed", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactText-Bold", size: 15)
        button.isHidden = true
        button.addTarget(self, action: #selector(accessTap), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundImage)
        backgroundImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(image)
        image.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-100)
        }

        addSubview(label)
        label.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(image.snp.bottom).offset(15)
        }

        addSubview(sublabel)
        sublabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(label.snp.bottom).offset(8)
        }

        addSubview(accessButton)
        accessButton.snp.makeConstraints {
            $0.top.equalTo(image.snp.bottom).offset(15)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(342)
            $0.height.equalTo(47)
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
