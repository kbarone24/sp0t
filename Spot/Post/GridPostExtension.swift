//
//  GridPostExtension.swift
//  Spot
//
//  Created by Kenny Barone on 3/20/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import Mixpanel
import Firebase

extension GridPostViewController {
    func addActionSheet(post: MapPost) {
        let activeUser = post.userInfo?.id ?? "" == Auth.auth().currentUser?.uid
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: "Share post", style: .default) { [weak self] _ in
                self?.sharePost(post: post)
            }
        )

        if !activeUser {
            alert.addAction(
                UIAlertAction(title: "Hide post", style: .default) { [weak self] _ in
                    self?.hidePostFromFeed(post: post)
                }
            )
        }

        let alertAction = activeUser ? "Delete post" : "Report post"
        alert.addAction(
            UIAlertAction(title: alertAction, style: .destructive) { [weak self] _ in
                activeUser ? self?.addDeletePostAction(post: post) : self?.addReportPostAction(post: post)
            }
        )

        alert.addAction(
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in
            }
        )

        present(alert, animated: true)
    }
    // https://medium.com/swift-india/uialertcontroller-in-swift-22f3c5b1dd68

    private func sharePost(post: MapPost) {
        print("share post")
    }

    func hidePostFromFeed(post: MapPost) {
        Mixpanel.mainInstance().track(event: "HidePostFromFeed")

        deletePostLocally(post: post)
        sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: false, spotDelete: false, spotRemove: false)

        let db = Firestore.firestore()
        db.collection("posts").document(post.id ?? "").updateData(["hiddenBy": FieldValue.arrayUnion([UserDataModel.shared.uid])])
    }

    func addDeletePostAction(post: MapPost) {
        let alert = UIAlertController(title: "Delete post", message: "Are you sure you want to delete this post?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "DeletePostCancelTap")
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            Mixpanel.mainInstance().track(event: "DeletePostTap")
            self?.deletePost(post: post)
        }))
        present(alert, animated: true)
    }

    func addReportPostAction(post: MapPost) {
        let alertController = UIAlertController(title: "Report post", message: nil, preferredStyle: .alert)
        alertController.addAction(
            UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                if let txtField = alertController.textFields?.first, let text = txtField.text {
                    Mixpanel.mainInstance().track(event: "ReportPostTap")
                    self?.postService?.reportPost(postID: post.id ?? "", feedbackText: text, userId: UserDataModel.shared.uid)

                    self?.hidePostFromFeed(post: post)
                    self?.showConfirmationAction(deletePost: false)
                }
            })

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

    func deletePost(post: MapPost) {
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

        checkForSpotRemove(spotID: post.spotID ?? "", mapID: post.mapID ?? "") { [weak self] remove in
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
        deleteIndicator.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
        deleteIndicator.tintColor = .white
        view.addSubview(deleteIndicator)
    }

    func runDeletes(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        deleteIndicator.removeFromSuperview()
        deletePostLocally(post: post)
        sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete, spotRemove: spotRemove)
        postService?.runDeletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove)
    }

    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        mapService?.checkForMapDelete(mapID: mapID) { delete in
            completion(delete)
        }
    }

    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void) {
        spotService?.checkForSpotDelete(spotID: spotID, postID: postID) { delete in
            completion(delete)
        }
    }

    func checkForSpotRemove(spotID: String, mapID: String, completion: @escaping(_ remove: Bool) -> Void) {
        spotService?.checkForSpotRemove(spotID: spotID, mapID: mapID) { remove in
            completion(remove)
        }
    }

    private func deletePostLocally(post: MapPost) {
        guard let postID = post.id else { return }
        UserDataModel.shared.deletedPostIDs.append(postID)
        postsList.removeAll(where: { $0.id == postID })
        DispatchQueue.main.async { self.collectionView.reloadData() }
    }

    private func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
}