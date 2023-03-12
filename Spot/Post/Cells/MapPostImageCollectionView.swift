//
//  MapPostImageCollectionView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

extension MapPostImageCell {
 
    final class CollectionView: UICollectionView {
        typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
        typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
        
        enum Section: Hashable {
            case main
        }
        
        enum Item: Hashable {
            case item([String])
        }
        
        private var snapshot = Snapshot() {
            didSet {
                reloadData()
            }
        }
        
        private weak var exploreMapDelegate: ExploreMapPreviewCellDelegate?
        
        override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
            super.init(frame: frame, collectionViewLayout: layout)
            allowsSelection = false
            backgroundColor = UIColor(named: "SpotBlack")
            delegate = self
            dataSource = self
            register(CustomMapBodyCell.self, forCellWithReuseIdentifier: CustomMapBodyCell.reuseID)
            register(ExtraCountCell.self, forCellWithReuseIdentifier: ExtraCountCell.reuseID)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure(snapshot: Snapshot) {
            self.snapshot = snapshot
        }
    }
}

extension MapPostImageCell.CollectionView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let section = snapshot.sectionIdentifiers[section]
        return snapshot.numberOfItems(inSection: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let items = snapshot.itemIdentifiers(inSection: section)
        let iterations = indexPath.row / items.count
        let itemIndex = indexPath.row - iterations * items.count
        let item = snapshot.itemIdentifiers(inSection: section)[itemIndex]
        
        switch item {
        case .item(let images):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomMapBodyCell.reuseID, for: indexPath) as? CustomMapBodyCell else {
                return UICollectionViewCell()
            }
            // cell.cellSetup(postData: mapPost, transform: false, cornerRadius: 9)
            return cell
        }
    }
}

extension MapPostImageCell.CollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height - 30.0
        return CGSize(width: width, height: height)
    }
}
