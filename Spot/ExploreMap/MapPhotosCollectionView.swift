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
    
    private(set) var snapshot = Snapshot() {
        didSet {
            reloadData()
        }
    }
    
    private lazy var datasource: DataSource = {
        let datasource = DataSource(collectionView: self) { collectionView, indexPath, item in
            
            switch item {
            case .item(let mapPost):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomMapBodyCell.reuseID, for: indexPath) as? CustomMapBodyCell
                cell?.cellSetup(postData: mapPost, transform: true, cornerRadius: 9)
                return cell
                
            case .extra(let count):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExtraCountCell.reuseID, for: indexPath) as? ExtraCountCell
                cell?.configure(text: "\(count) more")
                return cell
            }
        }
        
        return datasource
    }()
    
    private weak var exploreMapDelegate: ExploreMapPreviewCellDelegate?
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        allowsSelection = false
        backgroundColor = .white
        delegate = self
        dataSource = self
        register(CustomMapBodyCell.self, forCellWithReuseIdentifier: CustomMapBodyCell.reuseID)
        register(ExtraCountCell.self, forCellWithReuseIdentifier: ExtraCountCell.reuseID)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(snapshot: Snapshot, delegate: ExploreMapPreviewCellDelegate?, position: CGPoint) {
        // datasource.apply(snapshot, animatingDifferences: false)
        self.snapshot = snapshot
        self.exploreMapDelegate = delegate
        contentOffset = position
    }
}

extension MapPhotosCollectionView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       // let section = snapshot.sectionIdentifiers[section]
       // return snapshot.numberOfItems(inSection: section)
        return 250
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let items = snapshot.itemIdentifiers(inSection: section)
        let iterations = indexPath.row / items.count
        let itemIndex = indexPath.row - iterations * items.count
        let item = snapshot.itemIdentifiers(inSection: section)[itemIndex]
        
        switch item {
        case .item(let mapPost):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomMapBodyCell.reuseID, for: indexPath) as? CustomMapBodyCell else {
                return UICollectionViewCell()
            }
            cell.cellSetup(postData: mapPost, transform: false, cornerRadius: 9)
            return cell
            
        case .extra(let count):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ExtraCountCell.reuseID, for: indexPath) as? ExtraCountCell else {
                return UICollectionViewCell()
            }
            cell.configure(text: "\(count) more")
            return cell
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let section = snapshot.sectionIdentifiers[0]
        switch section {
        case .main(let map):
            exploreMapDelegate?.cacheScrollPosition(map: map, position: scrollView.contentOffset)
        }
    }
}

extension MapPhotosCollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (UIScreen.main.bounds.width - 18) / 2.85
        let height = width * 1.25
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
    }
}
