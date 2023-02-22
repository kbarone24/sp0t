//
//  SideBarMapCell.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage

class ChooseMapCustomCell: UITableViewCell {
    private lazy var mapImage: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 11
        view.contentMode = .scaleAspectFill
        return view
    }()

    private lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 18)
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
        backgroundColor = UIColor(named: "SpotBlack")
        selectionStyle = .none

        contentView.addSubview(mapImage)
        mapImage.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.width.height.equalTo(55)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(mapLabel)
        mapLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(15)
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

    func setUp(map: CustomMap) {
        backgroundColor = map == UploadPostModel.shared.mapObject ? UIColor(red: 0.488, green: 0.969, blue: 1, alpha: 0.4) : UIColor(named: "SpotBlack")

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        mapImage.sd_setImage(
            with: URL(string: map.imageURL),
            placeholderImage: UIImage(color: UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)),
            options: .highPriority,
            context: [.imageTransformer: transformer])

        if map.secret {
            mapLabel.attributedText = map.mapName.getAttributedStringWithImage(image: UIImage(named: "PinkLockIcon") ?? UIImage(), offset: -1)
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
