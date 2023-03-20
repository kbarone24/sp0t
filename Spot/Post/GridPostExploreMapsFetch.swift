//
//  GridPostExploreMapsFetch.swift
//  Spot
//
//  Created by Kenny Barone on 3/19/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

extension GridPostViewController {
    func getExploreMapsPosts() {
        guard let mapID = postsList.first?.mapID else { return }
        var query = Firestore.firestore().collection("posts").whereField("mapID", isEqualTo: mapID).limit(to: 12).order(by: "timestamp", descending: true)
        if let exploreMapsEndDocument { query = query.start(afterDocument: exploreMapsEndDocument) }
        Task {
            let documents = try? await self.mapPostService?.getPostsFrom(query: query, caller: .Explore, limit: 12)
            guard var posts = documents?.posts else { return }
            print("ct", posts.count)

            self.exploreMapsEndDocument = documents?.endDocument
            if self.exploreMapsEndDocument == nil { self.refreshStatus = .refreshDisabled }

            if !postsLoaded {
                // remove dummy posts that were passed through, sort to show post that was tapped
                self.postsLoaded = true
                self.postsList.removeAll()
                posts.sortPostsOnOpen(index: startingIndex)
            }

            DispatchQueue.main.async {
                self.setPosts(posts: posts)
            }

            return
        }
    }

    func checkForExploreRefresh() {
        guard parentVC == .Explore else { return }
        if postsList.count - selectedPostIndex < 5, refreshStatus == .refreshEnabled {
            DispatchQueue.global().async { self.getExploreMapsPosts() }
        }
    }
}
