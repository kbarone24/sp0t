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
        return section == 0 ? 1 : postsList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.section == 0 ? "ProfileHeaderCell" : "BodyCell", for: indexPath)
        guard let userProfile = userProfile else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "Default", for: indexPath)
        }

        if let headerCell = cell as? ProfileHeaderCell {
            headerCell.cellSetup(userProfile: userProfile, relation: relation)
            headerCell.actionButton.addTarget(self, action: #selector(actionButtonTap), for: .touchUpInside)
            headerCell.friendListButton.addTarget(self, action: #selector(friendsListTap), for: .touchUpInside)
            return headerCell

        } else if let postCell = cell as? CustomMapBodyCell {
            postCell.cellSetup(postData: postsList[indexPath.row], transform: true)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: view.frame.width, height: 160)
        }
        return CGSize(width: itemWidth, height: itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            Mixpanel.mainInstance().track(event: "ProfileOpenPostFromGallery")
            if navigationController?.viewControllers.last is PostController { return } // double stack happening here
            let title = "@\(userProfile?.username ?? "")'s posts"
            let postVC = PostController(parentVC: .Map)
            postVC.delegate = self
            DispatchQueue.main.async { self.navigationController?.pushViewController(postVC, animated: true) }
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
}

extension ProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Show navigation bar when user scroll pass the header section
        DispatchQueue.main.async {
            self.navigationItem.title = scrollView.contentOffset.y > 35 ? self.userProfile?.username : ""
        }
        if scrollView.contentOffset.y > UIScreen.main.bounds.height &&
            scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 4) &&
            refreshStatus == .refreshEnabled {
            DispatchQueue.global().async { self.getPosts() }
        }
    }

    func scrollToTop() {
        if collectionView.numberOfSections == 2 {
            DispatchQueue.main.async { self.collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
        }
    }
}
