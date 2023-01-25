//
//  FriendsListSearchBarExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension FriendsListController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        queriedFriends.removeAll()
        queriedFriends = getQueriedUsers(userList: friendsList, searchText: searchText)
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchPan?.isEnabled = true
        readyToDismiss = false
        queried = true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchPan?.isEnabled = false
        // lag on ready to dismiss to avoid double tap to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.readyToDismiss = true
        }
    }
}

extension FriendsListController {
    func getQueriedUsers(userList: [UserProfile], searchText: String) -> [UserProfile] {
        var queriedUsers: [UserProfile] = []
        let usernameList = userList.map({ $0.username })
        let nameList = userList.map({ $0.name })

        let filteredUsernames = searchText.isEmpty ? usernameList : usernameList.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        let filteredNames = searchText.isEmpty ? nameList : nameList.filter({(dataString: String) -> Bool in
            return dataString.range(of: searchText, options: [.anchored, .caseInsensitive]) != nil
        })

        for username in filteredUsernames {
            if let user = userList.first(where: { $0.username == username }) { queriedUsers.append(user) }
        }

        for name in filteredNames {
            if let user = userList.first(where: { $0.name == name }) {
                if !queriedUsers.contains(where: { $0.id == user.id }) { queriedUsers.append(user) }
            }
        }
        return queriedUsers
    }
}
