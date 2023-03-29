//
//  TabBarActionsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/15/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension SpotTabBarController {
    @objc func notifyNewPost() {
        DispatchQueue.main.async {
            if self.selectedIndex != 0 {
                self.selectedIndex = 0
                if let nav = self.tabBarController?.viewControllers?.first as? UINavigationController {
                    nav.popToRootViewController(animated: false)
                }
            }
        }
    }

    @objc func gotMap(_ notification: NSNotification) {
        if let map = notification.userInfo?["mapInfo"] as? CustomMap {
            openMap(map: map)
        }
    }

    @objc func gotPost(_ notification: NSNotification) {
        if let post = notification.userInfo?["postInfo"] as? MapPost {
            openPost(post: post)
        }
    }

    private func openPost(post: MapPost) {
        guard post.friendsList.contains(UserDataModel.shared.uid) ||
          (post.inviteList?.contains(UserDataModel.shared.uid) ?? false) else { return }
        let postVC = GridPostViewController(parentVC: .Notifications, postsList: [post], delegate: nil, title: nil, subtitle: nil)

        if let selectedVC = selectedViewController as? UINavigationController {
            selectedVC.pushViewController(postVC, animated: true)
        }
    }

    private func openMap(map: CustomMap) {
        guard !map.secret || map.memberIDs.contains(UserDataModel.shared.uid) else { return }
        let customMapVC = CustomMapController(userProfile: nil, mapData: map, postsList: [])

        if let selectedVC = selectedViewController as? UINavigationController {
            selectedVC.pushViewController(customMapVC, animated: true)
        }
    }

    @objc func gotNotification(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        if let postID = userInfo["postID"] as? String, postID != "" {
            Task {
                do {
                    let post = try? await postService?.getPost(postID: postID)
                    if let post {
                        self.openPost(post: post)
                    }
                }
            }
        } else if let mapID = userInfo["mapID"] as? String, mapID != "" {
            Task {
                do {
                    let map = try? await mapService?.getMap(mapID: mapID)
                    if let map {
                        self.openMap(map: map)
                    }
                }
            }
        } else if let nav = viewControllers?[safe: 3] as? UINavigationController {
            nav.popToRootViewController(animated: false)
            selectedIndex = 3
        }
    }

    @objc func notifyLogout() {
        DispatchQueue.main.async { self.dismiss(animated: false) }
    }

    func openCamera() {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "HomeScreenAddTap")
        let cameraVC = CameraViewController()
        
        let nav = UINavigationController(rootViewController: cameraVC)
        nav.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.present(nav, animated: true)
        }
    }
}
