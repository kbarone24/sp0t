//
//  ChooseMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 10/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage

class ChooseMapCell: UITableViewCell {
    private lazy var mapImage: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10
        view.contentMode = .scaleAspectFill
        view.tintColor = SpotColors.SublabelGray.color
        return view
    }()

    private lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedBold.fontWith(size: 18)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        return label
    }()

    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = SpotColors.SpotBlack.color
        selectionStyle = .none

        contentView.addSubview(mapImage)
        mapImage.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.width.height.equalTo(48)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage.snp.trailing).offset(10)
            $0.trailing.lessThanOrEqualTo(-16)
            $0.height.lessThanOrEqualTo(mapImage)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(map: CustomMap, isSelectedMap: Bool) {
        backgroundColor = isSelectedMap ? SpotColors.SpotGreen.color.withAlphaComponent(0.25) : SpotColors.SpotBlack.color

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        let imageURL = map.postImageURLs.last(where: { $0 != "" }) ?? map.imageURL

        if imageURL != "" {
            mapImage.sd_setImage(
                with: URL(string: imageURL),
                placeholderImage: UIImage(color: .darkGray),
                options: .highPriority,
                context: [.imageTransformer: transformer])
        } else {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15.5, weight: .regular)
            mapImage.image = UIImage(systemName: "map", withConfiguration: symbolConfig)
        }

        if map.secret {
            mapLabel.attributedText = map.mapName.getAttributedStringWithImage(image: UIImage(named: "PinkLockIcon") ?? UIImage(), topOffset: -1)
        } else {
            mapLabel.attributedText = NSAttributedString(string: map.mapName)
        }
        mapLabel.sizeToFit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapImage.sd_cancelCurrentImageLoad()
        mapImage.image = UIImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
