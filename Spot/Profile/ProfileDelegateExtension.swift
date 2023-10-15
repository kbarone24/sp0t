//
//  ProfileDelegateExtension.swift
//  Spot
//
//  Created by Kenny Barone on 8/22/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Mixpanel

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let snapshot = datasource.snapshot()
        if (indexPath.row >= snapshot.numberOfItems - 2) && !isRefreshingPagination, !viewModel.disablePagination {
            Mixpanel.mainInstance().track(event: "ProfilePaginationTriggered")
            isRefreshingPagination = true
            refresh.send(true)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        DispatchQueue.main.async {
            self.navigationItem.title = scrollView.contentOffset.y > 60 ? self.viewModel.cachedProfile.username : ""
        }
    }
}

extension ProfileViewController: PostCellDelegate {
    //TODO: spot name tap opens spot
    func likePost(post: Post) {
        viewModel.likePost(post: post)
        refresh.send(false)
    }

    func unlikePost(post: Post) {
        viewModel.unlikePost(post: post)
        refresh.send(false)
    }

    func dislikePost(post: Post) {
        viewModel.dislikePost(post: post)
        refresh.send(false)
    }

    func undislikePost(post: Post) {
        viewModel.undislikePost(post: post)
        refresh.send(false)
    }

    func viewMoreTap(parentPostID: String) {
        if let post = viewModel.presentedPosts.first(where: { $0.id == parentPostID }) {
            refresh.send(true)
            commentPaginationForced.send((post, post.lastCommentDocument))
        }
    }

    func moreButtonTap(post: Post) {
       // more button action removed on profile
        addPostActionSheet(post: post)
    }

    func replyTap(spot: Spot?, parentPostID: String, parentPosterID: String, replyToID: String, replyToUsername: String) {
        // reply action removed on profile
    }

    func profileTap(userInfo: UserProfile) {
        guard userInfo.id ?? "" != viewModel.cachedProfile.id ?? "" else { return }
        let vc = ProfileViewController(viewModel: ProfileViewModel(serviceContainer: ServiceContainer.shared, profile: userInfo))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func spotTap(post: Post) {
        guard let spotID = post.spotID else { return }
        let spot = Spot(id: spotID, spotName: post.spotName ?? "")
        let vc = SpotController(viewModel: SpotViewModel(serviceContainer: ServiceContainer.shared, spot: spot, passedPostID: nil, passedCommentID: nil))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    func mapTap(post: Post) {
        guard let postID = post.id, let mapID = post.mapID, let mapName = post.mapName else { return }
        let map = CustomMap(id: mapID, mapName: mapName)
        let vc = CustomMapController(viewModel: CustomMapViewModel(serviceContainer: ServiceContainer.shared, map: map, passedPostID: postID, passedCommentID: nil))
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ProfileViewController: ProfileOverviewDelegate {
    func addFriend() {
        viewModel.addFriend()
        refresh.send(false)
    }

    func showPendingActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove friend request", style: .destructive) { (_) in
            self.viewModel.removeFriendRequest()
            self.refresh.send(false)
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)

    }

    func showRemoveActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Remove friend", style: .destructive) { (_) in
            self.showRemoveFriendAlert()
        })
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    func showUnblockActionSheet() {
        showUnblockUserAlert()
    }

    func openEditProfile() {
        let editVC = EditProfileViewController(userProfile: UserDataModel.shared.userInfo)
        editVC.delegate = self
        let nav = UINavigationController(rootViewController: editVC)
        nav.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.present(nav, animated: true)
        }
    }

    func inviteFriends() {
        guard let url = URL(string: "https://apps.apple.com/app/id1477764252") else { return }
        let items = [url, "download sp0t 🫵‼️🔥"] as [Any]

        let activityView = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(activityView, animated: true)
        activityView.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                Mixpanel.mainInstance().track(event: "ProfileInviteSent", properties: ["type": activityType?.rawValue ?? ""])
            } else {
                Mixpanel.mainInstance().track(event: "ProfileInviteCancelled")
            }
        }
    }

    func acceptFriendRequest() {
        viewModel.acceptFriendRequest()
        refresh.send(false)
    }

    func avatarTap() {
        guard viewModel.cachedProfile.friendStatus == .activeUser else { return }
        let vc = SpotscoreController(spotscore: UserDataModel.shared.userInfo.spotScore ?? 0)
        vc.delegate = self
        DispatchQueue.main.async {
            self.present(vc, animated: true)
        }

        viewModel.setNewAvatarSeen()
        refresh.send(false)
    }

    private func openAvatarSelection() {
        let vc = AvatarSelectionController(sentFrom: .spotscore, family: AvatarFamily(rawValue: viewModel.cachedProfile.avatarFamily ?? ""))
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ProfileViewController: EditProfileDelegate {
    func finishPassing(userInfo: UserProfile, passedAvatarProfile: AvatarProfile?) {
        viewModel.cachedProfile = userInfo
        if let passedAvatarProfile {
            // update avatar if user changed it
            viewModel.updateUserAvatar(avatar: passedAvatarProfile)
        }

        refresh.send(false)
    }
}

extension ProfileViewController: AvatarSelectionDelegate {
    func finishPassing(avatar: AvatarProfile) {
        viewModel.updateUserAvatar(avatar: avatar)
        refresh.send(false)
    }
}

extension ProfileViewController: SpotscoreDelegate {
    func openEditAvatar(family: AvatarFamily?) {
        let vc = AvatarSelectionController(sentFrom: .edit, family: nil)
        vc.delegate = self
        DispatchQueue.main.async {
            self.navigationController?.pushViewController(vc, animated: false)
        }
    }
}

