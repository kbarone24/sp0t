//
//  MapHomeCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/23/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

final class MapHomeCell: UICollectionViewCell {
    lazy var contentArea = UIView()
    var newIndicator: UIView!
    var mapCoverImage: UIImageView!
    var friendsCoverImage: ImageAvatarView!
    var lockIcon: UIImageView!
    var nameLabel: UILabel!

    override var isSelected: Bool {
        didSet {
            contentArea.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            contentArea.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
            if lockIcon != nil { lockIcon.image = isSelected ? UIImage(named: "HomeLockIconSelected") : UIImage(named: "HomeLockIcon") }
        }
    }

    func setUp(map: CustomMap?, avatarURLs: [String]?, postsList: [MapPost]) {
        setUpView()
        if map != nil {
            mapCoverImage.isHidden = false
            friendsCoverImage.isHidden = true
            if map!.id == "9ECABEF9-0036-4082-A06A-C8943428FFF4" {
                mapCoverImage.image = UIImage(named: "HeelsmapCover")
            } else {
                let transformer = SDImageResizingTransformer(size: CGSize(width: 180, height: 140), scaleMode: .aspectFill)
                mapCoverImage.sd_setImage(with: URL(string: map!.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
            }
            mapCoverImage.layer.cornerRadius = 9
            mapCoverImage.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]

            let textString = NSMutableAttributedString(string: map?.mapName ?? "").shrinkLineHeight()
            nameLabel.attributedText = textString
            nameLabel.sizeToFit()
            if map!.secret { lockIcon.isHidden = false }
        } else {
            friendsCoverImage.isHidden = false
            mapCoverImage.isHidden = true
            friendsCoverImage.setUp(avatarURLs: avatarURLs!, annotation: false, completion: { _ in })
            friendsCoverImage.backgroundColor = .white
            friendsCoverImage.layer.cornerRadius = 9
            friendsCoverImage.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]

            let textString = NSMutableAttributedString(string: "Friends map").shrinkLineHeight()
            nameLabel.attributedText = textString
        }

        if postsList.contains(where: { !$0.seenList!.contains(UserDataModel.shared.uid) }) {
            newIndicator.isHidden = false
        }

        /// add image bottom corner radius
        let maskPath = UIBezierPath(roundedRect: mapCoverImage.bounds,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: 9.0, height: 0.0))
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
     //   if map != nil { mapCoverImage.layer.mask = maskLayer } else { friendsCoverImage.layer.mask = maskLayer }
    }

    func setUpView() {
        contentArea.removeFromSuperview()
        contentArea = UIView {
            $0.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            $0.layer.borderWidth = 2.5
            $0.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")!.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
            $0.layer.cornerRadius = 16
            contentView.addSubview($0)
        }
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }

        if newIndicator != nil { newIndicator.removeFromSuperview() }
        newIndicator = UIView {
            $0.backgroundColor = UIColor(named: "SpotGreen")
            $0.layer.cornerRadius = 20 / 2
            $0.isHidden = true
            contentView.addSubview($0)
        }
        newIndicator.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        if mapCoverImage != nil { mapCoverImage.removeFromSuperview() }
        mapCoverImage = UIImageView {
            $0.layer.cornerRadius = 2
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        mapCoverImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(9)
            $0.bottom.equalToSuperview().inset(30)
        }

        if friendsCoverImage != nil { friendsCoverImage.removeFromSuperview() }
        friendsCoverImage = ImageAvatarView {
            $0.clipsToBounds = true
            $0.isHidden = true
            contentArea.addSubview($0)
        }
        friendsCoverImage.snp.makeConstraints {
            $0.edges.equalTo(mapCoverImage.snp.edges)
        }

        if nameLabel != nil { nameLabel.removeFromSuperview() }
        nameLabel = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 15)
            $0.numberOfLines = 0
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.75
            $0.textAlignment = .center
            $0.lineBreakMode = .byTruncatingTail
            contentArea.addSubview($0)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().inset(2)
        }

        if lockIcon != nil { lockIcon.removeFromSuperview() }
        lockIcon = UIImageView {
            $0.image = isSelected ? UIImage(named: "HomeLockIconSelected") : UIImage(named: "HomeLockIcon")
            $0.isHidden = true
            addSubview($0)
        }
        lockIcon.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(nameLabel.snp.top).offset(1.5)
            $0.width.equalTo(21)
            $0.height.equalTo(18.5)
        }

        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if mapCoverImage != nil {
            mapCoverImage.sd_cancelCurrentImageLoad()
        }
    }
}
