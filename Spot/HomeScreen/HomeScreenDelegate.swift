//
//  HomeScreenDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 12/30/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension HomeScreenContainerController: HomeScreenDelegate {
    func openFindFriends() {
        Mixpanel.mainInstance().track(event: "HomeScreenFindFriendsTap")
        if sheetView != nil { return }
        let findFriendsController = FindFriendsController()
        sheetView = DrawerView(present: findFriendsController, detentsInAscending: [.top, .middle, .bottom]) { [weak self] in
            self?.sheetView = nil
        }
        findFriendsController.containerDrawerView = sheetView
    }

    func openNotifications() {
        Mixpanel.mainInstance().track(event: "HomeScreenNotificationsTap")
        if sheetView != nil { return }
        let notificationsController = NotificationsController()
        sheetView = DrawerView(present: notificationsController, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        notificationsController.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openProfile() {
        Mixpanel.mainInstance().track(event: "HomeScreenProfileTap")
        if sheetView != nil { return }
        let profileVC = ProfileViewController(userProfile: nil)
        sheetView = DrawerView(present: profileVC, detentsInAscending: [.bottom, .middle, .top], closeAction: { [weak self] in
            self?.sheetView = nil
        })
        profileVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openSpot(post: MapPost) {
        Mixpanel.mainInstance().track(event: "MapSpotTap")
        if sheetView != nil { return }
        let spotVC = SpotPageController(mapPost: post, presentedDrawerView: nil)
        sheetView = DrawerView(present: spotVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }
        spotVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openPosts(posts: [MapPost]) {
        Mixpanel.mainInstance().track(event: "MapPostTap")
        if sheetView != nil { return }
        guard let postVC = UIStoryboard(name: "Feed", bundle: nil).instantiateViewController(identifier: "Post") as? PostController else { return }
        postVC.postsList = posts
        sheetView = DrawerView(present: postVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }
        postVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openMap(map: CustomMap) {
        Mixpanel.mainInstance().track(event: "SideBarMapTap")
        if sheetView != nil { return }
        if selectedControllerIndex == 0 { animateSideBar() }

        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [], presentedDrawerView: nil, mapType: .customMap)
        sheetView = DrawerView(present: customMapVC, detentsInAscending: [.bottom, .middle, .top]) { [weak self] in
            self?.sheetView = nil
        }

        customMapVC.containerDrawerView = sheetView
        sheetView?.present(to: .top)
    }

    func openNewMap() {
        Mixpanel.mainInstance().track(event: "SideBarNewMapTap")
        if selectedControllerIndex == 0 { animateSideBar() }
        mapController.openNewMap()
    }

    func drawerOpen() -> Bool {
        return sheetView != nil
    }

    func animateSideBar() {
        mapNavController.view.snp.removeConstraints()
        sideBarController.view.snp.removeConstraints()

        selectedControllerIndex = selectedControllerIndex == 0 ? 1 : 0
        switch selectedControllerIndex {
        case 0: openSideBar()
        case 1: closeSideBar()
        default: return
        }

        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }

    func openExploreMaps() {
        Mixpanel.mainInstance().track(event: "SideBarExploreMapsTap")
        if selectedControllerIndex == 0 { animateSideBar() }
        mapController.openExploreMaps(onboarding: false)
    }
}