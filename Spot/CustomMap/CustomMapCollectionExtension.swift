//
//  CustomMapCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Firebase
import Foundation
import Mixpanel
import UIKit

extension CustomMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : postsList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 ? "CustomMapHeaderCell" : "CustomMapBodyCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(mapData: mapData, memberProfiles: firstMaxFourMapMemberList)
            return headerCell

        } else if let bodyCell = cell as? CustomMapBodyCell {
            bodyCell.cellSetup(postData: postsList[indexPath.row])
            return bodyCell
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: UIScreen.main.bounds.width, height: getHeaderHeight())
        }
        return CGSize(width: itemWidth, height: itemHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 { return }
        let posts = Array(postsList.suffix(from: indexPath.row))
        openPost(posts: posts, row: indexPath.item)
        Mixpanel.mainInstance().track(event: "CustomMapOpenPostFromGallery")
    }

    func getHeaderHeight() -> CGFloat {
        let temp = UILabel(frame: CGRect(x: 19, y: 0, width: UIScreen.main.bounds.width - 38, height: 0))
        temp.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        temp.text = mapData?.mapDescription ?? ""
        temp.numberOfLines = 0
        temp.lineBreakMode = .byWordWrapping
        temp.sizeToFit()
        return temp.frame.height + 153
    }

    func openPost(posts: [MapPost], row: Int) {
        if navigationController?.viewControllers.last is PostController { return } // double stack happening here
        let title = mapData?.mapName ?? ""
        let postVC = PostController(parentVC: .Map, postsList: posts, selectedPostIndex: 0, title: title)
        postVC.delegate = self
        DispatchQueue.main.async { self.navigationController?.pushViewController(postVC, animated: true) }
    }

    func openSpot(spotID: String, spotName: String) {
        let emptyPost = MapPost(
            spotID: spotID,
            spotName: spotName,
            mapID: mapData?.id ?? "",
            mapName: mapData?.mapName ?? ""
        )

        let spotVC = SpotPageController(mapPost: emptyPost)
        navigationController?.pushViewController(spotVC, animated: true)
    }
}

extension CustomMapController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if cancelOnDismiss { return }
        DispatchQueue.main.async {
            self.navigationItem.title = scrollView.contentOffset.y > 25 ? self.mapData?.mapName ?? "" : ""
        }

        // Check if need to refresh according to content position
        if scrollView.contentOffset.y > UIScreen.main.bounds.height &&
            scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 4) &&
            refreshStatus == .refreshEnabled {
            print("refresh on scroll view")
            DispatchQueue.global().async { self.getPosts() }
        }
    }
}
