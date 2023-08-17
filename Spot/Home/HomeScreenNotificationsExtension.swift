//
//  HomeScreenNotificationsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension HomeScreenController {
    func checkLocationAuth() {
        if let alert = viewModel.locationService.checkLocationAuth() {
            present(alert, animated: true)
        }
    }

    @objc func gotUserLocation() {
        refreshLocation()
    }

    @objc func gotMap(_ notification: NSNotification) {
        if let map = notification.userInfo?["mapInfo"] as? CustomMap {
         //   openMap(map: map)
        }
    }

    @objc func gotPost(_ notification: NSNotification) {
        if let post = notification.userInfo?["postInfo"] as? MapPost {
         //   openPost(post: post)
        }
    }

    private func openPost(post: MapPost, commentNoti: Bool? = false) {
 //       guard post.privacyLevel == "public" || (post.friendsList.contains(UserDataModel.shared.uid) ||
 //         (post.inviteList?.contains(UserDataModel.shared.uid) ?? false)) else { return }
        // push spot vc, passthrough selected post
        /*
        if let selectedVC = selectedViewController as? UINavigationController {
            selectedVC.pushViewController(postVC, animated: true)
        }
        */
    }

    @objc func gotNotification(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        /*
        if let mapID = userInfo["mapID"] as? String, mapID != "" {
            Task {
                do {
                    let map = try? await mapService?.getMap(mapID: mapID)
                    if let map {
                        self.openMap(map: map)
                    }
                }
            }
        } else if let postID = userInfo["postID"] as? String, postID != "" {
            Task {
                do {
                    let post = try? await postService?.getPost(postID: postID)
                    if let post {
                        let notiString = userInfo["commentNoti"] as? String
                        let commentNoti = notiString == "yes"
                        self.openPost(post: post, commentNoti: commentNoti)
                    }
                }
            }
        } else if let nav = viewControllers?[safe: 3] as? UINavigationController {
            nav.popToRootViewController(animated: false)
            selectedIndex = 3
        }
        */
    }

    @objc func notifyLogout() {
        print("logout")
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: false)
            self.dismiss(animated: false)
        }
    }
}
