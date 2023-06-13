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
            reloadResultsTable(searchText: searchText)
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

        let mapNames = customMaps.map({ $0.lowercaseName ?? "" })
        let filteredNames = mapNames.filter({(dataString: String) -> Bool in
            // If dataItem matches the searchText, return true to include it
            return dataString.range(of: self.searchTextGlobal, options: .caseInsensitive) != nil
        })

        for name in filteredNames {
            if let map = customMaps.first(where: { $0.lowercaseName == name }) { self.queryMaps.append(map) }
        }

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
        let mapQuery = db.collection("maps")
            .whereField("searchKeywords", arrayContains: searchText.lowercased())
            .whereField("communityMap", isEqualTo: true)
            .limit(to: 10)

        mapQuery.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let docs = snap?.documents else { return }
            if !self.queryValid(searchText: searchText) { self.mapSearching = false; return }

            for doc in docs {
                /// get all spots that match query and order by distance
                let map = try? doc.data(as: CustomMap.self)
                if let map {
                    self.queryMaps.append(map)
                }
            }

            self.reloadResultsTable(searchText: searchText)
        }
    }

    private func reloadResultsTable(searchText: String) {
        mapSearching = false
        queryMaps.removeDuplicates()
        DispatchQueue.main.async { self.tableView.reloadData() }
    }

    private func queryValid(searchText: String) -> Bool {
        // check that search text didnt change
        return searchText == searchTextGlobal && searchText != ""
    }
}

