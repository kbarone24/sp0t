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
        label.font = SpotFonts.SFCompactRoundedSemibold.fontWith(size: 14)
        label.textColor = .white
        return label
    }()

    private lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.isHidden = true
        return image
    }()

    private lazy var spotImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.cornerRadius = 8
        image.layer.masksToBounds = true
        image.isHidden = true
        image.tintColor = SpotColors.SublabelGray.color
        return image
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

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(12)
            $0.top.equalToSuperview().offset(5.5)
            $0.bottom.equalToSuperview().inset(10.5)
            $0.height.equalTo(45)
            $0.width.equalTo(40)
        }

        contentView.addSubview(spotImage)
        spotImage.snp.makeConstraints {
            $0.leading.equalTo(avatarImage)
            $0.centerY.equalToSuperview()
            $0.height.width.equalTo(36)
        }

        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(60)
            $0.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(searchResult: SearchResult) {
        switch searchResult.type {

        case .spot:
            label.text = searchResult.spot?.spotName ?? ""
            avatarImage.isHidden = true
            spotImage.isHidden = false

            let lastPostIndex = searchResult.spot?.getLastAccessImageIndex() ?? -1
            if lastPostIndex > -1, let imageURL = searchResult.spot?.postImageURLs?[safe: lastPostIndex] {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 80), scaleMode: .aspectFill)
                spotImage.sd_setImage(with: URL(string: imageURL),
                                      placeholderImage: nil,
                                      options: .highPriority,
                                      context: [.imageTransformer: transformer])
            } else {
                spotImage.image = UIImage(named: "LocationPin")
            }

        case .user:
            label.text = searchResult.user?.username ?? ""
            avatarImage.isHidden = false
            spotImage.isHidden = true

            let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 90), scaleMode: .aspectFit)
            avatarImage.sd_setImage(with: URL(string: searchResult.user?.avatarURL ?? ""),
                                    placeholderImage: nil,
                                    options: .highPriority,
                                    context: [.imageTransformer: transformer])

        case .map:
            label.text = searchResult.map?.mapName ?? ""
            avatarImage.isHidden = true
            spotImage.isHidden = false

            let lastPostIndex = searchResult.map?.postImageURLs.lastIndex(where: { $0 != "" }) ?? -1
            if lastPostIndex > -1, let imageURL = searchResult.map?.postImageURLs[safe: lastPostIndex] {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 80, height: 80), scaleMode: .aspectFill)
                spotImage.sd_setImage(with: URL(string: imageURL),
                                      placeholderImage: nil,
                                      options: .highPriority,
                                      context: [.imageTransformer: transformer])
            } else {
                let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15.5, weight: .regular)
                spotImage.image = UIImage(systemName: "map", withConfiguration: symbolConfig)
            }
        }
    }
}
