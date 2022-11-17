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
    private lazy var contentArea: UIView = {
        let view = UIView()
        view.layer.borderWidth = 2.5
        view.layer.cornerRadius = 16
        return view
    }()
    private lazy var newIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "SpotGreen")
        view.layer.cornerRadius = 20 / 2
        view.isHidden = true
        return view
    }()
    private lazy var mapCoverImage: UIImageView = {
        let view = UIImageView()
        view.layer.cornerRadius = 2
        view.clipsToBounds = true
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 2
        view.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        return view
    }()
    private lazy var lockIcon: UIImageView = {
        let view = UIImageView()
        view.isHidden = true
        return view
    }()
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 15)
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    override var isSelected: Bool {
        didSet {
            setSelectedValues()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUp(map: CustomMap, postsList: [MapPost]) {
        setSelectedValues()

        mapCoverImage.image = UIImage()
        if map.id == "9ECABEF9-0036-4082-A06A-C8943428FFF4" {
            mapCoverImage.image = UIImage(named: "HeelsmapCover")
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 180, height: 140), scaleMode: .aspectFill)
            mapCoverImage.sd_setImage(with: URL(string: map.imageURL), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

     //   let textString = NSMutableAttributedString(string: map.mapName).shrinkLineHeight()
      //  nameLabel.attributedText = textString
      //  print("contains emoji", nameLabel.text?.contains(where: {$0.isASCII}))
        nameLabel.text = map.mapName
        nameLabel.sizeToFit()

        lockIcon.isHidden = !map.secret
        newIndicator.isHidden = !(postsList.contains(where: { !($0.seenList?.contains(UserDataModel.shared.uid) ?? false) }))
    }

    func setUpView() {
        contentView.addSubview(contentArea)
        contentArea.snp.makeConstraints {
            $0.top.leading.equalToSuperview().offset(3)
            $0.bottom.trailing.equalToSuperview()
        }

        contentView.addSubview(newIndicator)
        newIndicator.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        contentArea.addSubview(mapCoverImage)
        mapCoverImage.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(9)
            $0.bottom.equalToSuperview().inset(34)
        }

        contentArea.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.top.equalTo(mapCoverImage.snp.bottom).offset(2)
            $0.bottom.equalToSuperview().inset(3)
        }

        contentView.addSubview(lockIcon)
        lockIcon.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(nameLabel.snp.top).offset(1.5)
            $0.width.equalTo(21)
            $0.height.equalTo(18.5)
        }
        layoutIfNeeded()

        let maskPath = UIBezierPath(roundedRect: mapCoverImage.bounds,
                                    byRoundingCorners: [.topLeft, .topRight],
                                    cornerRadii: CGSize(width: 9.0, height: 0.0))
        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
        mapCoverImage.layer.mask = maskLayer
    }

    func setSelectedValues() {
        contentArea.backgroundColor = isSelected ? UIColor(red: 0.843, green: 0.992, blue: 1, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        contentArea.layer.borderColor = isSelected ? UIColor(named: "SpotGreen")?.cgColor : UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1).cgColor
        lockIcon.image = isSelected ? UIImage(named: "HomeLockIconSelected") : UIImage(named: "HomeLockIcon")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapCoverImage.sd_cancelCurrentImageLoad()
    }
}
