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

    func fetchRelatedPosts() {
        let db: Firestore = Firestore.firestore()
        let baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID)
        let conditionedQuery = (mapID == nil || mapID == "") ? baseQuery.whereField("friendsList", arrayContains: UserDataModel.shared.uid) : baseQuery.whereField("mapID", isEqualTo: mapID ?? "")
        var finalQuery = conditionedQuery.limit(to: 13).order(by: "timestamp", descending: true)
        if let relatedEndDocument { finalQuery = finalQuery.start(atDocument: relatedEndDocument) }

        fetching = .activelyRefreshing
        finalQuery.getDocuments { [weak self ](snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }

            let docs = allDocs.count == 13 ? allDocs.dropLast() : allDocs
            let postGroup = DispatchGroup()
            for doc in docs {
                do {
                    let unwrappedInfo = try? doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if self.relatedPosts.contains(where: { $0.id == postInfo.id }) { continue }
                    if postInfo.posterID.isBlocked() { continue }
                    postGroup.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        DispatchQueue.main.async { self.addRelatedPost(postInfo: post) }
                        postGroup.leave()
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }

            postGroup.notify(queue: .main) {
                self.activityIndicator.stopAnimating()
                self.relatedEndDocument = allDocs.last
                self.fetchRelatedPostsComplete = docs.count < 12
                self.fetching = .refreshEnabled

                self.relatedPosts.sort(by: { $0.seconds > $1.seconds })
                self.collectionView.reloadData()

                if docs.count < 12 {
                    DispatchQueue.global().async { self.fetchCommunityPosts() }
                }
            }
        }
    }

    func fetchCommunityPosts() {
        let db: Firestore = Firestore.firestore()
        let baseQuery = db.collection("posts").whereField("spotID", isEqualTo: spotID)
        var finalQuery = baseQuery.limit(to: 13).order(by: "timestamp", descending: true)
        if let communityEndDocument { finalQuery = finalQuery.start(atDocument: communityEndDocument) }

        fetching = .activelyRefreshing
        finalQuery.getDocuments { [weak self] (snap, _) in
            guard let self = self else { return }
            guard let allDocs = snap?.documents else { return }
            if allDocs.isEmpty { self.fetching = .refreshDisabled }
            let docs = allDocs.count == 13 ? allDocs.dropLast() : allDocs
            if docs.count < 12 { self.fetching = .refreshDisabled }

            let postGroup = DispatchGroup()
            for doc in allDocs {
                do {
                    let unwrappedInfo = try? doc.data(as: MapPost.self)
                    guard let postInfo = unwrappedInfo else { continue }
                    if self.relatedPosts.contains(where: { $0.id == postInfo.id }) { continue }
                    if postInfo.posterID.isBlocked() { continue }

                    postGroup.enter()
                    self.mapPostService?.setPostDetails(post: postInfo) { [weak self] post in
                        guard let self = self else { return }
                        DispatchQueue.main.async { self.addCommunityPost(postInfo: post) }
                        postGroup.leave()
                    }
                } catch let parseError {
                    print("JSON Error \(parseError.localizedDescription)")
                }
            }

            postGroup.notify(queue: .main) {
                self.activityIndicator.stopAnimating()
                if self.fetching == .refreshDisabled {
                    self.fetchCommunityPostsComplete = true
                } else {
                    self.fetching = .refreshEnabled
                }

                self.communityEndDocument = allDocs.last
            //    self.relatedPosts.sort(by: { $0.seconds > $1.seconds })
                self.communityPosts.sort(by: { $0.seconds > $1.seconds })
                self.collectionView.reloadData()
            }
        }
    }

    private func addRelatedPost(postInfo: MapPost) {
        if !hasPostAccess(post: postInfo) { return }
        if !relatedPosts.contains(where: { $0.id == postInfo.id }) { relatedPosts.append(postInfo) }
    }

    private func addCommunityPost(postInfo: MapPost) {
        if !hasPostAccess(post: postInfo) { return }
        // removed checks for related posts here because it causes the UI to jump and user will never see it. Friends posts to private maps will show in community posts -> feels better than jumpy UI
        if !communityPosts.contains(where: { $0.id == postInfo.id }) { communityPosts.append(postInfo) }
    }

    private func hasPostAccess(post: MapPost) -> Bool {
        // show all posts except secret map posts from secret maps.
        // Allow friends level access for posts posted to friends feed, invite level access for posts hidden from friends feed / myMap
        if post.privacyLevel == "invite" {
            if post.hideFromFeed ?? false {
                return (post.inviteList?.contains(UserDataModel.shared.uid)) ?? false
            } else {
                return UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) || UserDataModel.shared.uid == post.posterID
            }
        }
        return true
    }
}
