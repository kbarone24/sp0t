//
//  PostCellActionSheet.swift
//  Spot
//
//  Created by Kenny Barone on 8/16/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
/// uiaction methods
extension PostCell {
    func addActionSheet() {
        let activeUser = post.posterID == uid
        let alertAction = activeUser ? "Delete post" : "Report post"
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: alertAction, style: .destructive, handler: { (_) in
            activeUser ? self.addDeletePostAction() : self.addReportPostAction()
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
            print("User click Dismiss button")
        }))
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.present(alert, animated: true)
    }
    
    func addDeletePostAction() {
        guard let postVC = viewContainingController() as? PostController else { return }
        let alert = UIAlertController(title: "Delete post", message: "Are you sure you want to delete this post?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "DeletePostCancelTap")
        }))
        alert.addAction(UIAlertAction(title: "Delete",
                                      style: .destructive,
                                      handler: {(_: UIAlertAction!) in
            Mixpanel.mainInstance().track(event: "DeletePostTap")
            postVC.deletePost(post: self.post)
        }))
        postVC.present(alert, animated: true)
    }
    
    func addReportPostAction() {
        let alertController = UIAlertController(title: "Report user", message: "", preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "Report user", style: .default) { (_) in
            if let txtField = alertController.textFields?.first, let text = txtField.text {
                Mixpanel.mainInstance().track(event: "ReportPostTap")
                self.db.collection("feedback").addDocument(data: [
                    "feedbackText": text,
                    "postID" : self.post.id!,
                    "type" : "reportPost",
                    "userID": self.uid
                ])
                self.showConfirmationAction(deletePost: false)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            Mixpanel.mainInstance().track(event: "ReportPostCancelTap")
        }
        alertController.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this user?"
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.present(alertController, animated: true, completion: nil)
    }
    
    func showConfirmationAction(deletePost: Bool) {
        let text = deletePost ? "Post successfully deleted!" : "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        guard let postVC = viewContainingController() as? PostController else { return }
        postVC.present(alert, animated: true, completion: nil)
    }
}

///https://medium.com/swift-india/uialertcontroller-in-swift-22f3c5b1dd68

