//
//  AllPostsViewControllerExtension.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 2/25/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Mixpanel
import UIKit
import Firebase
import FirebaseAuth
import FirebaseFirestore
import LinkPresentation

extension AllPostsViewController {
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
        //ADD MIXPANEL INSTANCE
        let promoText = UserDataModel.shared.userInfo.name + " spotted something! Check it out 👀"
        
        //post ID info
        var postID = post.id
        
        //generating short dynamic link
        var components = URLComponents()
                components.scheme = "https"
                components.host = "sp0t.app"
                components.path = "/map"
                
                let postIDQueryItem = URLQueryItem(name: "postID", value: postID)
                components.queryItems = [postIDQueryItem]
                
                guard let linkParameter = components.url else {return}
                print("sharing \(linkParameter.absoluteString)")
                
                guard let shareLink = DynamicLinkComponents.init(link: linkParameter, domainURIPrefix: "https://sp0t.page.link") else {
                    print("Couldn't create FDL component")
                    return
                }
                
                if let myBundleID = Bundle.main.bundleIdentifier {
                    shareLink.iOSParameters = DynamicLinkIOSParameters(bundleID: myBundleID)
                 }
                shareLink.iOSParameters?.appStoreID = "1477764252"
                shareLink.socialMetaTagParameters = DynamicLinkSocialMetaTagParameters()
                shareLink.socialMetaTagParameters?.title = "sp0tted it!"
                shareLink.socialMetaTagParameters?.descriptionText = "Your friend saw something cool and thinks you should check it out on the sp0t app!"
                shareLink.socialMetaTagParameters?.imageURL = URL(string: "https://sp0t.app/Assets/textLogo.svg")
                guard let longURL = shareLink.url else {return}
                
                print("The long dynamic link is \(longURL)")
                
                shareLink.shorten {(url, warnings, error) in
                    if let error = error {
                        print("Oh no! Got an error! \(error)")
                        return
                    }
                    if let warnings = warnings {
                        for warning in warnings {
                            print("FDL Warning: \(warning)")
                        }
                    }
                    
                    guard let url = url else {return}
                    
                    let image = UIImage(named: "AppIcon")! //Image to show in preview
                    let metadata = LPLinkMetadata()
                    metadata.imageProvider = NSItemProvider(object: image)
                    metadata.originalURL = url //dynamic links
                    metadata.title = "Your friend found a map! Check it out 👀\n"

                    let metadataItemSource = LinkPresentationItemSource(metaData: metadata)
                    
                    let items = [metadataItemSource] as [Any]
                    
                    DispatchQueue.main.async {
                        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        self.present(activityView, animated: true)
                        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
                            if completed {
                                print("post shared")
                            } else {
                                print("post not shared")
                            }
                        }
                    }
                    
                }
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
                    self?.viewModel.postService.reportPost(postID: post.id ?? "", feedbackText: text, userId: UserDataModel.shared.uid)

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
        self.deleteIndicator.removeFromSuperview()
        self.deletePostLocally(post: post)
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
    
    private func deletePostLocally(post: MapPost) {
        let postID = post.id ?? ""
        UserDataModel.shared.deletedPostIDs.append(postID)
        // viewModel.deletePost(id: postID)
        // refresh.send(false)
    }

    private func sendPostDeleteNotification(post: MapPost, mapID: String, mapDelete: Bool, spotDelete: Bool, spotRemove: Bool) {
        let infoPass: [String: Any] = ["post": post, "mapID": mapID, "mapDelete": mapDelete, "spotDelete": spotDelete, "spotRemove": spotRemove]
        NotificationCenter.default.post(name: Notification.Name("DeletePost"), object: nil, userInfo: infoPass)
    }
}
