//
//  NotificationTableExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension NotificationsController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) is ActivityCell {
            let notification = notifications[indexPath.row]
            if notification.type == "mapInvite" {
                openMap(mapID: notification.mapID ?? "")
            } else if let post = notification.postInfo {
                let comment = notification.type.contains("comment")
                openPost(post: post, commentNoti: comment)
            } else if let user = notification.userInfo {
                openProfile(user: user)
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return pendingFriendRequests.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && !pendingFriendRequests.isEmpty {
            return 1
        } else if refresh == .activelyRefreshing {
            return notifications.count + 1
        } else {
            return notifications.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && !pendingFriendRequests.isEmpty {
            let itemWidth = UIScreen.main.bounds.width / 1.89
            let itemHeight = itemWidth * 1.2
            return itemHeight + 1
        } else {
            return 70
        }
    }

    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return pendingFriendRequests.isEmpty ? 0 : 32
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && !pendingFriendRequests.isEmpty, let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as? FriendRequestCollectionCell {
            cell.notificationControllerDelegate = self
            cell.setValues(notifications: pendingFriendRequests)
            return cell
        } else if indexPath.row == notifications.count, let cell = tableView.dequeueReusableCell(withIdentifier: "IndicatorCell") as? ActivityIndicatorCell {
            cell.animate()
            return cell
        } else if let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as? ActivityCell {
            cell.notificationControllerDelegate = self
            cell.setValues(notification: notifications[indexPath.row])
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.backgroundView?.backgroundColor = .white
            view.textLabel?.backgroundColor = .clear
            view.textLabel?.textColor = UIColor(red: 0.671, green: 0.671, blue: 0.671, alpha: 1)
            view.textLabel?.font = UIFont(name: "SFCompactText-Bold", size: 14)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if pendingFriendRequests.isEmpty {
            return "ACTIVITY"
        } else if notifications.isEmpty {
            return "FRIEND REQUESTS"
        } else {
            if section == 0 {
                return "FRIEND REQUESTS"
            } else {
                return "ACTIVITY"
            }
        }
    }
}
