//
//  CustomMapFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import CoreLocation
import Firebase
import Foundation

extension CustomMapController {
    func getMapMembers() {
        guard let mapData = mapData else { return }
        // sort members by #posts
        sortMapMembers()
        // will show "x joined" if 7+ members or community map so don't need profiles
        if mapData.memberIDs.count > 6 || mapData.communityMap ?? false {
            DispatchQueue.main.async { self.collectionView.reloadData() }
            return
        }

        var memberList: [UserProfile] = []
        firstMaxFourMapMemberList.removeAll()

        var members = Array(mapData.memberIDs.reversed())
        if let i = members.firstIndex(where: { $0 == mapData.founderID }) {
            let member = members.remove(at: i)
            members.insert(member, at: 0)
        }
        
        Task {
            // fetch profiles for the first four map members
            for index in 0...(members.count < 5 ? (members.count - 1) : 3) {
                guard let user = try? await userService?.getUserInfo(userID: members[index]) else {
                    continue
                }
                memberList.insert(user, at: 0)
            }
            
                self.firstMaxFourMapMemberList = memberList
                self.firstMaxFourMapMemberList.sort(by: { $0.id == mapData.founderID && $1.id != mapData.founderID })
                self.collectionView.reloadData()
        }
    }

    private func sortMapMembers() {
        var posters: [String: Int] = [:]
        for posterID in mapData?.posterIDs ?? [] {
            posters[posterID] = (posters[posterID] ?? 0) + 1
        }
        mapData?.memberIDs.sort(by: { posters[$0] ?? 0 > posters[$1] ?? 0 })
    }

    func getPosts() {
        guard let mapID = mapData?.id else { return }
        refreshStatus = .activelyRefreshing
        let limit = 20
        var query = db.collection("posts").whereField("mapID", isEqualTo: mapID).order(by: "timestamp", descending: true).limit(to: limit)
        if let endDocument = endDocument { query = query.start(afterDocument: endDocument) }
        Task {
            let documents = try? await mapPostService?.getPostsFrom(query: query, caller: .CustomMap, limit: limit)
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

extension CustomMapController: PostControllerDelegate {
    func indexChanged(rowsRemaining: Int) {
        if rowsRemaining < 5 && refreshStatus == .refreshEnabled {
            DispatchQueue.global().async { self.getPosts() }
        }
    }
}
