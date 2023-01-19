//
//  ProfileCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/26/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension ProfileViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // always show empty posts cell for non-friend
        let showCollectionItems = (noPostLabel.isHidden && (!maps.isEmpty || !posts.isEmpty)) || (relation != .myself && relation != .friend)
        return section == 0 ? 1 : showCollectionItems ? maps.count + 1 : 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
        guard let userProfile = userProfile else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }

        if let headerCell = cell as? ProfileHeaderCell {
            headerCell.cellSetup(userProfile: userProfile, relation: relation)
            headerCell.actionButton.addTarget(self, action: #selector(actionButtonTap), for: .touchUpInside)
            headerCell.friendListButton.addTarget(self, action: #selector(friendsListTap), for: .touchUpInside)
            return headerCell

        } else if let mapCell = cell as? ProfileMyMapCell {
            mapCell.cellSetup(userAccount: userProfile.username, posts: posts, relation: relation)
            return mapCell

        } else if let bodyCell = cell as? ProfileBodyCell {
            bodyCell.cellSetup(mapData: maps[indexPath.row - 1], userID: userProfile.id ?? "")
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return section == 0 ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.frame.width - 40) / 2
        return indexPath.section == 0 ? CGSize(width: view.frame.width, height: 160) : CGSize(width: width, height: 230)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "ProfileMapSelect")
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            } completion: { (_) in
                UIView.animate(withDuration: 0.15) {
                    collectionCell?.transform = .identity
                }
            }

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.row == 0 ? "ProfileMyMapCell" : "ProfileBodyCell", for: indexPath)
            if cell is ProfileMyMapCell {
                guard relation == .friend || relation == .myself else { return }
                let mapData = getMyMap()
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: mapData, postsList: [], presentedDrawerView: containerDrawerView, mapType: .myMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            } else if cell is ProfileBodyCell {
                let customMapVC = CustomMapController(userProfile: userProfile, mapData: maps[indexPath.row - 1], postsList: [], presentedDrawerView: containerDrawerView, mapType: .customMap)
                navigationController?.pushViewController(customMapVC, animated: true)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            let collectionCell = collectionView.cellForItem(at: indexPath)
            UIView.animate(withDuration: 0.15) {
                collectionCell?.transform = .identity
            }
        }
    }

    func getMyMap() -> CustomMap {
        var mapData = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        mapData.createPosts(posts: posts)
        return mapData
    }
}

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Show navigation bar when user scroll pass the header section
        if scrollView.contentOffset.y > -91.0 {
            navigationController?.navigationBar.isTranslucent = false
            if scrollView.contentOffset.y > 35 {
                self.title = userProfile?.name
            } else { self.title = ""}
        }
    }
}
