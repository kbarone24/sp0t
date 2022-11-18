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
    func joinMap(map: CustomMap)
}

final class ExploreMapPreviewCell: UITableViewCell {
    typealias Snapshot = NSDiffableDataSourceSnapshot<MapPhotosCollectionView.Section, MapPhotosCollectionView.Item>
    typealias JoinButton = ExploreMapViewModel.JoinButtonType

    private lazy var titleContainer = UIView()

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
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 17.0
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private lazy var headerView = UIView()
    
    private lazy var checkMark: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var joinButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var photosCollectionView: MapPhotosCollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInsetReference = .fromContentInset
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5
        
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
        
        contentView.addSubview(headerView)
        contentView.addSubview(photosCollectionView)

        headerView.addSubview(iconView)
        headerView.addSubview(titleContainer)
        titleContainer.addSubview(titleLabel)
        titleContainer.addSubview(subTitleLabel)
        
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }
        
        iconView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10.0)
            $0.height.equalTo(64.0)
            $0.width.equalTo(64.0)
            $0.leading.equalToSuperview().offset(14.0)
            $0.bottom.equalToSuperview().inset(10.0)
        }

        // auto-sizing container to center with cover image
        titleContainer.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(10.0)
            $0.trailing.equalToSuperview().inset(96.0)
            $0.centerY.equalTo(iconView)
        }
        
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
        
        subTitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(5)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        let itemWidth = (UIScreen.main.bounds.width - 18) / 2.5
        let itemHeight = itemWidth * 1.25 + 2
        photosCollectionView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(headerView.snp.bottom).offset(6.0)
            $0.bottom.equalToSuperview().inset(28.0)
            $0.height.equalTo(itemHeight)
        }
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
        onTap = nil
        checkMark.image = UIImage(named: "MapToggleOff")
        checkMark.removeFromSuperview()
        joinButton.removeFromSuperview()
        headerView.gestureRecognizers?.forEach { headerView.removeGestureRecognizer($0) }
    }
    
    func configure(
        customMap: CustomMap,
        data: [MapPost],
        isSelected: Bool,
        buttonType: JoinButton,
        delegate: ExploreMapPreviewCellDelegate?
    ) {
        self.delegate = delegate
        
        titleLabel.text = customMap.mapName
        
        iconView.sd_setImage(
            with: URL(string: customMap.imageURL),
            placeholderImage: nil,
            options: .highPriority
        )
        
        let attachment = NSTextAttachment()
        attachment.image = UIImage(named: "FriendsIcon")?
            .withRenderingMode(.alwaysTemplate)
            .withTintColor(UIColor(hexString: "B6B6B6"))
        let attachmentString = NSAttributedString(attachment: attachment)
        let myString = NSMutableAttributedString()
        myString.append(attachmentString)
        myString.append(
            NSMutableAttributedString(string: " \(customMap.memberIDs.count)")
        )
        
        myString.addAttributes(
            [
                .foregroundColor: UIColor(hexString: "B6B6B6") as Any
            ],
            range: NSRange(location: 0, length: myString.length)
        )
        
        subTitleLabel.attributedText = myString
        
        switch buttonType {
        case .joinedText:
            self.onTap = { [weak self] in
                self?.delegate?.joinMap(map: customMap)
            }
            
            headerView.addSubview(joinButton)
            joinButton.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.trailing.equalToSuperview().inset(15.0)
                $0.height.equalTo(40.0)
                $0.width.equalTo(75.0)
            }
            
            if isSelected {
                joinButton.setImage(UIImage(named: "JoinedButtonImage"), for: .normal)
            } else {
                joinButton.setImage(UIImage(named: "JoinButtonImage"), for: .normal)
            }
            
        case .checkmark:
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
            headerView.addGestureRecognizer(tapGesture)
            
            self.onTap = { [weak self] in
                self?.delegate?.cellTapped(data: customMap)
            }
            
            headerView.addSubview(checkMark)
            checkMark.snp.makeConstraints {
                $0.centerY.equalToSuperview()
                $0.trailing.equalToSuperview().inset(10.0)
                $0.height.width.equalTo(40.0)
            }
            
            if isSelected {
                checkMark.image = UIImage(named: "MapToggleOn")
            } else {
                checkMark.image = UIImage(named: "MapToggleOff")
            }
        }
        
        var snapshot = Snapshot()
        snapshot.appendSections([.main(customMap)])
        data.forEach {
            snapshot.appendItems([.item($0)], toSection: .main(customMap))
        }
        
        // let remainder = customMap.postIDs.count - 7
        // if remainder > 0 {
        //    snapshot.appendItems([.extra(remainder)], toSection: .main(customMap))
        // }
        
        photosCollectionView.configure(snapshot: snapshot)

        layoutIfNeeded()
    }
    
    @objc private func tapped() {
        onTap?()
        HapticGenerator.shared.play(.light)
    }
}
