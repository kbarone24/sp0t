//
//  SpotPageCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension SpotPageController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return relatedPosts.count
        case 2:
            return communityPosts.count
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "SpotPageHeaderCell" : "SpotPageBodyCell", for: indexPath)
        if let headerCell = cell as? SpotPageHeaderCell {
            headerCell.cellSetup(spotName: spotName, spot: spot)
            return headerCell
        } else if let bodyCell = cell as? SpotPageBodyCell {
            // Setup map post label
            if indexPath == IndexPath(row: 0, section: 1) {
                let frontPadding = "    "
                let bottomPadding = "   "
                if let mapName, mapName != "" {
                    mapPostLabel.text = frontPadding + mapName + bottomPadding
                } else {
                    mapPostLabel.text = frontPadding + "Friends posts" + bottomPadding
                }
                addHeaderView(label: mapPostLabel, cell: cell, communityEmpty: false)
            }
            // set up community post label
            if !communityPosts.isEmpty {
                if indexPath == IndexPath(row: 0, section: 2) {
                    addHeaderView(label: communityPostLabel, cell: cell, communityEmpty: false)
                }
            } else if fetchCommunityPostsComplete {
                if indexPath == IndexPath(row: relatedPosts.count - 1, section: 1) {
                    addHeaderView(label: communityPostLabel, cell: cell, communityEmpty: true)
                }
            }

            bodyCell.cellSetup(mapPost: indexPath.section == 1 ? relatedPosts[indexPath.row] : communityPosts[indexPath.row])

            return bodyCell
        }
        return cell
    }

    func addHeaderView(label: UILabel, cell: UICollectionViewCell, communityEmpty: Bool) {
        if !collectionView.subviews.contains(label) { collectionView.addSubview(label) }
        label.snp.removeConstraints()
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.height.equalTo(31)
            if !communityEmpty {
                $0.top.equalToSuperview().offset(cell.frame.minY - 15.5)
            } else {
                $0.bottom.equalToSuperview().offset(cell.frame.maxY + 15.5)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 130) : CGSize(width: view.frame.width / 2 - 0.5, height: (view.frame.width / 2 - 0.5) * 267 / 194.5)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "SpotPageGalleryPostTap")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (_) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }
            let posts = indexPath.section == 1 ? relatedPosts : communityPosts
            let postVC = PostController(parentVC: .Spot, postsList: posts, selectedPostIndex: indexPath.item, title: spotName)
            postVC.containerDrawerView = containerDrawerView
            barView.isHidden = true
            self.navigationController?.pushViewController(postVC, animated: true)
        }
    }
}

extension SpotPageController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > -91 {
            barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
            titleLabel.text = scrollView.contentOffset.y > 0 ? spotName : ""
        }

        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 500)) && fetching == .refreshEnabled {
            DispatchQueue.global(qos: .userInitiated).async {
                self.fetchRelatedPostsComplete ? self.fetchCommunityPosts() : self.fetchRelatedPosts()
            }
        }
    }
}
