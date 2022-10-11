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
        checkForSpotDelete(spotID: post.spotID ?? "", postID: post.id!) { delete in
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
        self.deletePostLocally(index: selectedPostIndex)
        self.sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete, spotRemove: spotRemove)
        self.deletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove)
    }
    
    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if mapID == "" { completion(false); return }
        db.collection("posts").whereField("mapID", isEqualTo: mapID).getDocuments { snap, err in
            var postCount = 0
            var mapDelete = false
            for doc in snap?.documents ?? [] {
                if !UserDataModel.shared.deletedPostIDs.contains(where: {$0 == doc.documentID}) { postCount += 1 }
                if doc == snap!.documents.last { mapDelete = postCount == 1 }
            }
            
            if mapDelete { UserDataModel.shared.deletedMapIDs.append(mapID) }
            completion(mapDelete)
            return
        }
    }
    
    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if spotID == "" { completion(false); return }
        db.collection("posts").whereField("spotID", isEqualTo: spotID).getDocuments { snap, err in
            let spotDelete = snap?.documents.count ?? 0 == 1 && snap?.documents.first?.documentID ?? "" == postID
            completion(spotDelete)
            return
        }
    }
    
    func checkForSpotRemove(spotID: String, mapID: String, postID: String, completion: @escaping(_ remove: Bool) -> Void) {
        if spotID == "" || mapID == "" { completion(false); return }
        db.collection("posts").whereField("mapID", isEqualTo: mapID).whereField("spotID", isEqualTo: spotID).getDocuments { snap, err in
            completion(snap?.documents.count ?? 0 <= 1)
        }
    }
    
    func deletePostLocally(index: Int) {
        if postsList.count > 1 {
            /// check for if == selectedPostIndex
            postsCollection.performBatchUpdates {
                self.postsList.remove(at: index)
                self.postsCollection.deleteItems(at: [IndexPath(item: index, section: 0)])
                if self.selectedPostIndex >= postsList.count { self.selectedPostIndex = postsList.count - 1 }
            } completion: { _ in
                self.postsCollection.reloadData()
            }
        } else {
            print("exit posts")
            exitPosts()
        }
    }
    
    func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
    
    func deletePostFunctions(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        db.collection("mapLocations").document(post.id!).delete()
        var posters = [uid]
        posters.append(contentsOf: post.addedUsers ?? [])
        let functions = Functions.functions()
        functions.httpsCallable("postDelete").call(["postIDs": [post.id], "spotID": post.spotID ?? "", "mapID": post.mapID ?? "", "uid": self.uid, "posters": posters, "spotDelete": spotDelete, "mapDelete": mapDelete, "spotRemove": spotRemove]) { result, error in
            print("result", result?.data as Any, error as Any)
        }
    }
}
