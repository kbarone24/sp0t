//
//  PopActionsExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel
import Firebase
import LinkPresentation

extension PopController {
    func addPostActionSheet(post: Post) {
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

    private func hidePostFromFeed(post: Post) {
        Mixpanel.mainInstance().track(event: "PopPageHidePost")
        viewModel.hidePost(post: post)
        refresh.send(false)
    }

    private func addDeletePostAction(post: Post) {
        let alert = UIAlertController(title: "Delete post", message: "Are you sure you want to delete this post?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            Mixpanel.mainInstance().track(event: "PopPageDeletePostCancel")
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            Mixpanel.mainInstance().track(event: "PopPageDeletePost")

            self?.viewModel.deletePost(post: post)
            self?.refresh.send(false)
            self?.showConfirmationAction(deletePost: true)
        }))
        present(alert, animated: true)
    }

    private func addReportPostAction(post: Post) {
        let alertController = UIAlertController(title: "Report post", message: nil, preferredStyle: .alert)
        alertController.addAction(
            UIAlertAction(title: "Report", style: .destructive) { [weak self] _ in
                if let txtField = alertController.textFields?.first, let text = txtField.text {
                    Mixpanel.mainInstance().track(event: "PopPageReportPost")

                    self?.viewModel.reportPost(post: post, feedbackText: text)
                    self?.refresh.send(false)
                    self?.showConfirmationAction(deletePost: false)
                }
            })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            Mixpanel.mainInstance().track(event: "PopPageReportPostCancel")
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


    @objc func shareTap() {
        guard let popID = viewModel.cachedPop.id else { return }
        var components = URLComponents()
                components.scheme = "https"
                components.host = "sp0t.app"
                components.path = "/pop"

                let postIDQueryItem = URLQueryItem(name: "popID", value: popID)
                components.queryItems = [postIDQueryItem]

                guard let linkParameter = components.url else {return}
                print("sharing \(linkParameter.absoluteString)")

                var shareLink = DynamicLinkComponents(link: linkParameter, domainURIPrefix: "https://sp0t.page.link")

                if let myBundleID = Bundle.main.bundleIdentifier {
                    shareLink?.iOSParameters = DynamicLinkIOSParameters(bundleID: myBundleID)
                 }
                shareLink?.iOSParameters?.appStoreID = "1477764252"
                shareLink?.socialMetaTagParameters = DynamicLinkSocialMetaTagParameters()
                shareLink?.socialMetaTagParameters?.title = "sp0tted it"
                shareLink?.socialMetaTagParameters?.descriptionText = "Your friend saw something cool and thinks you should check it out on the sp0t app!"
                shareLink?.socialMetaTagParameters?.imageURL = URL(string: "https://sp0t.app/Assets/textLogo.svg")
                guard shareLink?.url != nil else { return }

                shareLink?.shorten {(url, warnings, error) in
                    if error != nil { return }
                    if let warnings = warnings {
                        for warning in warnings {
                            print("FDL Warning: \(warning)")
                        }
                    }

                    shareLink?.options = DynamicLinkComponentsOptions()
                    shareLink?.options?.pathLength = .short

                    guard (url?.absoluteString) != nil else {return}

                    let image = UIImage(named: "AppIcon")! //Image to show in preview
                    let metadata = LPLinkMetadata()
                    metadata.imageProvider = NSItemProvider(object: image)
                    metadata.originalURL = url //dynamic links
                    metadata.title = "It's popping 😎"


                    let metadataItemSource = LinkPresentationItemSource(metaData: metadata)
                    let items = [metadataItemSource]

                    DispatchQueue.main.async {
                        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        self.present(activityView, animated: true)
                        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                            if completed {
                                Mixpanel.mainInstance().track(event: "PopPageSharedPop")
                            }
                        }
                    }

                }
    }

    @objc func enteredForeground() {
        if viewModel.cachedPop.popIsActive, let id = viewModel.cachedPop.liveVideoID, id != "" {
            livePlayerView.playVideo()
        }
    }
}
