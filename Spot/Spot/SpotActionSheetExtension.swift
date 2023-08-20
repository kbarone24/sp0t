//
//  SpotActionSheetExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import Firebase

extension SpotController {
    func addActionSheet(post: MapPost) {
        let activeUser = post.userInfo?.id ?? "" == UserDataModel.shared.uid
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

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
            UIAlertAction(title: "Dismiss", style: .cancel) { _ in }
        )

        present(alert, animated: true)
    }
    // https://medium.com/swift-india/uialertcontroller-in-swift-22f3c5b1dd68

    private func hidePostFromFeed(post: MapPost) {
        Mixpanel.mainInstance().track(event: "SpotPageHidePost")
        viewModel.hidePost(post: post)
        refresh.send(false)
    }

    private func addDeletePostAction(post: MapPost) {
        let alert = UIAlertController(title: "Delete post", message: "Are you sure you want to delete this post?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "SpotPageDeletePostCancel")
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            Mixpanel.mainInstance().track(event: "SpotPageDeletePost")

            self?.viewModel.deletePost(post: post)
            self?.refresh.send(false)
            self?.showConfirmationAction(deletePost: true)
        }))
        present(alert, animated: true)
    }

    private func addReportPostAction(post: MapPost) {
        let alertController = UIAlertController(title: "Report post", message: nil, preferredStyle: .alert)
        alertController.addAction(
            UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                if let txtField = alertController.textFields?.first, let text = txtField.text {
                    Mixpanel.mainInstance().track(event: "SpotPageReportPost")

                    self?.viewModel.reportPost(post: post, feedbackText: text)
                    self?.refresh.send(false)
                    self?.showConfirmationAction(deletePost: false)
                }
            })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            Mixpanel.mainInstance().track(event: "SpotPageReportPostCancel")
        }))

        alertController.addTextField { (textField) in
            textField.autocorrectionType = .default
            textField.placeholder = "Why are you reporting this post?"
        }

        present(alertController, animated: true, completion: nil)
    }

    private func showConfirmationAction(deletePost: Bool) {
        let text = deletePost ? "Successfully deleted!" : "Thank you for the feedback. We will review your report ASAP."
        let alert = UIAlertController(title: "Success!", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alert, animated: true, completion: nil)
    }
}
