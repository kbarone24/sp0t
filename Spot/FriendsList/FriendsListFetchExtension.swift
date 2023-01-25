//
//  FriendsListFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase

extension FriendsListController: UIScrollViewDelegate {
    func getFriends() {
        // fetch 20 friends at a time, endless scroll
        let upperBound = endUserPosition + min(20, friendIDs.count - endUserPosition)
        if endUserPosition == friendIDs.count || endUserPosition >= upperBound { return }
        // hold a local friends list object for smooth refresh (friends list was incrementing and removing the activity indicator prematurely)
        var localFriendsList: [UserProfile] = []
        Task {
            for i in endUserPosition..<upperBound {
                let userID = friendIDs[i]
                guard let user = try await userService?.getUserInfo(userID: userID) else { continue }
                if user.username == "" { continue }
                localFriendsList.append(user)
            }

            DispatchQueue.main.async {
                self.refresh = upperBound - self.endUserPosition < 20 ? .refreshDisabled : .refreshEnabled
                self.endUserPosition = upperBound

                self.friendsList.append(contentsOf: localFriendsList)
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height - 350)) && refresh == .refreshEnabled {
            // reload to show activity indicator
            self.refresh = .activelyRefreshing
            DispatchQueue.main.async { self.tableView.reloadData() }
            DispatchQueue.global(qos: .userInitiated).async { self.getFriends() }
        }
    }
}
