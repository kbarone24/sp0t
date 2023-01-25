//
//  FriendsListTableExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/24/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension FriendsListController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if queried {
            return queriedFriends.count
        } else {
            var friendsCount = friendsList.count
            // show extra row for activity indicator
            if refresh == .activelyRefreshing { friendsCount += 1 }
            return friendsCount
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let dataModel = queried ? queriedFriends : friendsList

        if indexPath.row < dataModel.count, let cell = tableView.dequeueReusableCell(withIdentifier: "FriendsCell", for: indexPath) as? ChooseFriendsCell {
            let friend = dataModel[indexPath.row]
            let editable = !confirmedIDs.contains(friend.id ?? "")
            cell.setUp(user: friend, allowsSelection: allowsSelection, editable: editable, showAddFriend: canAddFriends)
            return cell

        } else if let cell = tableView.dequeueReusableCell(withIdentifier: "IndicatorCell") as? ActivityIndicatorCell {
            cell.animate()
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 63
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = queried ? queriedFriends[indexPath.row] : friendsList[indexPath.row]
        let id = user.id ?? ""

        if allowsSelection {
            if confirmedIDs.contains(id) { return } /// cannot unselect confirmed ID
            Mixpanel.mainInstance().track(event: "FriendsListSelectFriend")

            if queried, let i = queriedFriends.firstIndex(where: { $0.id == id }) {
                queriedFriends[i].selected = !queriedFriends[i].selected
            }
            if let i = friendsList.firstIndex(where: { $0.id == id }) {
                friendsList[i].selected = !friendsList[i].selected
            }
            DispatchQueue.main.async { self.tableView.reloadData() }

        } else {
            DispatchQueue.main.async {
                self.delegate?.finishPassing(openProfile: user)
                self.dismiss(animated: true)
            }
        }
    }
}
