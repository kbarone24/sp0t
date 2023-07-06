//
//  SearchResultCell.swift
//  Spot
//
//  Created by Kenny Barone on 6/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI

class SearchResultCell: UITableViewCell {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.textColor = .white
        return label
    }()

    private lazy var avatarImage = UIImageView()

    private lazy var spotImage = UIImageView(image: UIImage(named: "SearchSpotIcon"))

    private lazy var mapImage: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none

        avatarImage.contentMode = .scaleAspectFill
        avatarImage.isHidden = true
        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.top.equalToSuperview().offset(5.5)
            $0.bottom.equalToSuperview().inset(10.5)
            $0.height.equalTo(45)
            $0.width.equalTo(40)
        }

        spotImage.isHidden = true
        contentView.addSubview(spotImage)
        spotImage.snp.makeConstraints {
            $0.leading.width.equalTo(avatarImage)
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(40)
        }

        mapImage.isHidden = true
        contentView.addSubview(mapImage)
        mapImage.snp.makeConstraints {
            $0.leading.centerY.width.height.equalTo(spotImage)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(spotImage.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(searchResult: SearchResult) {
        switch searchResult.type {
        case .map:
            label.text = searchResult.map?.mapName ?? ""
            avatarImage.isHidden = true
            spotImage.isHidden = true
            mapImage.isHidden = false

            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            mapImage.sd_setImage(
                with: URL(string: searchResult.map?.imageURL ?? ""),
                placeholderImage: UIImage(color: .darkGray),
                options: .highPriority,
                context: [.imageTransformer: transformer])

        case .spot:
            label.text = searchResult.spot?.spotName ?? ""
            avatarImage.isHidden = true
            spotImage.isHidden = false
            mapImage.isHidden = true

        case .user:
            label.text = searchResult.user?.username ?? ""
            avatarImage.isHidden = false
            spotImage.isHidden = true
            mapImage.isHidden = true

            let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 90), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: searchResult.user?.avatarURL ?? ""),
                                    placeholderImage: nil,
                                    options: .highPriority,
                                    context: [.imageTransformer: transformer])
        }
    }
}
