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
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return postsList.count
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
            bodyCell.cellSetup(mapPost: postsList[indexPath.row])
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 94) : CGSize(width: itemWidth, height: itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2
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

            let posts = Array(postsList.suffix(postsList.count - indexPath.row))
            let vc = GridPostViewController(parentVC: .Notifications, postsList: posts, delegate: nil, title: spot?.spotName ?? "", subtitle: spot?.city ?? "")
            DispatchQueue.main.async {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}

extension SpotPageController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.navigationItem.title = scrollView.contentOffset.y > 30 ? self.spotName : ""
        }

        if scrollView.contentOffset.y > UIScreen.main.bounds.height &&
            scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 4) &&
            refreshStatus == .refreshEnabled {
            DispatchQueue.global().async {
                self.getPosts()
            }
        }
    }
}
