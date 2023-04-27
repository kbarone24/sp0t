//
//  CommentsControllerDelegate.swift
//  Spot
//
//  Created by Kenny Barone on 2/3/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

extension CommentsController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        /// send tap
        if text == "\n" { postComment(); return false }
        return textView.shouldChangeText(range: range, replacementText: text, maxChar: 450)
    }

    func textViewDidChange(_ textView: UITextView) {
        let trimText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.postButton.isEnabled = trimText != ""
        self.textView.alpha = trimText == "" ? 0.65 : 1.0

        // add tag table if @ used
        let cursor = textView.getCursorPosition()
        let text = textView.text ?? ""
        let tagTuple = text.getTagUserString(cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
        } else {
            addTagTable(tagString: tagString)
        }
    }

    func removeTagTable() {
        tagFriendsView.removeFromSuperview()
        textView.autocorrectionType = .default
    }

    func addTagTable(tagString: String) {
        let friendsList = UserDataModel.shared.userInfo.friendsList

        var userList = [UserProfile]()
        let allowSearch = post.privacyLevel != "invite"
        if post.privacyLevel != "invite" {
            userList.append(contentsOf: friendsList)
        } else {
            userList.append(contentsOf: friendsList.filter({ post.inviteList?.contains($0.id ?? "") ?? false }))
        }

        userList.removeDuplicates()

        view.addSubview(tagFriendsView)
        tagFriendsView.setUp(userList: userList, textColor: .black, delegate: self, allowSearch: allowSearch, tagParent: .Comments, searchText: tagString)
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(120)
            $0.bottom.equalTo(footerView.snp.top)
        }

        textView.autocorrectionType = .no
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        panGesture.isEnabled = true
        if textView.alpha < 0.7 {
            textView.text = nil
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        panGesture.isEnabled = false
        if textView.text.isEmpty {
            textView.alpha = 0.65
            textView.text = emptyTextString
        }
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        if cancelOnDismiss { return }
        animateWithKeyboard(notification: notification) { keyboardFrame in
            self.footerView.snp.removeConstraints()
            self.footerView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview().offset(-keyboardFrame.height)
            //    $0.height.greaterThanOrEqualTo(66)
            }
        }
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        if cancelOnDismiss { return }
        animateWithKeyboard(notification: notification) { _ in
            self.footerView.snp.removeConstraints()
            self.footerView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(self.footerOffset.snp.top)
          //      $0.height.greaterThanOrEqualTo(66)
            }
        }
    }

    @objc func pan(_ sender: UIPanGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        let direction = sender.velocity(in: view)
        if abs(direction.y) > 100 { textView.resignFirstResponder() }
    }

    // https://www.advancedswift.com/animate-with-ios-keyboard-swift/
    private func animateWithKeyboard(
        notification: NSNotification,
        animations: ((_ keyboardFrame: CGRect) -> Void)?
    ) {
        // Extract the duration of the keyboard animation
        let durationKey = UIResponder.keyboardAnimationDurationUserInfoKey
        let duration = notification.userInfo?[durationKey] as? Double ?? 0

        // Extract the final frame of the keyboard
        let frameKey = UIResponder.keyboardFrameEndUserInfoKey
        let keyboardFrameValue = notification.userInfo?[frameKey] as? NSValue

        // Extract the curve of the iOS keyboard animation
        let curveKey = UIResponder.keyboardAnimationCurveUserInfoKey
        let curveValue = notification.userInfo?[curveKey] as? Int ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveValue) ?? .easeIn

        // Create a property animator to manage the animation
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: curve
        ) {
            // Perform the necessary animation layout updates
            animations?(keyboardFrameValue?.cgRectValue ?? .zero)

            // Required to trigger NSLayoutConstraint changes
            // to animate
            self.view?.layoutIfNeeded()
        }

        // Start the animation
        animator.startAnimation()
    }
}

extension CommentsController: CommentCellDelegate {
    func tagUserFromCell(username: String) {
        var text = (textView.text ?? "")
        // have to enable manually because the textView didn't technically "edit"
        if text == emptyTextString {
            text = ""
            textView.alpha = 1.0
            postButton.isEnabled = true
        }
        text.insert(contentsOf: username, at: text.startIndex)
        textView.text = text
    }

    func likeCommentFromCell(comment: MapComment) {
        likeComment(comment: comment, post: post)
    }

    func unlikeCommentFromCell(comment: MapComment) {
        unlikeComment(comment: comment, post: post)
    }

    func openProfileFromCell(user: UserProfile) {
        DispatchQueue.main.async {
            self.delegate?.openProfileFromComments(user: user)
            self.dismiss(animated: true)
        }
    }
}

extension CommentsController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commentList.count - 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as? CommentCell {
            cell.setUp(comment: commentList[indexPath.row + 1], post: post)
            cell.delegate = self
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let comment = commentList[safe: indexPath.row + 1] else { return .none }
        return comment.commenterID == self.uid ? .delete : .none
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // swipe to delete comment
        if editingStyle == .delete {
            let commentID = commentList[indexPath.row + 1].id ?? ""
            commentList.remove(at: indexPath.row + 1)
            deleteComment(commentID: commentID)

            let path = IndexPath(row: indexPath.row, section: 0)
            DispatchQueue.main.async {
                tableView.performBatchUpdates {
                    tableView.deleteRows(at: [path], with: .fade)
                } completion: { _ in
                    tableView.reloadData()
                }
            }
        }
    }
}
