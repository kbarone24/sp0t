//
//  FindFriendsFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 10/27/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import MapKit

extension FindFriendsController {
    func fetchTableData() {
        // run fetch only once friends list fetched from map
        guard UserDataModel.shared.friendsFetched else { return }
        DispatchQueue.global().async { self.getContacts() }
    }

    func runNewAuthContactsFetch() {
        DispatchQueue.global().async { self.getContacts() }
    }

    func getContacts() {
        // show contacts empty state
        if ContactsFetcher.shared.contactsAuth != .authorized {
            self.reloadTableView()
            return
        }

        DispatchQueue.main.async { self.activityIndicator.startAnimating() }
        let contactsFetcher = ContactsFetcher()
        contactsFetcher.runFetch { contacts, err in
            if err != nil { print("err", err as Any) }
            for contact in contacts {
                self.contacts.append((contact, .none))
            }
            self.reloadTableView()
        }
    }

    private func reloadTableView() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.tableView.reloadData()
        }
    }
}
