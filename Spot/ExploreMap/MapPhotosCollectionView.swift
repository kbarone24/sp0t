//
//  MapPhotosCollectionView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 10/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

final class MapPhotosCollectionView: UICollectionView {
    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    enum Section: Hashable {
        case main(CustomMap)
    }
    
    enum Item: Hashable {
        case item(MapPost)
        case extra(Int)
    }
    
    private lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: self) { collectionView, indexPath, item in
            
            switch item {
            case .item(let mapPost):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomMapBodyCell.reuseID, for: indexPath) as? CustomMapBodyCell
                cell?.cellSetup(postData: mapPost, transform: false)
                return cell
                
            case .extra(let count):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExtraCountCell.reuseID, for: indexPath) as? ExtraCountCell
                cell?.configure(text: "\(count) more")
                return cell
            }
        }
        
        return datasource
    }()
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        allowsSelection = false
        backgroundColor = .white
        delegate = self
        register(CustomMapBodyCell.self, forCellWithReuseIdentifier: CustomMapBodyCell.reuseID)
        register(ExtraCountCell.self, forCellWithReuseIdentifier: ExtraCountCell.reuseID)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(snapshot: Snapshot) {
        if #available(iOS 15.0, *) {
            datasource.applySnapshotUsingReloadData(snapshot)
        } else {
            datasource.apply(snapshot, animatingDifferences: false)
        }
        
        layoutIfNeeded()
    }
}

extension MapPhotosCollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 130, height: 475)
    }
}
