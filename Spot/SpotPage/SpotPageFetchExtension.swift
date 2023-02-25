//
//  SpotPageFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 1/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

extension SpotPageController {
    func fetchSpot() {
        let db: Firestore = Firestore.firestore()
        db.collection("spots").document(spotID).getDocument { [weak self] snap, _ in
            do {
                guard let self = self else { return }
                let unwrappedInfo = try snap?.data(as: MapSpot.self)
                guard let userInfo = unwrappedInfo else { return }
                self.spot = userInfo
            } catch let parseError {
                print("JSON Error \(parseError.localizedDescription)")
            }
        }
    }

    func getPosts() {
        refreshStatus = .activelyRefreshing
        let limit = 20
        let db: Firestore = Firestore.firestore()
        var query = db.collection("posts").whereField("spotID", isEqualTo: spotID).order(by: "timestamp", descending: true).limit(to: limit)
        if let endDocument = endDocument { query = query.start(afterDocument: endDocument) }
        Task {
            let documents = try? await mapPostService?.getPostsFrom(query: query, caller: .Spot, limit: limit)
            guard var posts = documents?.posts else { return }
            posts.sort(by: { $0.timestamp.seconds > $1.timestamp.seconds })

            self.endDocument = documents?.endDocument
            if self.endDocument == nil { self.refreshStatus = .refreshDisabled }
            self.reloadCollectionView(posts: posts)
        }

    }

    private func reloadCollectionView(posts: [MapPost]) {
        DispatchQueue.main.async {
            self.postsList.append(contentsOf: posts)
            self.collectionView.reloadData()
            if self.refreshStatus != .refreshDisabled { self.refreshStatus = .refreshEnabled }
            self.activityIndicator.stopAnimating()

            guard let controllers = self.navigationController?.children else { return }
            if let postController = controllers.last as? PostController {
                postController.postsList.append(contentsOf: posts)
                postController.contentTable.reloadData()
            }
        }
    }
}

extension SpotPageController: PostControllerDelegate {
    func indexChanged(rowsRemaining: Int) {
        if rowsRemaining < 5 && refreshStatus == .refreshEnabled {
            DispatchQueue.global().async { self.getPosts() }
        }
    }
}
