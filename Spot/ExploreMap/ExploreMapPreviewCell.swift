//
//  ExploreMapPreviewCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

protocol ExploreMapPreviewCellDelegate: AnyObject {
    func cellTapped(data: CustomMap)
}

final class ExploreMapPreviewCell: UITableViewCell {
    
    typealias Snapshot = NSDiffableDataSourceSnapshot<MapPhotosCollectionView.Section, MapPhotosCollectionView.Item>
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Heavy", size: 18)
        label.textColor = .black
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private lazy var subTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14)
        label.numberOfLines = 0
        label.textColor = UIColor(hexString: "B6B6B6")
        label.textAlignment = .left
        return label
    }()
    
    private lazy var iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var checkMark: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var photosCollectionView: MapPhotosCollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInsetReference = .fromContentInset
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        
        let collectionView = MapPhotosCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isScrollEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        
        return collectionView
    }()
    
    private weak var delegate: ExploreMapPreviewCellDelegate?
    private var onTap: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .white
        contentView.backgroundColor = .white
        
        let headerView = UIView()
        
        contentView.addSubview(headerView)
        contentView.addSubview(photosCollectionView)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(iconView)
        headerView.addSubview(checkMark)
        headerView.addSubview(subTitleLabel)
        
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }
        
        iconView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10.0)
            $0.height.equalTo(64.0)
            $0.width.equalTo(60.0)
            $0.leading.equalToSuperview().offset(18.0)
            $0.bottom.equalToSuperview().inset(10.0)
        }
        
        titleLabel.snp.makeConstraints {
            $0.bottom.equalTo(headerView.snp.centerY).inset(2.5)
            $0.leading.equalTo(iconView.snp.trailing).offset(10.0)
            $0.trailing.equalToSuperview().inset(55.0)
        }
        
        subTitleLabel.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.centerY).offset(2.5)
            $0.leading.equalTo(titleLabel.snp.leading)
            $0.trailing.equalToSuperview().inset(55.0)
        }
        
        checkMark.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(10.0)
            $0.height.width.equalTo(40.0)
        }
        
        photosCollectionView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(10.0)
            $0.bottom.trailing.equalToSuperview().inset(18.0)
            $0.leading.equalToSuperview().offset(18.0)
            $0.height.greaterThanOrEqualTo(180.0)
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
        headerView.addGestureRecognizer(tapGesture)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        subTitleLabel.text = ""
        subTitleLabel.attributedText = nil
        iconView.image = nil
        iconView.sd_cancelCurrentImageLoad()
        checkMark.image = UIImage(named: "MapToggleOff")
        onTap = nil
    }
    
    func configure(customMap: CustomMap, data: [MapPost], isSelected: Bool, delegate: ExploreMapPreviewCellDelegate?) {
        self.delegate = delegate
        
        self.onTap = { [weak self] in
            self?.delegate?.cellTapped(data: customMap)
        }
        
        titleLabel.text = customMap.mapName
        
        iconView.sd_setImage(
            with: URL(string: customMap.imageURL),
            placeholderImage: nil,
            options: .highPriority
        )
        
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "FriendsIcon")
        let attachmentString = NSAttributedString(attachment: attachment)
        let myString = NSMutableAttributedString()
        myString.append(attachmentString)
        myString.append(
            NSMutableAttributedString(string: " \(customMap.memberIDs.count)")
        )
        subTitleLabel.attributedText = myString
        
        if isSelected {
            checkMark.image = UIImage(named: "MapToggleOn")
        } else {
            checkMark.image = UIImage(named: "MapToggleOff")
        }
        
        var snapshot = Snapshot()
        snapshot.appendSections([.main(customMap)])
        data.forEach {
            snapshot.appendItems([.item($0)], toSection: .main(customMap))
        }
        
        let remainder = customMap.postIDs.count - 7
        if remainder > 0 {
            snapshot.appendItems([.extra(remainder)], toSection: .main(customMap))
        }
        
        photosCollectionView.configure(snapshot: snapshot)
        
        layoutIfNeeded()
    }
    
    @objc private func tapped() {
        onTap?()
        HapticGenerator.shared.play(.light)
    }
}
