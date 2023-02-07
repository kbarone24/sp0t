//
//  PostCellActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import Mixpanel
import UIKit
import Firebase

extension PostController {
    func addActionSheet() {
        let activeUser = postsList[selectedPostIndex].userInfo?.id ?? "" == uid
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if !activeUser {
            alert.addAction(UIAlertAction(title: "Hide post", style: .default, handler: { (_) in
                self.hidePostFromFeed()
            }))
        }
        let alertAction = activeUser ? "Delete post" : "Report post"
        alert.addAction(UIAlertAction(title: alertAction, style: .destructive, handler: { (_) in
            activeUser ? self.addDeletePostAction() : self.addReportPostAction()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
            print("User click Dismiss button")
        }))
        present(alert, animated: true)
    }
    // https://medium.com/swift-india/uialertcontroller-in-swift-22f3c5b1dd68

    func hidePostFromFeed() {
        Mixpanel.mainInstance().track(event: "HidePostFromFeed")
        let post = postsList[selectedPostIndex]
        deletePostLocally(index: selectedPostIndex)
        sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: false, spotDelete: false, spotRemove: false)

        let db = Firestore.firestore()
        db.collection("posts").document(post.id ?? "").updateData(["hiddenBy": FieldValue.arrayUnion([UserDataModel.shared.uid])])
    }

    func addDeletePostAction() {
        let alert = UIAlertController(title: "Delete post", message: "Are you sure you want to delete this post?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "DeletePostCancelTap")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
            Mixpanel.mainInstance().track(event: "DeletePostTap")
            self.deletePost()
        }))
        present(alert, animated: true)
    }

    func addReportPostAction() {
        let alertController = UIAlertController(title: "Report post", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Report", style: .destructive, handler: { (_) in
            if let txtField = alertController.textFields?.first, let text = txtField.text {
                Mixpanel.mainInstance().track(event: "ReportPostTap")
                self.db.collection("feedback").addDocument(data: [
                    "feedbackText": text,
                    "postID": self.postsList[self.selectedPostIndex].id ?? "",
                    "type": "reportPost",
                    "userID": UserDataModel.shared.uid
                ])
                self.hidePostFromFeed()
                self.showConfirmationAction(deletePost: false)
            }
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            Mixpanel.mainInstance().track(event: "ReportPostCancelTap")
        }))
        alertController.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this post?"
        }

        present(alertController, animated: true, completion: nil)
    }

    func showConfirmationAction(deletePost: Bool) {
        let text = deletePost ? "Post successfully deleted!" : "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alert, animated: true, completion: nil)
    }

    func deletePost() {
        let post = postsList[selectedPostIndex]
        addDeleteIndicator()

        var leaveCount = 0
        var spotDelete = false
        var mapDelete = false
        var spotRemove = false

        guard let postID = post.id else { return }
        checkForSpotDelete(spotID: post.spotID ?? "", postID: postID) { [weak self] delete in
            guard let self else { return }
            spotDelete = delete
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }

        checkForSpotRemove(spotID: post.spotID ?? "", mapID: post.mapID ?? "", postID: postID) { [weak self] remove in
            guard let self else { return }
            spotRemove = remove
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }

        checkForMapDelete(mapID: post.mapID ?? "") { [weak self] delete in
            guard let self else { return }
            mapDelete = delete
            leaveCount += 1
            if leaveCount == 3 { self.runDeletes(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove) }
        }
    }

    func addDeleteIndicator() {
        deleteIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30) / 2), y: UIScreen.main.bounds.height / 2 - 100, width: 30, height: 30)
        deleteIndicator.startAnimating()
        deleteIndicator.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(deleteIndicator)
    }

    func runDeletes(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        self.deleteIndicator.removeFromSuperview()
        self.deletePostLocally(index: selectedPostIndex)
        self.sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete, spotRemove: spotRemove)
        mapPostService?.runDeletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove)
    }

    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if mapID == "" { completion(false); return }
        db.collection(FirebaseCollectionNames.posts.rawValue).whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID).getDocuments { snap, _ in
            var postCount = 0
            var mapDelete = false
            for doc in snap?.documents ?? [] {
                if !UserDataModel.shared.deletedPostIDs.contains(where: { $0 == doc.documentID }) { postCount += 1 }
                if doc == snap?.documents.last { mapDelete = postCount == 1 }
            }

            if mapDelete { UserDataModel.shared.deletedMapIDs.append(mapID) }
            completion(mapDelete)
            return
        }
    }

    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void) {
        if spotID == "" { completion(false); return }
        db.collection(FirebaseCollectionNames.posts.rawValue).whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID).getDocuments { snap, _ in
            let spotDelete = snap?.documents.count ?? 0 == 1 && snap?.documents.first?.documentID ?? "" == postID
            completion(spotDelete)
            return
        }
    }

    func checkForSpotRemove(spotID: String, mapID: String, postID: String, completion: @escaping(_ remove: Bool) -> Void) {
        if spotID == "" || mapID == "" { completion(false); return }
        db.collection(FirebaseCollectionNames.posts.rawValue)
            .whereField(FirebaseCollectionFields.mapID.rawValue, isEqualTo: mapID)
            .whereField(FirebaseCollectionFields.spotID.rawValue, isEqualTo: spotID)
            .getDocuments { snap, _ in
                completion(snap?.documents.count ?? 0 <= 1)
            }
    }

    func deletePostLocally(index: Int) {
        if postsList.count > 1 {
            // check for if == selectedPostIndex
            contentTable.performBatchUpdates {
                self.postsList.remove(at: index)
                self.contentTable.deleteRows(at: [IndexPath(item: index, section: 0)], with: .automatic)
                if self.selectedPostIndex >= postsList.count { self.selectedPostIndex = postsList.count - 1 }
            } completion: { _ in
                self.contentTable.reloadData()
            }
        } else {
            exitPosts()
        }
    }

    func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
}
