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
        if pendingFriendRequests.isEmpty || notifications.isEmpty {
            return 1
        } else {
            if refresh == .activelyRefreshing { return 1 } else {return 2}
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if refresh == .activelyRefreshing {
            return notifications.count + 1
        }
        if pendingFriendRequests.isEmpty {
            return notifications.count
        } else if notifications.isEmpty {
            return 1
        } else {
            if section == 0 {
                return 1
            } else {
                return notifications.count
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if pendingFriendRequests.isEmpty {
            return 70
        } else if notifications.isEmpty {
            return UITableView.automaticDimension
        } else {
            if indexPath.section == 0 {
                return UITableView.automaticDimension
            } else {
                return 70
            }
        }
    }

    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if pendingFriendRequests.isEmpty {
            return 70
        } else if notifications.isEmpty {
            return UITableView.automaticDimension
        } else {
            if indexPath.section == 0 {
                return UITableView.automaticDimension
            } else {
                return 70
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if pendingFriendRequests.isEmpty { return 0 }
        return 32
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let amtFriendReq = pendingFriendRequests.isEmpty ? 0 : 1
        if indexPath.row >= notifications.count + amtFriendReq {
            let cell = tableView.dequeueReusableCell(withIdentifier: "IndicatorCell", for: indexPath) as! ActivityIndicatorCell
            cell.setUp()
            return cell
        }
        if pendingFriendRequests.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
            let notif = notifications[indexPath.row]
            cell.notificationControllerDelegate = self
            cell.set(notification: notif)
            return cell
        } else if notifications.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
            let notifs = pendingFriendRequests
            cell.notificationControllerDelegate = self
            cell.setUp(notifs: notifs)
            return cell
        } else {
            if indexPath.section == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as! FriendRequestCollectionCell
                let notifs = pendingFriendRequests
                cell.notificationControllerDelegate = self

                cell.setUp(notifs: notifs)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as! ActivityCell
                let notif = notifications[indexPath.row]
                cell.notificationControllerDelegate = self
                cell.set(notification: notif)
                return cell
            }
        }
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // tries to query more data when the user is about 5 cells from hitting the end
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 350)) && refresh == .refreshEnabled {
            fetchNotifications(refresh: false)
            refresh = .activelyRefreshing
        }
    }
}
