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
            }
        }
    }

    func openCamera() {
        if presentedViewController != nil { return }
        Mixpanel.mainInstance().track(event: "HomeScreenAddTap")
        let cameraVC = CameraViewController()
        let nav = UINavigationController(rootViewController: cameraVC)
        nav.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async { self.present(nav, animated: true) }
    }
}
