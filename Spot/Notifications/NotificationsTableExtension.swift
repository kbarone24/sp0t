//
//  NotificationTableExtension.swift
//  Spot
//
//  Created by Kenny Barone on 11/14/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension NotificationsController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) is ActivityCell {
            let notification = UserDataModel.shared.notifications[indexPath.row]
            if notification.type == "mapInvite" || notification.type == "mapJoin" || notification.type == "mapFollow" {
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
        return UserDataModel.shared.pendingFriendRequests.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && !UserDataModel.shared.pendingFriendRequests.isEmpty {
            return 1
        } else if UserDataModel.shared.notificationsRefreshStatus == .activelyRefreshing {
            return UserDataModel.shared.notifications.count + 1
        } else {
            return UserDataModel.shared.notifications.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && !UserDataModel.shared.pendingFriendRequests.isEmpty {
            return 205
        } else {
            return 70
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UserDataModel.shared.pendingFriendRequests.isEmpty ? 0 : 32
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && !UserDataModel.shared.pendingFriendRequests.isEmpty,
           let cell = tableView.dequeueReusableCell(withIdentifier: "FriendRequestCollectionCell") as? FriendRequestCollectionCell {
            cell.notificationControllerDelegate = self
            cell.setValues(notifications: UserDataModel.shared.pendingFriendRequests)
            return cell

        } else if indexPath.row == UserDataModel.shared.notifications.count, let cell = tableView.dequeueReusableCell(withIdentifier: "IndicatorCell") as? ActivityIndicatorCell {
            cell.animate()
            return cell

        } else {
            let noti = UserDataModel.shared.notifications[indexPath.row]
            if noti.type == "contactJoin",
                let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseID) as? ContactCell,
                let user = noti.userInfo {
                cell.setUp(contact: user, friendStatus: (user.contactInfo?.pending ?? false) ? .pending : .none, cellType: .notifications)
                cell.delegate = self
                return cell

            } else if let cell = tableView.dequeueReusableCell(withIdentifier: "ActivityCell") as? ActivityCell {
                cell.notificationControllerDelegate = self
          //      cell.setValues(notification: UserDataModel.shared.notifications[indexPath.row])
                return cell
            }
            return UITableViewCell()
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
        if UserDataModel.shared.pendingFriendRequests.isEmpty {
            return "ACTIVITY"
        } else if UserDataModel.shared.notifications.isEmpty {
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
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 350)) && UserDataModel.shared.notificationsRefreshStatus == .refreshEnabled {
            // reload to show activity indicator
            DispatchQueue.main.async { self.tableView.reloadData() }
            UserDataModel.shared.getNotifications()
        }
    }

    public func scrollToTop() {
        if !UserDataModel.shared.notifications.isEmpty {
            DispatchQueue.main.async { self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true) }
        }
    }
}

extension NotificationsController: ContactCellDelegate {
    func addFriend(user: UserProfile) {
        // send friend request, show as pending in table
        if let userID = user.id, let i = UserDataModel.shared.notifications.firstIndex(where: { $0.type == "contactJoin" && $0.senderID == user.id ?? "" }) {
            UserDataModel.shared.notifications[i].userInfo?.contactInfo?.pending = true
            DispatchQueue.main.async { self.tableView.reloadData() }
            friendService?.removeContactNotification(notiID: UserDataModel.shared.notifications[i].id ?? "")
            friendService?.addFriend(receiverID: userID, completion: nil)
        }
    }

    func removeSuggestion(user: UserProfile) {
        // remove from notifications + add to hidden users, show in table
        if let i = UserDataModel.shared.notifications.firstIndex(where: { $0.type == "contactJoin" && $0.senderID == user.id ?? "" }) {
            friendService?.removeContactNotification(notiID: UserDataModel.shared.notifications[i].id ?? "")
            friendService?.removeSuggestion(userID: user.id ?? "")
            UserDataModel.shared.notifications.remove(at: i)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}
