//
//  MapsCollectionExtension.swift
//  Spot
//
//  Created by Kenny Barone on 7/21/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import FirebaseUI
import Foundation
import Mixpanel
import UIKit

extension MapController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if feedLoaded {
            let extraCells = userInChapelHill() ? 3 : 2
            return UserDataModel.shared.userInfo.mapsList.count + extraCells
        }
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if !feedLoaded, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapLoadingCell", for: indexPath) as? MapLoadingCell {
            // display loading cell
            return cell
        }
        if indexPath.row == UserDataModel.shared.userInfo.mapsList.count + 1, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CampusMapCell", for: indexPath) as? CampusMapCell {
            return cell
        }
        if indexPath.row == UserDataModel.shared.userInfo.mapsList.count + 2, let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddMapCell", for: indexPath) as? AddMapCell {
            // display new map button
            return cell
        }
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MapCell", for: indexPath) as? MapHomeCell {
            let map = UserDataModel.shared.userInfo.mapsList[safe: indexPath.row - 1]
            var avatarURLs = map == nil ? friendsPostsDictionary.values.map({ $0.userInfo?.avatarURL ?? "" }).uniqued().prefix(5) : []
            if avatarURLs.count < 5 && !avatarURLs.contains(UserDataModel.shared.userInfo.avatarURL ?? "") { avatarURLs.append(UserDataModel.shared.userInfo.avatarURL ?? "") }
            let postsList = map == nil ? friendsPostsDictionary.map({ $0.value }) : map!.postsDictionary.map({ $0.value })
            cell.setUp(map: map, avatarURLs: Array(avatarURLs), postsList: postsList)
            cell.isSelected = selectedItemIndex == indexPath.row
            return cell
        }
        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == UserDataModel.shared.userInfo.mapsList.count + 1 {
            openExploreMaps()
            return
        } else if indexPath.item == UserDataModel.shared.userInfo.mapsList.count + 2 {
            // launch new map
            openNewMap()
            return
        } else if indexPath.item == selectedItemIndex {
            openSelectedMap()
            return
        }
        HapticGenerator.shared.play(.light)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        selectMapAt(index: indexPath.item)
    }

    func selectMapAt(index: Int) {
        Mixpanel.mainInstance().track(event: "MapControllerSelectMapAt", properties: ["index": index])
        DispatchQueue.main.async {
            if index != self.selectedItemIndex {
                self.selectedItemIndex = index
                self.setNewPostsButtonCount()
                self.addMapAnnotations(index: index, reload: false)
                if self.addFriendsView != nil { self.addFriendsView.removeFromSuperview() }
                if index != 0 { UserDataModel.shared.userInfo.mapsList[index - 1].selected.toggle() }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 9 + 5 * 3
        let itemWidth = (UIScreen.main.bounds.width - spacing) / 3.7
        let itemHeight = itemWidth * 0.95
        let firstItemWidth = itemWidth * 1.15

        if feedLoaded {
            if indexPath.item == 0 {
                // friends cell
                return CGSize(width: firstItemWidth, height: itemHeight)
            }
            // standard cell
            return CGSize(width: itemWidth, height: itemHeight)
        }
        // loading indicator
        return CGSize(width: UIScreen.main.bounds.width, height: itemHeight)
    }

    func addMapAnnotations(index: Int, reload: Bool) {
        mapView.removeAllAnnos()
        var map = getSelectedMap()
        // create temp map to represent friends map
        if map == nil { map = getFriendsMapObject() }
        for group in map!.postGroup { mapView.addSpotAnnotation(group: group, map: map!) }

        if !reload {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                guard let self = self else { return }
                self.centerMapOnMapPosts(animated: false)
            })
        }
    }

    func getFriendsMapObject() -> CustomMap {
        var map = CustomMap(founderID: "", imageURL: "", likers: [], mapName: "", memberIDs: [], posterIDs: [], posterUsernames: [], postIDs: [], postImageURLs: [], secret: false, spotIDs: [])
        map.postsDictionary = friendsPostsDictionary
        map.postGroup = postGroup
        return map
    }
}
