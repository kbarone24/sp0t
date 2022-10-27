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
        case main
    }
    
    enum Item: Hashable {
        case item(MapPost)
    }
    
    private lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: self) { collectionView, indexPath, item in
            
            switch item {
            case .item(let mapPost):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomMapBodyCell.reuseID, for: indexPath) as? CustomMapBodyCell
                cell?.cellSetup(postData: mapPost)
                return cell
            }
        }
        
        return datasource
    }()
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        allowsSelection = false
        backgroundColor = .white
        register(CustomMapBodyCell.self, forCellWithReuseIdentifier: CustomMapBodyCell.reuseID)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(snapshot: Snapshot) {
        datasource.apply(snapshot, animatingDifferences: false)
        layoutIfNeeded()
    }
}
