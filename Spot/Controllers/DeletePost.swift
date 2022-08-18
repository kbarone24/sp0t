//
//  DeletePost.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase

extension PostController {
    func deletePost(post: MapPost) {
        addDeleteIndicator()
        
        var leaveCount = 0
        var spotDelete = false
        var mapDelete = false
        var spotRemove = false
        checkForSpotDelete(spotID: post.spotID ?? "") { delete in
            spotDelete = delete
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }
        
        checkForSpotRemove(spotID: post.spotID ?? "", mapID: post.mapID ?? "", postID: post.id!) { remove in
            spotRemove = remove
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }

        checkForMapDelete(mapID: post.mapID ?? "") { delete in
            mapDelete = delete
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }
    }
    
    func addDeleteIndicator() {
        deleteIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30)/2), y: UIScreen.main.bounds.height/2 - 100, width: 30, height: 30)
        deleteIndicator.startAnimating()
        deleteIndicator.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(deleteIndicator)
    }
    
    func runDeletes(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        self.deleteIndicator.removeFromSuperview()
        self.deletePostLocally()
        self.sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete, spotRemove: spotRemove)
        self.deletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove)
    }
    
    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if mapID == "" { completion(false); return }
        db.collection("posts").whereField("mapID", isEqualTo: mapID).getDocuments { snap, err in
            let mapDelete = snap?.documents.count ?? 0 == 1
            completion(mapDelete)
            return
        }
    }
    
    func checkForSpotDelete(spotID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if spotID == "" { completion(false); return }
        db.collection("spots").whereField("spotID", isEqualTo: spotID).getDocuments { snap, err in
            let spotDelete = snap?.documents.count ?? 0 == 1
            completion(spotDelete)
            return
        }
    }
    
    func checkForSpotRemove(spotID: String, mapID: String, postID: String, completion: @escaping(_ remove: Bool) -> Void) {
        if spotID == "" || mapID == "" { completion(false); return }
        db.collection("posts").whereField("mapID", isEqualTo: mapID).whereField("spotID", isEqualTo: spotID).whereField("postID", isNotEqualTo: postID).limit(to: 1).getDocuments { snap, err in
            completion(snap?.documents.count ?? 0 == 0)
        }
    }
    
    func deletePostLocally() {
        if postsList.count > 1 {
            postsCollection.performBatchUpdates {
                self.postsList.remove(at: selectedPostIndex)
                self.postsCollection.deleteItems(at: [IndexPath(item: self.selectedPostIndex, section: 0)])
                if self.selectedPostIndex >= postsList.count { self.selectedPostIndex = postsList.count - 1 }
            } completion: { _ in
                self.postsCollection.reloadData()
            }
        } else {
            exitPosts()
        }
    }
    
    func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
    
    func deletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        var posters = [uid]
        posters.append(contentsOf: post.addedUsers ?? [])
        let functions = Functions.functions()
        functions.httpsCallable("postDelete").call(["postIDs": [post.id], "spotID": post.spotID ?? "", "mapID": post.mapID ?? "", "uid": self.uid, "posters": posters, "spotDelete": spotDelete, "mapDelete": mapDelete, "spotRemove": spotRemove]) { result, error in
            print("result", result?.data as Any, error as Any)
        }
    }
}
