//
//  FindFriendsSearchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel

extension FindFriendsController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        activeSearch = true
        DispatchQueue.main.async { self.tableView.reloadData() }
        Mixpanel.mainInstance().track(event: "FindFriendsUserClickedSearchBar")
        UIView.animate(withDuration: 0.1) {
            searchBar.snp.updateConstraints {
                $0.trailing.equalToSuperview().offset(-76)
            }
            self.view.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.cancelButton.isHidden = false
            self.searchIndicator.isHidden = true
        }
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.1) {
            self.cancelButton.isHidden = true
            searchBar.snp.updateConstraints {
                $0.trailing.equalToSuperview().offset(-16)
            }
            self.view.layoutIfNeeded()
        }

        searchBar.text = ""
        activeSearch = false
        emptyQueries()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.searchIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTextGlobal = searchText.lowercased()
        emptyQueries()

        // reset table for new search or abandon search function
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if !self.activeSearch || searchBar.text == "" {
                self.searchIndicator.stopAnimating()
                return
            } else if !self.searchIndicator.isAnimating {
                self.activityIndicator.stopAnimating()
                self.searchIndicator.startAnimating()

            }
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.runQuery), object: nil)
        self.perform(#selector(self.runQuery), with: nil, afterDelay: 0.65)
    }

    private func emptyQueries() {
        queryUsers.removeAll()
    }

    @objc private func runQuery() {
        queryUsers.removeAll()
        DispatchQueue.global(qos: .userInitiated).async {
            self.runUsernameQuery(searchText: self.searchTextGlobal)
        }
    }

   private func runUsernameQuery(searchText: String) {
        Task {
            let users = try? await self.userService?.getUsersFrom(searchText: searchText, limit: 8)
            for user in users ?? [] {
                if self.shouldAppendUser(id: user.id ?? "", searchText: searchText) {
                    let status = self.getFriendsStatus(id: user.id ?? "")
                    self.queryUsers.append((user, status))
                }
            }
            self.reloadResultsTable()
        }
    }

    private func queryValid(searchText: String) -> Bool {
        return searchText == searchTextGlobal && searchText != ""
    }

    private func shouldAppendUser(id: String, searchText: String) -> Bool {
        return queryValid(searchText: searchText) && !self.queryUsers.contains(where: { $0.0.id == id }) && id != self.uid
    }

    private func getFriendsStatus(id: String) -> FriendStatus {
        let status: FriendStatus = UserDataModel.shared.userInfo.friendIDs.contains(id) ?
            .friends : UserDataModel.shared.userInfo.pendingFriendRequests.contains(id) ?
            .pending :
            .none
        return status
    }

    private func reloadResultsTable() {
        if !activeSearch { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sortSearchResults()
            self.searchIndicator.stopAnimating()
            self.tableView.reloadData()
            return
        }
    }

    private func sortSearchResults() {
        // 1. strangers 2. pending 3. friends
        queryUsers = queryUsers.sorted { p1, p2 in
            if p1.1 != .none && p2.1 != .none {
                return p1.1 == .pending && p2.1 != .pending
            }
            return p1.1 == .none && p2.1 != .none
        }
    }
}
