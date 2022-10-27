//
//  ExploreMapPreviewCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/22/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

protocol ExploreMapPreviewCellDelegate: AnyObject {
    func cellTapped(id: String)
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
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = 24.0
        
        let collectionView = MapPhotosCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isScrollEnabled = true
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
        
        photosCollectionView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(10.0)
            $0.bottom.leading.trailing.equalToSuperview()
            $0.height.greaterThanOrEqualTo(120.0)
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
        iconView.image = nil
        checkMark.image = UIImage(named: "MapToggleOff")
        onTap = nil
    }
    
    func configure(data: CustomMap, isSelected: Bool, delegate: ExploreMapPreviewCellDelegate?) {
        self.delegate = delegate
        
        guard case let posts = data.postsDictionary.compactMap({ $0.value }),
              !posts.isEmpty
        else { return }
        
        self.onTap = { [weak self] in
            guard let id = data.id else { return }
            self?.delegate?.cellTapped(id: id)
        }
        
        if isSelected {
            checkMark.image = UIImage(named: "MapToggleOn")
        } else {
            checkMark.image = UIImage(named: "MapToggleOff")
        }
        
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        posts.forEach { snapshot.appendItems([.item($0)], toSection: .main) }
        photosCollectionView.configure(snapshot: snapshot)
        
        layoutIfNeeded()
    }
    
    @objc private func tapped() {
        onTap?()
        HapticGenerator.shared.play(.light)
    }
}
