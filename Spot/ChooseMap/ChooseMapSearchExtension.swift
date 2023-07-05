//
//  ChooseMapSearchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 6/12/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension ChooseMapController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        queried = searchText != ""
        searchTextGlobal = searchText
        queryMaps.removeAll()

        if queried {
            mapSearching = true
            runMapSearch(searchText: searchText)
        } else {
            // reload table immediately, cancel search, and remove previous requests
            reloadResultsTable()
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runDatbaseQuery), object: nil)
        }
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        tableView.isScrollEnabled = false
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        tableView.isScrollEnabled = true
    }
}

extension ChooseMapController {
    private func runMapSearch(searchText: String) {
        /// cancel search requests after user stops typing for 0.4/sec
        queryUserMaps()
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runDatbaseQuery), object: nil)
        self.perform(#selector(runDatbaseQuery), with: nil, afterDelay: 0.4)
    }

    private func queryUserMaps() {
        queryMaps.removeAll()
        queryMaps = mapService?.queryMapsFrom(mapsList: customMaps, searchText: searchTextGlobal) ?? []
        // reload table with existing mapsList queried
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    @objc private func runDatbaseQuery() {
        // query DB for community maps
        DispatchQueue.global().async {
            self.fetchMaps(searchText: self.searchTextGlobal)
        }
    }

    private func fetchMaps(searchText: String) {
        Task {
            let maps = try? await self.mapService?.getMapsFrom(searchText: searchText, limit: 10)
            self.queryMaps.append(contentsOf: maps ?? [])
            self.reloadResultsTable()
        }
    }

    private func reloadResultsTable() {
        mapSearching = false
        queryMaps.removeDuplicates()
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    private func queryValid(searchText: String) -> Bool {
        // check that search text didnt change
        return searchText == searchTextGlobal && searchText != ""
    }
}

