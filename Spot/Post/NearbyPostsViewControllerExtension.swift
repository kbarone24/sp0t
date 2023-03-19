//
//  NearbyPostsViewControllerExtension.swift
//  Spot
//
//  Created by Kenny Barone on 2/25/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Mixpanel
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

extension NearbyPostsViewController {
    func addActionSheet() {
        let snapshot = datasource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
        switch item {
        case .item(let post):
            let activeUser = post.userInfo?.id ?? "" == Auth.auth().currentUser?.uid
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(
                UIAlertAction(title: "Share post", style: .default) { [weak self] _ in
                    self?.sharePost()
                }
            )
            if !activeUser {
                alert.addAction(
                    UIAlertAction(title: "Hide post", style: .default) { [weak self] _ in
                        self?.hidePostFromFeed()
                    }
                )
            }
            
            let alertAction = activeUser ? "Delete post" : "Report post"
            alert.addAction(
                UIAlertAction(title: alertAction, style: .destructive) { [weak self] _ in
                    activeUser ? self?.addDeletePostAction() : self?.addReportPostAction()
                }
            )
            
            alert.addAction(
                UIAlertAction(title: "Dismiss", style: .cancel) { _ in
                }
            )
            
            present(alert, animated: true)
        }
    }
    // https://medium.com/swift-india/uialertcontroller-in-swift-22f3c5b1dd68

    private func sharePost() {
        print("share tap")
    }

    func hidePostFromFeed() {
        Mixpanel.mainInstance().track(event: "HidePostFromFeed")
        let snapshot = datasource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
        switch item {
        case .item(let post):
            deletePostLocally(index: selectedPostIndex, post: post)
            sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: false, spotDelete: false, spotRemove: false)

            let db = Firestore.firestore()
            db.collection("posts").document(post.id ?? "").updateData(["hiddenBy": FieldValue.arrayUnion([UserDataModel.shared.uid])])
        }
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
        let snapshot = datasource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
        switch item {
        case .item(let post):
            alertController.addAction(
                UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                    if let txtField = alertController.textFields?.first, let text = txtField.text {
                        Mixpanel.mainInstance().track(event: "ReportPostTap")
                        self?.viewModel.postService.reportPost(postID: post.id ?? "", feedbackText: text, userId: UserDataModel.shared.uid)
                        
                        self?.hidePostFromFeed()
                        self?.showConfirmationAction(deletePost: false)
                    }
                }
            )
        }
        
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
        let snapshot = datasource.snapshot()
        let item = snapshot.itemIdentifiers(inSection: .main)[selectedPostIndex]
        switch item {
        case .item(let post):
            
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
    }

    func addDeleteIndicator() {
        deleteIndicator.frame = CGRect(x: ((UIScreen.main.bounds.width - 30) / 2), y: UIScreen.main.bounds.height / 2 - 100, width: 30, height: 30)
        deleteIndicator.startAnimating()
        deleteIndicator.translatesAutoresizingMaskIntoConstraints = true
        view.addSubview(deleteIndicator)
    }

    func runDeletes(post: MapPost, spotDelete: Bool, mapDelete: Bool, spotRemove: Bool) {
        self.deleteIndicator.removeFromSuperview()
        self.deletePostLocally(index: selectedPostIndex, post: post)
        self.sendPostDeleteNotification(post: post, mapID: post.mapID ?? "", mapDelete: mapDelete, spotDelete: spotDelete, spotRemove: spotRemove)
        viewModel.postService.runDeletePostFunctions(post: post, spotDelete: spotDelete, mapDelete: mapDelete, spotRemove: spotRemove)
    }

    func checkForMapDelete(mapID: String, completion: @escaping(_ delete: Bool) -> Void) {
        viewModel.mapService.checkForMapDelete(mapID: mapID) { delete in
            completion(delete)
        }
    }

    func checkForSpotDelete(spotID: String, postID: String, completion: @escaping(_ delete: Bool) -> Void) {
        viewModel.spotService.checkForSpotDelete(spotID: spotID, postID: postID) { delete in
            completion(delete)
        }
    }

    func checkForSpotRemove(spotID: String, mapID: String, completion: @escaping(_ remove: Bool) -> Void) {
        viewModel.spotService.checkForSpotRemove(spotID: spotID, mapID: mapID) { remove in
            completion(remove)
        }
    }
    
    private func deletePostLocally(index: Int, post: MapPost) {
        let postID = post.id ?? ""
        UserDataModel.shared.deletedPostIDs.append(postID)
        viewModel.deletePost(id: postID)
        refresh.send(false)
    }

    private func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
}
