//
//  PopViewModelActions.swift
//  Spot
//
//  Created by Kenny Barone on 8/29/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation

extension PopViewModel {
    func addNewPost(post: Post) {
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }) {
                recentPosts[i].postChildren?.append(post)
            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }) {
                topPosts[i].postChildren?.append(post)
            }
        } else {
            activeSortMethod = .New
            recentPosts.insert(post, at: 0)
        }
    }

    func hidePost(post: Post) {
        deletePostLocally(post: post)
        postService.hidePost(post: post)
    }

    func reportPost(post: Post, feedbackText: String) {
        deletePostLocally(post: post)
        postService.reportPost(post: post, feedbackText: feedbackText)
    }

    func deletePost(post: Post) {
        deletePostLocally(post: post)
        postService.deletePost(post: post)
    }

    private func deletePostLocally(post: Post) {
        UserDataModel.shared.deletedPostIDs.append(post.id ?? "")
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }) {
                recentPosts[i].commentCount = (recentPosts[i].commentCount ?? 1) - 1
                recentPosts[i].postChildren?.removeAll(where: { $0.id == post.id ?? "" })

            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }) {
                topPosts[i].commentCount = (topPosts[i].commentCount ?? 1) - 1
                topPosts[i].postChildren?.removeAll(where: { $0.id == post.id ?? "" })
            }
        } else {
            recentPosts.removeAll(where: { $0.id == post.id ?? "" })
            topPosts.removeAll(where: { $0.id == post.id ?? "" })
        }
    }

    func getSelectedIndexFor(postID: String) -> Int? {
        return presentedPosts.firstIndex(where: { $0.id == postID })
    }


    // adjust liker directly from postChild -> getAllPosts function will reset comment posts from postChildren
    func likePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }), let j = recentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                recentPosts[i].postChildren?[j].likers.append(UserDataModel.shared.uid)
            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }), let j = topPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                topPosts[i].postChildren?[j].likers.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
                recentPosts[i].likers.append(UserDataModel.shared.uid)
            }
            if let i = topPosts.firstIndex(where: { $0.id == postID }) {
                topPosts[i].likers.append(UserDataModel.shared.uid)
            }
        }
        postService.likePostDB(post: post)
    }

    func unlikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }), let j = recentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                recentPosts[i].postChildren?[j].likers.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }), let j = topPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                topPosts[i].postChildren?[j].likers.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
                recentPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
            if let i = topPosts.firstIndex(where: { $0.id == postID }) {
                topPosts[i].likers.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.unlikePostDB(post: post)
    }

    func dislikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }), let j = recentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                recentPosts[i].postChildren?[j].dislikers?.append(UserDataModel.shared.uid)
            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }), let j = topPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                topPosts[i].postChildren?[j].dislikers?.append(UserDataModel.shared.uid)
            }
        } else {
            if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
                recentPosts[i].dislikers?.append(UserDataModel.shared.uid)
            }
            if let i = topPosts.firstIndex(where: { $0.id == postID }) {
                topPosts[i].dislikers?.append(UserDataModel.shared.uid)
            }
        }
        postService.dislikePostDB(post: post)
    }

    func undislikePost(post: Post) {
        guard let postID = post.id else { return }
        if let parentID = post.parentPostID, parentID != "" {
            if let i = recentPosts.firstIndex(where: { $0.id == parentID }), let j = recentPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                recentPosts[i].postChildren?[j].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
            if let i = topPosts.firstIndex(where: { $0.id == parentID }), let j = topPosts[i].postChildren?.firstIndex(where: { $0.id == post.id }) {
                topPosts[i].postChildren?[j].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid} )
            }
        } else {
            if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
                recentPosts[i].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
            if let i = topPosts.firstIndex(where: { $0.id == postID }) {
                topPosts[i].dislikers?.removeAll(where: { $0 == UserDataModel.shared.uid })
            }
        }
        postService.undislikePostDB(post: post)
    }

    func addUserToVisitorList() {
        // add user to visitor List to immediately show update
        var visitorList = cachedPop.visitorList
        visitorList.append(UserDataModel.shared.uid)
        cachedPop.visitorList = visitorList.removingDuplicates()
    }

    func setSeen() {
        // add user to seen list, add user to visitor list
        popService.setSeen(pop: cachedPop)
    }

    func updateParentPostCommentCount(post: Post) {
        if let i = recentPosts.firstIndex(where: { $0.id == post.id ?? "" }) {
            recentPosts[i].commentCount = post.commentCount ?? 0
        }
    }

    func removePostHighlight(postID: String, commentID: String?) {
        if let i = recentPosts.firstIndex(where: { $0.id == postID }) {
            if let commentID, let j = recentPosts[i].postChildren?.firstIndex(where: { $0.id == commentID }) {
                // remove comment highlight
                recentPosts[i].postChildren?[j].highlightCell = false
            } else {
                // remove post highlight
                recentPosts[i].highlightCell = false
            }
        }
    }
}
