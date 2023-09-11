//
//  HomeScreenPopCollectionCell.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol PopCollectionCellDelegate: AnyObject {
    func open(pop: Spot)
}

class HomeScreenPopCollectionCell: UITableViewCell {
    var pops = [Spot]()
    weak var delegate: PopCollectionCellDelegate?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 10, height: 192)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        layout.minimumInteritemSpacing = 10

        // same as with tableView, it acts up if I set up the view using the other style
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        collectionView.backgroundColor = nil
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(HomeScreenPopCell.self, forCellWithReuseIdentifier: HomeScreenPopCell.reuseID)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return collectionView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        collectionView.delegate = self
        collectionView.dataSource = self
        contentView.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func configure(pops: [Spot]) {
        self.pops = pops
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HomeScreenPopCollectionCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pops.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeScreenPopCell.reuseID, for: indexPath) as? HomeScreenPopCell {
            cell.configure(pop: pops[indexPath.row])
            return cell
        }
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.open(pop: pops[indexPath.row])
    }
}
