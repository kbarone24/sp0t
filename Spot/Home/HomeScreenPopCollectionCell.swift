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
    func cacheContentOffset(offset: CGPoint)
}

class HomeScreenPopCollectionCell: UITableViewCell {
    private var pops = [Spot]()
    weak var delegate: PopCollectionCellDelegate?

    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 74, height: 185)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 36, bottom: 0, right: 36)
        layout.minimumLineSpacing = 17
        return layout
    }()

    private var selectedIndex = 0

    private lazy var collectionView: UICollectionView = {
        // same as with tableView, it acts up if I set up the view using the other style
        let collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        collectionView.backgroundColor = nil
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(HomeScreenPopCell.self, forCellWithReuseIdentifier: HomeScreenPopCell.reuseID)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Default")
        return collectionView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        print("init")
        backgroundColor = .clear
        selectionStyle = .none

        collectionView.delegate = self
        collectionView.dataSource = self
        contentView.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func configure(pops: [Spot], offset: CGPoint) {
        self.pops = pops

        DispatchQueue.main.async {
            self.collectionView.setContentOffset(offset, animated: false)
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.cacheContentOffset(offset: scrollView.contentOffset)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    /*
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let newOffset = getPaginatingOffset(targetContentOffset: targetContentOffset.pointee.x)
        targetContentOffset.pointee = scrollView.contentOffset

        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveEaseOut]) {
            self.collectionView.contentOffset.x = newOffset
        }
    }

    private func getPaginatingOffset(targetContentOffset: CGFloat) -> CGFloat {
        let leftInset = layout.sectionInset.left
        let rowWidthPlusSpacing = layout.itemSize.width + layout.minimumLineSpacing
        let startingContentOffset = rowWidthPlusSpacing * CGFloat(selectedIndex) + leftInset
        let index =
        (targetContentOffset - startingContentOffset) > rowWidthPlusSpacing / 2 ?
        min(pops.count - 1, selectedIndex + 1) :
        (targetContentOffset - startingContentOffset) < -(rowWidthPlusSpacing / 2) ?
        max(0, selectedIndex - 1) :
        selectedIndex

        return CGFloat(index) * rowWidthPlusSpacing + leftInset
    }
    */
}
