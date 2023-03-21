//
//  MapPostImageCollectionView.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

protocol PostImageCollectionDelegate: AnyObject {
    func indexChanged(index: Int)
}

extension MapPostImageCell {

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    enum Section: Hashable {
        case main
    }
    
    enum Item: Hashable {
        case item([String])
    }
    
    final class CollectionView: UICollectionView {
        var imageDelegate: PostImageCollectionDelegate?
        var imageIndex: Int {
            let offset = contentOffset.x
            let row = offset / UIScreen.main.bounds.width
            return Int(row)
        }

        private var snapshot = Snapshot() {
            didSet {
                reloadData()
            }
        }

        override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
            super.init(frame: frame, collectionViewLayout: layout)
            allowsSelection = false
            backgroundColor = UIColor(named: "SpotBlack")
            delegate = self
            dataSource = self
            register(StillImageCell.self, forCellWithReuseIdentifier: StillImageCell.reuseID)
            register(AnimatedImageCell.self, forCellWithReuseIdentifier: AnimatedImageCell.reuseID)
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
        guard !snapshot.sectionIdentifiers.isEmpty else {
            return 0
        }
        
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
        case .item(let imageURLs):
            if imageURLs.count > 1,
               let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.AnimatedImageCell.reuseID, for: indexPath) as? MapPostImageCell.AnimatedImageCell {
                cell.configure(animatedImageURLs: imageURLs)
                return cell
                
            } else if imageURLs.count == 1,
                      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MapPostImageCell.StillImageCell.reuseID, for: indexPath) as? MapPostImageCell.StillImageCell {
                cell.configure(imageURL: imageURLs[0])
                return cell
                
            } else {
                return UICollectionViewCell()
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        imageDelegate?.indexChanged(index: imageIndex)
    }
}

extension MapPostImageCell.CollectionView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        return CGSize(width: width, height: height)
    }
}
