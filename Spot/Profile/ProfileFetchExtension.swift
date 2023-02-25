//
//  ProfileFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/23/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

extension ProfileViewController {
    func getPosts() {
        guard let userID = userProfile?.id else { return }
        refreshStatus = .activelyRefreshing
        let limit = 20
        var query = Firestore.firestore().collection("posts").whereField("posterID", isEqualTo: userID).order(by: "timestamp", descending: true).limit(to: limit)
        if let endDocument = endDocument { query = query.start(afterDocument: endDocument) }
        Task {
            let documents = try? await mapPostService?.getPostsFrom(query: query, caller: .Profile, limit: limit)
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
            if let postController = self.navigationController?.children.last as? PostController {
                postController.postsList.append(contentsOf: posts)
                postController.contentTable.reloadData()
            }
        }
    }
}

extension ProfileViewController: PostControllerDelegate {
    func indexChanged(rowsRemaining: Int) {
        if rowsRemaining < 5 && self.refreshStatus == .refreshEnabled {
            DispatchQueue.global().async { self.getPosts() }
        }
    }
}
