//
//  CommentsController.swift
//  Spot
//
//  Created by kbarone on 6/25/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Firebase
import Foundation
import IQKeyboardManagerSwift
import Mixpanel
import UIKit
import SDWebImage

final class CommentsController: UIViewController {

    // var friendsList: [UserProfile] = []
    weak var postVC: PostController!
    var post: MapPost!

    var likers: [UserProfile] = []
    var commentList: [MapComment] = []
    var taggedUserProfiles: [UserProfile] = []

    var selectedIndex = 0 /// tableView cells are comment when 0, like when 1
    var tableView: UITableView!

    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db = Firestore.firestore()

    var footerOffset: UIView!
    var footerView: UIView!
    var profilePic: UIImageView!
    var postButton: UIButton!
    
    
    private(set) lazy var textView: UITextView = {
        let textView = UITextView()
        
        textView.delegate = self
        textView.backgroundColor = UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1)
        textView.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        textView.font = UIFont(name: "SFCompactText-Semibold", size: 17)
        textView.alpha = 0.65
        textView.text = emptyTextString
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 60)
        textView.isScrollEnabled = false
        textView.returnKeyType = .send
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.delegate = self
        textView.layer.cornerRadius = 11
        
        return textView
    }()

    lazy var friendService: FriendsServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.friendsService)
        return service
    }()
    
    private lazy var userService: UserServiceProtocol? = {
        let service = try? ServiceContainer.shared.service(for: \.userService)
        return service
    }()
    
    let emptyTextString = "Comment..."

    var panGesture: UIPanGestureRecognizer!
    
    private(set) lazy var tagFriendsView: TagFriendsView = {
        let view = TagFriendsView()
        view.delegate = self
        view.textColor = .black
        
        return view
    }()
    
    var cancelOnDismiss = false
    var firstOpen = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)

        addTable()
        addFooter()

        DispatchQueue.global().async {
            self.getLikers()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disableKeyboardMethods()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enableKeyboardMethods()

        if firstOpen {
            DispatchQueue.main.async { self.textView.becomeFirstResponder() }
            firstOpen = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Mixpanel.mainInstance().track(event: "CommentsOpen")
    }

    func enableKeyboardMethods() {
        IQKeyboardManager.shared.enableAutoToolbar = false
        IQKeyboardManager.shared.enable = false /// disable for textView sticking to keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func disableKeyboardMethods() {
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
    }

    func addTable() {
        tableView = UITableView {
            $0.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            $0.separatorStyle = .none
            $0.dataSource = self
            $0.delegate = self
            $0.showsVerticalScrollIndicator = false
            $0.allowsSelection = false
            $0.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
            $0.estimatedRowHeight = 50
            $0.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
            $0.register(CommentsControl.self, forHeaderFooterViewReuseIdentifier: "CommentsControl")
            $0.register(LikerCell.self, forCellReuseIdentifier: "LikerCell")
            view.addSubview($0)
        }
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        panGesture.isEnabled = false
        tableView.addGestureRecognizer(panGesture)
    }

    func addFooter() {
        footerOffset = UIView {
            $0.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            view.addSubview($0)
        }
        footerOffset.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(40)
        }
        /// footerView isn't a true footer but the input accessory view used to fix text to the keyboard
        footerView = UIView {
            $0.backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
            view.addSubview($0)
        }
        footerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footerOffset.snp.top)
        }

        profilePic = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 39 / 2
            $0.clipsToBounds = true
            footerView.addSubview($0)
        }
        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profilePic.sd_setImage(
            with: URL(string: UserDataModel.shared.userInfo.imageURL),
            placeholderImage: UIImage(color: UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)),
            options: .highPriority,
            context: [.imageTransformer: transformer]
        )

        profilePic.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.width.height.equalTo(39)
            $0.bottom.equalToSuperview().inset(15)
        }

        footerView.addSubview(textView)
        textView.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(15)
            $0.trailing.equalToSuperview().inset(17)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalToSuperview().inset(12)
        }

        postButton = UIButton {
            $0.setImage(UIImage(named: "PostCommentButton"), for: .normal)
            $0.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.addTarget(self, action: #selector(postComment(_:)), for: .touchUpInside)
            $0.isEnabled = false
            footerView.addSubview($0)
        }
        postButton.snp.makeConstraints {
            $0.trailing.equalTo(textView.snp.trailing).inset(7)
            $0.width.height.equalTo(32)
            $0.bottom.equalTo(textView.snp.bottom).inset(6)
        }
    }

    func getLikers() {
        Task {
            var ct = 0
            for id in post.likers {
                guard let user = try? await userService?.getUserInfo(userID: id) else {
                    continue
                }

                self.likers.append(user)
                ct += 1
                
                if ct == self.post.likers.count {
                    self.reloadLikers()
                }
            }
        }
    }

    func reloadLikers() {
        if selectedIndex == 1 { DispatchQueue.main.async { self.tableView.reloadData() } }
    }
}

/// database methods
extension CommentsController {
    func likeComment(comment: MapComment, post: MapPost) {
        var likers = comment.likers == nil ? [] : comment.likers
        likers!.append(uid)
        var comment = comment
        comment.likers = likers

        if let i = commentList.firstIndex(where: { $0.id == comment.id }) { commentList[i] = comment }
        updateParent()
        DispatchQueue.main.async { self.tableView.reloadData() }

        if uid == comment.commenterID { return } /// user liked their own comment
        DispatchQueue.global().async {
            self.db.collection("posts").document(post.id!).collection("comments").document(comment.id!).updateData(["likers": FieldValue.arrayUnion([self.uid])])
            self.db.collection("users").document(comment.commenterID).collection("notifications").addDocument(data: [
                "commentID": comment.id!,
                "imageURL": post.imageURLs.first ?? "",
                "postID": post.id!,
                "seen": false,
                "senderID": self.uid,
                "senderUsername": UserDataModel.shared.userInfo.username,
                "spotID": post.spotID ?? "",
                "timestamp": Timestamp(date: Date()),
                "type": "commentLike"
            ])
        }
    }

    func unlikeComment(comment: MapComment, post: MapPost) {
        var comment = comment
        var likers = comment.likers == nil ? [] : comment.likers
        likers!.removeAll(where: { $0 == uid })
        comment.likers = likers
        DispatchQueue.main.async { self.tableView.reloadData() }

        if let i = commentList.firstIndex(where: { $0.id == comment.id }) { commentList[i] = comment }
        updateParent()
        DispatchQueue.main.async { self.tableView.reloadData() }

        let functions = Functions.functions()
        functions.httpsCallable("unlikeComment").call(["postID": post.id!, "commentID": comment.id!, "commenterID": comment.commenterID, "likerID": uid]) { result, error in
            print(result?.data as Any, error as Any)
        }
    }

    func deleteComment(commentID: String) {
        Mixpanel.mainInstance().track(event: "CommentsDelete")
        let postID = post.id!
        let postsRef = self.db.collection("posts").document(postID).collection("comments").document(commentID)
                postsRef.delete()

        db.collection("posts").document(self.post.id!).updateData(["commentCount": FieldValue.increment(Int64(-1))])
        friendService?.incrementTopFriends(friendID: post.posterID, increment: -1, completion: nil)
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

        DispatchQueue.main.async {
            self.resetTextView()
            self.tableView.reloadData()
            self.updateParent()
        }

        let commentRef = db.collection("posts").document(self.post.id!).collection("comments")
        /// set additional values for notification handling
        commentRef.addDocument(data: [
            "addedUsers": post.addedUsers ?? [],
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
        self.db.collection("posts").document(self.post.id!).updateData(["commentCount": FieldValue.increment(Int64(1))])
        friendService?.incrementTopFriends(friendID: post.posterID, increment: 1, completion: nil)

    }

    func resetTextView() {
        textView.text = ""
        textView.resignFirstResponder()
    }

    func updateParent() {
        let infoPass = ["commentList": commentList, "postID": post.id as Any] as [String: Any]
        NotificationCenter.default.post(name: Notification.Name("CommentChange"), object: nil, userInfo: infoPass)
    }

    func openProfile(user: UserProfile) {
        postVC.openProfile(user: user, openComments: true)
        DispatchQueue.main.async { self.dismiss(animated: true) }
    }
}

extension CommentsController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        /// send tap
        if text == "\n" { postComment(); return false }

        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        return updatedText.count <= 560
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
        view.addSubview(tagFriendsView)
        tagFriendsView.searchText = tagString
        tagFriendsView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(90)
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
}

extension CommentsController: TagFriendsDelegate {
    func finishPassing(selectedUser: UserProfile) {
        textView.addUsernameAtCursor(username: selectedUser.username)
        removeTagTable()
    }
}

extension CommentsController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedIndex == 0 ? commentList.count - 1 : likers.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return selectedIndex == 0 ? UITableView.automaticDimension : 46
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedIndex {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
            cell.setUp(comment: commentList[indexPath.row + 1], post: post)
            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "LikerCell", for: indexPath) as! LikerCell
            cell.setUp(user: likers[indexPath.row])
            return cell

        default: return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let comment = commentList[safe: indexPath.row + 1] else { return .none }
        return comment.commenterID == self.uid ? .delete : .none
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        // swipe to delete comment
        if editingStyle == .delete {
            let commentID = commentList[indexPath.row + 1].id!
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

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "CommentsControl") as? CommentsControl {
            header.selectedIndex = selectedIndex
            header.likeSeg.likeCount = post.likers.count
            header.commentSeg.commentCount = max(commentList.count - 1, 0)
            return header
        } else { return UITableViewHeaderFooterView() }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 64
    }
    ///https://stackoverflow.com/questions/37942812/turn-some-parts-of-uilabel-to-act-like-a-uibutton

}
