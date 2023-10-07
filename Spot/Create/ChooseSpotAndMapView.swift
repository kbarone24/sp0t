//
//  HomeSpotView.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

class ChooseSpotAndMapView: UIView {
    private lazy var scrollContainer: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        return view
    }()

    private(set) lazy var spotContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = SpotColors.SublabelGray.color.cgColor
        return view
    }()
    private(set) lazy var spotIcon = UIImageView(image: UIImage(named: "HomeSpotLocationPin"))
    private(set) lazy var spotLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 16)
        return label
    }()

    private(set) lazy var mapContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
          view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = SpotColors.SublabelGray.color.cgColor
        return view
    }()
    private(set) lazy var mapIcon: UIImageView = {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15.5, weight: .regular)
        let view = UIImageView(image: UIImage(systemName: "map", withConfiguration: symbolConfig))
        view.tintColor = SpotColors.SublabelGray.color
        return view
    }()
    private(set) lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 16)
        return label
    }()

    override func layoutSubviews() {
        scrollContainer.contentSize = CGSize(width: mapContainer.frame.maxX, height: frame.height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(scrollContainer)
        scrollContainer.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        scrollContainer.addSubview(spotContainer)
        spotContainer.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        spotContainer.addSubview(spotIcon)
        spotIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(10)
            $0.centerY.equalToSuperview()
        }

        spotContainer.addSubview(spotLabel)
        spotLabel.snp.makeConstraints {
            $0.leading.equalTo(spotIcon.snp.trailing).offset(8)
            $0.top.bottom.equalToSuperview().inset(5)
            $0.trailing.equalToSuperview().inset(10)
        }

        scrollContainer.addSubview(mapContainer)
        mapContainer.snp.makeConstraints {
            $0.leading.equalTo(spotContainer.snp.trailing).offset(8)
            $0.top.bottom.equalToSuperview()
        }

        mapContainer.addSubview(mapIcon)
        mapIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(5)
            $0.centerY.equalToSuperview()
        }

        mapContainer.addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(mapIcon.snp.trailing).offset(8)
            $0.top.bottom.equalToSuperview().inset(5)
            $0.trailing.equalToSuperview().inset(10)
        }
    }

    func configure(spotName: String?, mapName: String?) {
        spotLabel.text = spotName ?? "Choose a spot"
        mapLabel.text = mapName ?? "Choose a map"

        layoutIfNeeded()
        layoutSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
