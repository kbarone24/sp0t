//
//  ProfileBodyCell.swift
//  Spot
//
//  Created by Arnold Lee on 2022/6/27.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import UIKit

class ProfileBodyCell: UICollectionViewCell {
    private lazy var mapImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 14
        return imageView
    }()

    private lazy var mapName: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 16)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapImage.sd_cancelCurrentImageLoad()
    }

    public func cellSetup(mapData: CustomMap, userID: String) {
        var urlString = mapData.imageURL
        if let i = mapData.posterIDs.lastIndex(where: { $0 == userID }) {
            urlString = mapData.postImageURLs[safe: i] ?? ""
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 200, height: 200), scaleMode: .aspectFill)
        mapImage.sd_setImage(with: URL(string: urlString), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])

        if mapData.secret {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = UIImage(named: "SecretMap")
            imageAttachment.bounds = CGRect(x: 0, y: 0, width: imageAttachment.image?.size.width ?? 0, height: imageAttachment.image?.size.height ?? 0)
            let attachmentString = NSAttributedString(attachment: imageAttachment)
            let completeText = NSMutableAttributedString(string: "")
            completeText.append(attachmentString)
            completeText.append(NSAttributedString(string: " \(mapData.mapName)"))
            self.mapName.attributedText = completeText
        } else {
            self.mapName.attributedText = NSAttributedString(string: mapData.mapName)
        }
    }
}

extension ProfileBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white

        contentView.addSubview(mapImage)
        mapImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.frame.width).multipliedBy(182 / 195)
        }

        contentView.addSubview(mapName)
        mapName.snp.makeConstraints {
            $0.leading.trailing.equalTo(mapImage)
            $0.top.equalTo(mapImage.snp.bottom).offset(6)
        }
    }
}
