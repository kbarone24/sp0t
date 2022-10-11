//
//  CustomMapCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension CustomMapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 1 : postsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.section == 0 && mapType == .customMap ? "CustomMapHeaderCell" : indexPath.section == 0 ? "SimpleMapHeaderCell" : "CustomMapBodyCell"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        if let headerCell = cell as? CustomMapHeaderCell {
            headerCell.cellSetup(mapData: mapData, fourMapMemberProfile: firstMaxFourMapMemberList)
            return headerCell
            
        } else if let headerCell = cell as? SimpleMapHeaderCell {
            let text = mapType == .friendsMap ? "Friends map" : "@\(userProfile!.username)'s posts"
            headerCell.mapText = text
            return headerCell
            
        } else if let bodyCell = cell as? CustomMapBodyCell {
            bodyCell.cellSetup(postData: postsList[indexPath.row])
            return bodyCell
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return indexPath.section == 0 && mapType == .customMap ? CGSize(width: UIScreen.main.bounds.width, height: getHeaderHeight()) : indexPath.section == 0 ? CGSize(width: view.frame.width, height: 35) : CGSize(width: UIScreen.main.bounds.width/2 - 0.5, height: (UIScreen.main.bounds.width/2 - 0.5) * 267 / 194.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 { return }
        openPost(posts: postsList, row: indexPath.item)
        Mixpanel.mainInstance().track(event: "CustomMapOpenPostFromGallery")
    }
    
    func getHeaderHeight() -> CGFloat {
        let temp = UILabel(frame: CGRect(x: 19, y: 0, width: UIScreen.main.bounds.width - 38, height: 0))
        temp.font = UIFont(name: "SFCompactText-Semibold", size: 13.5)
        temp.text = mapData!.mapDescription ?? ""
        temp.numberOfLines = 0
        temp.lineBreakMode = .byWordWrapping
        temp.sizeToFit()
        return temp.frame.height + 148
    }
                                                                        
    func openPost(posts: [MapPost], row: Int) {
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        if navigationController!.viewControllers.last is PostController { return } // double stack happening here
        setDrawerValuesForViewAppear()
        postVC.postsList = posts
        postVC.selectedPostIndex = row
        postVC.containerDrawerView = containerDrawerView
        DispatchQueue.main.async { self.navigationController!.pushViewController(postVC, animated: true) }
    }
    
    func openSpot(spotID: String, spotName: String) {
        var emptyPost = MapPost(caption: "", friendsList: [], imageURLs: [], likers: [], postLat: 0, postLong: 0, posterID: "", timestamp: Timestamp(date: Date()))
        emptyPost.spotID = spotID
        emptyPost.spotName = spotName
        emptyPost.mapID = mapData!.id
        emptyPost.mapName = mapData!.mapName
        let spotVC = SpotPageController(mapPost: emptyPost, presentedDrawerView: containerDrawerView)
        navigationController?.pushViewController(spotVC, animated: true)
    }
    
    func setDrawerValuesForViewAppear() {
        if containerDrawerView?.status == .Top { presentToFullScreen = true; offsetOnDismissal = collectionView.contentOffset.y }
        currentContainerCanDragStatus = containerDrawerView?.canDrag
    }
}

extension CustomMapController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let itemHeight = UIScreen.main.bounds.width * 1.373
        
        // Check if need to refresh according to content position
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - itemHeight * 1.5)) && refresh == .refreshEnabled {
            self.getPosts()
            refresh = .activelyRefreshing
        }
        
        if containerDrawerView == nil { return }
        if topYContentOffset != nil && containerDrawerView?.status == .Top {
            // Disable the bouncing effect when scroll view is scrolled to top
            if scrollView.contentOffset.y <= topYContentOffset! {
                scrollView.contentOffset.y = topYContentOffset!
            }
            // Show navigation bar + adjust offset for small header
            if scrollView.contentOffset.y > topYContentOffset! {
                UIView.animate(withDuration: 0.3) {
                    self.barView.backgroundColor = scrollView.contentOffset.y > 0 ? .white : .clear
                }
                var titleText = ""
                if scrollView.contentOffset.y > 0 {
                    titleText = mapType == .friendsMap ? "Friends map" : mapType == .myMap ? "@\(userProfile!.username)'s posts" : mapData?.mapName ?? ""
                }
                titleLabel.text = titleText
                titleLabel.sizeToFit()
            }
        }
        
        // Set scroll view content offset when in transition
        if
            middleYContentOffset != nil &&
            topYContentOffset != nil &&
            scrollView.contentOffset.y <= middleYContentOffset! &&
            containerDrawerView!.slideView.frame.minY >= (middleYContentOffset! - topYContentOffset!)
        {
            scrollView.contentOffset.y = middleYContentOffset!
        }
    }
}
