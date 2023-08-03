//
//  CommensControllerActions.swift
//  Spot
//
//  Created by Kenny Barone on 2/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import Mixpanel

extension CommentsController {
    func likeComment(comment: MapComment, post: MapPost) {
        var likers = comment.likers == nil ? [] : comment.likers
        likers?.append(uid)
        var comment = comment
        comment.likers = likers

        if let i = commentList.firstIndex(where: { $0.id == comment.id }) { commentList[i] = comment }
        updateParent()
        DispatchQueue.main.async { self.tableView.reloadData() }

        if uid == comment.commenterID { return } /// user liked their own comment
        DispatchQueue.global().async {
            self.db.collection("posts").document(post.id ?? "").collection("comments").document(comment.id ?? "").updateData(["likers": FieldValue.arrayUnion([self.uid])])
            self.db.collection("users").document(comment.commenterID).collection("notifications").addDocument(data: [
                "commentID": comment.id ?? "",
                "imageURL": post.imageURLs.first ?? "",
                "postID": post.id ?? "",
                "seen": false,
                "senderID": self.uid,
                "senderUsername": UserDataModel.shared.userInfo.username,
                "spotID": post.spotID ?? "",
                "timestamp": Timestamp(date: Date()),
                "type": "commentLike"
            ])
            if let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService) {
                if post.posterID != UserDataModel.shared.uid {
                    mapPostService.incrementSpotScoreFor(userID: post.posterID, increment: 1)
                    mapPostService.incrementSpotScoreFor(userID: UserDataModel.shared.uid, increment: 1)
                }
            }
        }
    }

    func unlikeComment(comment: MapComment, post: MapPost) {
        var comment = comment
        var likers = comment.likers == nil ? [] : comment.likers
        likers?.removeAll(where: { $0 == uid })
        comment.likers = likers
        DispatchQueue.main.async { self.tableView.reloadData() }

        if let i = commentList.firstIndex(where: { $0.id == comment.id }) { commentList[i] = comment }
        updateParent()
        DispatchQueue.main.async { self.tableView.reloadData() }

        let functions = Functions.functions()
        functions.httpsCallable("unlikeComment").call(["postID": post.id ?? "", "commentID": comment.id ?? "", "commenterID": comment.commenterID, "likerID": uid]) { result, error in
            print(result?.data as Any, error as Any)
        }
        
        if let mapPostService = try? ServiceContainer.shared.service(for: \.mapPostService) {
            if post.posterID != UserDataModel.shared.uid {
                mapPostService.incrementSpotScoreFor(userID: post.posterID, increment: -1)
                mapPostService.incrementSpotScoreFor(userID: UserDataModel.shared.uid, increment: -1)
            }
        }
    }

    func deleteComment(commentID: String) {
        Mixpanel.mainInstance().track(event: "CommentsDelete")
        let postID = post.id ?? ""
        let postsRef = self.db.collection("posts").document(postID).collection("comments").document(commentID)
                postsRef.delete()

        db.collection("posts").document(self.post.id ?? "").updateData(["commentCount": FieldValue.increment(Int64(-1))])
        friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)

        commentList.removeAll(where: { $0.id == commentID })
        post.commentCount = max(0, commentList.count - 1)
        post.commentList = commentList

        updateParent()
    }

    @objc func postComment(_ sender: UIButton) {
        postComment()
    }

    func postComment() {
        /// check for empty
        guard var commentText = textView.text else { return }
        if commentText == emptyTextString { return }
        while commentText.last?.isNewline ?? false {
            commentText = String(commentText.dropLast())
        }
        if commentText.replacingOccurrences(of: " ", with: "") == "" { return }

        Mixpanel.mainInstance().track(event: "CommentsPost")

        var commenterIDList = [uid]
        let suffixCount = max(commentList.count - 1, 0)
        let excludingFirstCommenter = Array(commentList.map({ $0.commenterID }).suffix(suffixCount))
        commenterIDList.append(contentsOf: excludingFirstCommenter)

        let commentID = UUID().uuidString
        let taggedUsers = commentText.getTaggedUsers()
        let taggedUsernames = taggedUsers.map({ $0.username })
        let taggedUserIDs = taggedUsers.map({ $0.id ?? "" })

        let comment = MapComment(id: commentID, comment: commentText, commenterID: self.uid, taggedUsers: taggedUsernames, timestamp: Timestamp(date: Date()), userInfo: UserDataModel.shared.userInfo)
        commentList.append(comment)

        post.commentCount = max(0, commentList.count - 1)
        post.commentList = commentList

        DispatchQueue.main.async {
            self.resetTextView()
            self.tableView.reloadData()
            self.updateParent()
        }

        let commentRef = db.collection("posts").document(self.post.id ?? "").collection("comments")
        /// set additional values for notification handling
        commentRef.addDocument(data: [
        //    "addedUsers": post.tagged ?? [],
            "comment": comment.comment,
            "commenterID": comment.commenterID,
            "commenterIDList": commenterIDList,
            "commenterUsername": UserDataModel.shared.userInfo.username,
            "imageURL": post.imageURLs.first ?? "",
            "likers": [],
            "posterID": post.posterID,
            "posterUsername": post.userInfo?.username ?? "",
            "taggedUserIDs": taggedUserIDs,
            "taggedUsers": comment.taggedUsers ?? [],
            "timestamp": comment.timestamp
        ] as [String: Any] )
        /// set extraneous values
        self.db.collection("posts").document(self.post.id ?? "").updateData(["commentCount": FieldValue.increment(Int64(1))])
        friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)
    }

    func resetTextView() {
        textView.text = ""
        textView.resignFirstResponder()
    }

    func updateParent() {
        let infoPass = ["post": post, "like": false] as [String: Any]
        NotificationCenter.default.post(name: Notification.Name("PostChanged"), object: nil, userInfo: infoPass)
    }
}
