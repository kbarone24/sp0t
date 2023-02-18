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
        var query = db.collection("posts").order(by: "timestamp", descending: true).limit(to: 21)
        switch mapType {
        case .customMap:
            query = query.whereField("mapID", isEqualTo: mapData?.id ?? "")
        case .myMap:
            query = query.whereField("posterID", isEqualTo: userProfile?.id ?? "")
        case .friendsMap:
            query = query.whereField("friendsList", arrayContains: uid)
        }
        if let endDocument = endDocument { query = query.start(atDocument: endDocument) }

        DispatchQueue.global().async {
            query.getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                guard let allDocs = snap?.documents else { return }
                if allDocs.count < 21 { self.refresh = .refreshDisabled }
                self.endDocument = allDocs.last

                let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()
                let postGroup = DispatchGroup()
                for doc in docs {
                    do {
                        let unwrappedInfo = try? doc.data(as: MapPost.self)
                        guard let postInfo = unwrappedInfo else { return }
                        if self.postsList.contains(where: { $0.id == postInfo.id }) { continue }
                        if !self.hasMapPostAccess(post: postInfo) { continue }
                        postGroup.enter()
                        self.mapPostService?.setPostDetails(post: postInfo) { post in
                            if let id = post.id, id != "", !self.postsList.contains(where: { $0.id == id }) {
                                DispatchQueue.main.async {
                                    self.postsList.append(post)
                                    self.mapData?.postsDictionary.updateValue(post, forKey: post.id ?? "")
                                }
                            }
                            postGroup.leave()
                        }

                    } 
                }
                postGroup.notify(queue: .main) {
                    self.postsList.sort(by: { $0.timestamp.seconds > $1.timestamp.seconds })
                    self.collectionView.reloadData()
                    if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
                }
            }
        }
    }

    func hasMapPostAccess(post: MapPost) -> Bool {
        if UserDataModel.shared.deletedPostIDs.contains(post.id ?? "_") || post.posterID.isBlocked() { return false }
        if mapType == .friendsMap || mapType == .myMap {
            /// show only friends level posts for friends map and my map,
            if post.privacyLevel == "invite" && post.hideFromFeed ?? false {
                return false
            }
            return UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) || uid == post.posterID
        }
        return true
    }
}
