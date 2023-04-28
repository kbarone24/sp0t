//
//  ProfileFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/23/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import FirebaseFirestore
import UIKit
import Firebase

extension ProfileViewController {
    func getPosts() {
        guard let userID = userProfile?.id else { return }
        refreshStatus = .activelyRefreshing
        let limit = 10
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
            self.postsList = self.postsList.removingDuplicates()
            self.collectionView.reloadData()
            if self.refreshStatus != .refreshDisabled { self.refreshStatus = .refreshEnabled }
            self.gridPostChild?.setPosts(posts: posts)

            if posts.count < 7, self.refreshStatus == .refreshEnabled {
                // rerun fetch -> only should be necessary if user has a bunch of private posts
                DispatchQueue.global().async {
                    self.getPosts()
                }
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
