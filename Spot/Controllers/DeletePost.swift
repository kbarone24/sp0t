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
        checkForSpotDelete(spotID: post.spotID ?? "") { delete in
            spotDelete = delete
            leaveCount += 1
            if leaveCount == 2 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete) }
        }

        checkForMapDelete(mapID: post.mapID ?? "") { delete in
            mapDelete = delete
            leaveCount += 1
            if leaveCount == 2 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete) }
        }
    }
    
    func addDeleteIndicator() {
        deleteIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30)/2), y: UIScreen.main.bounds.height/2 - 100, width: 30, height: 30)
        deleteIndicator.startAnimating()
        deleteIndicator.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(deleteIndicator)
    }
    
    func runDeletes(post: MapPost, spotDelete: Bool, mapDelete: Bool) {
        self.deleteIndicator.removeFromSuperview()
        self.deletePostLocally()
        self.sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete)
        self.deletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete)
    }
    
    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if mapID == "" { completion(false) }
        db.collection("posts").whereField("mapID", isEqualTo: mapID).getDocuments { snap, err in
            let mapDelete = snap?.documents.count ?? 0 == 1
            completion(mapDelete)
            return
        }
    }
    
    func checkForSpotDelete(spotID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if spotID == "" { completion(false) }
        db.collection("spots").whereField("spotID", isEqualTo: spotID).getDocuments { snap, err in
            let spotDelete = snap?.documents.count ?? 0 == 1
            completion(spotDelete)
            return
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
    
    func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
    
    func deletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool) {
        var posters = [uid]
        posters.append(contentsOf: post.addedUsers ?? [])
        let functions = Functions.functions()
        functions.httpsCallable("postDelete").call(["postIDs": [post.id], "spotID": post.spotID ?? "", "mapID": post.mapID ?? "", "uid": self.uid, "posters": posters, "spotDelete": spotDelete, "mapDelete": mapDelete]) { result, error in
            print("result", result?.data as Any, error as Any)
        }
    }
}
