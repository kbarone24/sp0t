//
//  CustomMapUploadCell.swift
//  Spot
//
//  Created by Kenny Barone on 8/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import UIKit

class CustomMapUploadCell: UITableViewCell {
    private lazy var mapImage: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 9
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        return view
    }()
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.lineBreakMode = .byTruncatingTail
        label.font = UIFont(name: "SFCompactText-Semibold", size: 18)
        return label
    }()
    private lazy var selectedBubble = UIImageView()
    private lazy var bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(map: CustomMap?, selected: Bool, newMap: Bool) {
        if let map {
            // standard map cell
            let url = map.imageURL
            if map.coverImage != UIImage() {
                mapImage.image = map.coverImage
            } else if url != "" {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
                mapImage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
            }
            let buttonImage = selected ? UIImage(named: "MapToggleOn") : UIImage(named: "MapToggleOff")
            selectedBubble.image = buttonImage

            if map.secret {
                // show secret icon
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = UIImage(named: "SecretMap")
                imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image?.size.width ?? 0, height: imageAttachment.image?.size.height ?? 0)
                let attachmentString = NSAttributedString(attachment: imageAttachment)
                let completeText = NSMutableAttributedString(string: "")
                completeText.append(attachmentString)
                completeText.append(NSAttributedString(string: " \(map.mapName)"))
                self.nameLabel.attributedText = completeText
            } else {
                nameLabel.attributedText = NSAttributedString(string: map.mapName)
            }
        } else {
            // new map cell
            mapImage.image = UIImage(named: "NewMapCellImage")
            selectedBubble.image = UIImage()
            nameLabel.attributedText = NSAttributedString(string: "New map")
        }

        let disableCell = !selected && newMap
        contentView.alpha = disableCell ? 0.2 : 1.0
        isUserInteractionEnabled = disableCell ? false : true
    }

    func setUpView() {
        backgroundColor = .white
        selectionStyle = .none

        contentView.addSubview(mapImage)
        mapImage.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.height.width.equalTo(49)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(selectedBubble)
        selectedBubble.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(21)
            $0.height.width.equalTo(33)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(mapImage.snp.trailing).offset(10)
            $0.trailing.lessThanOrEqualTo(selectedBubble.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(bottomLine)
        bottomLine.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.trailing.equalToSuperview().inset(25)
            $0.height.equalTo(1)
            $0.bottom.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapImage.sd_cancelCurrentImageLoad()
    }
}

class CustomMapsHeader: UITableViewHeaderFooterView {
    private lazy var customMapsLabel: UILabel = {
        let label = UILabel()
        label.text = "MY MAPS"
        label.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Bold", size: 14)
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView

        addSubview(customMapsLabel)
        customMapsLabel.snp.makeConstraints {
            $0.leading.equalTo(15)
            $0.bottom.equalToSuperview().inset(6)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
