//
//  HomeScreenNotificationsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/5/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension HomeScreenController {
    func checkLocationAuth() {
        if let alert = viewModel.locationService.checkLocationAuth() {
            present(alert, animated: true)
        }
    }

    @objc func gotUserLocation() {
        refreshLocation()
    }

    @objc func gotNotification(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as? [String: Any] else { return }
        if let spotID = userInfo["spotID"] as? String {
            Mixpanel.mainInstance().track(event: "OpenSpotFromPush")

            let postID = userInfo["postID"] as? String
            let commentID = userInfo["commentID"] as? String
            openSpot(spot: Spot(id: spotID, spotName: ""), postID: postID, commentID: commentID)

        } else {
            Mixpanel.mainInstance().track(event: "OpenNotificationsFromPush")
            openNotifications()
        }
    }

    @objc func notifyLogout() {
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: false)
            self.dismiss(animated: false)
        }
    }
}
