//
//  CustomMapFetchExtension.swift
//  Spot
//
//  Created by Kenny Barone on 9/9/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Firebase
import Geofirestore
import CoreLocation

extension CustomMapController {
    func getMapMembers() {
        let dispatch = DispatchGroup()
        var memberList: [UserProfile] = []
        firstMaxFourMapMemberList.removeAll()
        
        let communityMap = mapData!.communityMap ?? false
        let members = communityMap ? mapData!.memberIDs.reversed() : mapData!.memberIDs
        // Get the first four map member
        for index in 0...(members.count < 4 ? (members.count - 1) : 3) {
            dispatch.enter()
            getUserInfo(userID: members[index]) { user in
                memberList.insert(user, at: 0)
                dispatch.leave()
            }
        }
        dispatch.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.firstMaxFourMapMemberList = memberList
            if !communityMap { self.firstMaxFourMapMemberList.sort(by: {$0.id == self.mapData!.founderID && $1.id != self.mapData!.founderID}) }
            self.collectionView.reloadData()
        }
    }
    
    func getPosts() {
        var query = db.collection("posts").order(by: "timestamp", descending: true).limit(to: 21)
        switch mapType {
        case .customMap:
            query = query.whereField("mapID", isEqualTo: mapData!.id!)
        case .myMap:
            query = query.whereField("posterID", isEqualTo: userProfile!.id!)
        case .friendsMap:
            query = query.whereField("friendsList", arrayContains: uid)
        default: return
        }
        if endDocument != nil { query = query.start(atDocument: endDocument) }
        
        DispatchQueue.global().async {
            query.getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                guard let allDocs = snap?.documents else { return }
                if allDocs.count < 21 { self.refresh = .refreshDisabled }
                self.endDocument = allDocs.last
                
                let docs = self.refresh == .refreshDisabled ? allDocs : allDocs.dropLast()
                let postGroup = DispatchGroup()
                for doc in docs {
                    do {
                        let unwrappedInfo = try doc.data(as: MapPost.self)
                        guard let postInfo = unwrappedInfo else { return }
                        if self.postsList.contains(where: {$0.id == postInfo.id}) { continue }
                        if !self.hasMapPostAccess(post: postInfo) { continue }
                        postGroup.enter()
                        self.setPostDetails(post: postInfo) { [weak self] post in
                            guard let self = self else { return }
                            if post.id ?? "" != "", !self.postsList.contains(where: {$0.id == post.id!}) {
                                DispatchQueue.main.async {
                                    self.postsList.append(post)
                                    self.mapData!.postsDictionary.updateValue(post, forKey: post.id!)
                                    let groupData = self.mapData!.updateGroup(post: post)
                                    self.addAnnotation(group: groupData.group, newGroup: groupData.newGroup)
                                }
                            }
                            postGroup.leave()
                        }
                        
                    } catch {
                        continue
                    }
                }
                postGroup.notify(queue: .main) {
                    self.postsList.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
                    self.collectionView.reloadData()
                    if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
                    if !self.centeredMap { self.setInitialRegion() }
                }
            }
        }
    }
    
    func getNearbyPosts() {
        print("get nearby")
        let geoFirestore = GeoFirestore(collectionRef: Firestore.firestore().collection("mapLocations"))
        guard let center = mapController?.mapView.centerCoordinate.location else { return }
        /// get radius in KM
        let radius = mapController!.mapView.currentRadius()/1000

        if circleQuery != nil {
            circleQuery!.center = center
            circleQuery!.radius = radius
            return
        }
        
        circleQuery = geoFirestore.query(withCenter: center, radius: radius)
        circleQuery!.searchLimit = 30
        let _ = self.circleQuery?.observe(.documentEntered, with: loadPostFromDB)
        
        geoFetchGroup.notify(queue: .main) {
            print("geo notify")
            self.postsList.sort(by: {$0.timestamp.seconds > $1.timestamp.seconds})
            self.collectionView.reloadData()
            if self.refresh != .refreshDisabled { self.refresh = .refreshEnabled }
            if !self.centeredMap { self.setInitialRegion() }
        }
    }
    
    func loadPostFromDB(key: String?, location: CLLocation?) {
        guard let key = key else { return }
        if !mapData!.postIDs.contains(key) { return }
        if postsList.contains(where: {$0.id == key}) { return }
        geoFetchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.getPost(postID: key) { post in
                if post.id ?? "" != "", !self.postsList.contains(where: {$0.id == post.id!}) {
                    DispatchQueue.main.async {
                        self.postsList.append(post)
                        self.mapData!.postsDictionary.updateValue(post, forKey: post.id!)
                        let groupData = self.mapData!.updateGroup(post: post)
                        self.addAnnotation(group: groupData.group, newGroup: groupData.newGroup)
                    }
                }
                self.geoFetchGroup.leave()
            }
        }
    }
    
    func hasMapPostAccess(post: MapPost) -> Bool {
        if UserDataModel.shared.deletedPostIDs.contains(post.id!) { return false }
        if mapType == .friendsMap || mapType == .myMap {
            /// show only friends level posts for friends map and my map,
            if post.privacyLevel == "invite" && post.hideFromFeed ?? false {
                return false
            }
            return UserDataModel.shared.userInfo.friendIDs.contains(post.posterID) || uid == post.posterID
        }
        return true
    }
    
    func addAnnotation(group: MapPostGroup?, newGroup: Bool) {
        if group != nil {
            if newGroup {
                /// add new group
                mapController?.mapView.addSpotAnnotation(group: group!, map: mapData!)
            } else if let anno = mapController?.mapView.annotations.first(where: {$0.coordinate.isEqualTo(coordinate: group!.coordinate)}) {
                /// update existing group
                    mapController?.mapView.removeAnnotation(anno)
                    mapController?.mapView.addSpotAnnotation(group: group!, map: mapData!)
            }
        }
    }
    
    func addInitialAnnotations() {
        mapController?.mapView.removeAllAnnos()
        for group in mapData!.postGroup { mapController?.mapView.addSpotAnnotation(group: group, map: mapData!) }
    }
}
