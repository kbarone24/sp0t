//
//  CommentsController.swift
//  Spot
//
//  Created by kbarone on 6/25/19.
//  Copyright © 2019 comp523. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import IQKeyboardManagerSwift
import Mixpanel
import FirebaseUI

class CommentsController: UIViewController {
    
    // var friendsList: [UserProfile] = []
    weak var postVC: PostController!
    var post: MapPost!
    
    var likers: [UserProfile] = []
    var commentList: [MapComment] = []
    var taggedUserProfiles: [UserProfile] = []
    
    var selectedIndex = 0 /// tableView cells are comment when 0, like when 1
    var tableView: UITableView!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    
    var footerOffset: UIView!
    var footerView: UIView!
    var profilePic: UIImageView!
    var postButton: UIButton!
    lazy var textView = UITextView()
        
    let emptyTextString = "Comment..."
    
    var panGesture: UIPanGestureRecognizer!
    var tagFriendsView: TagFriendsView?
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
            $0.image = UserDataModel.shared.userInfo.profilePic
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 39/2
            $0.clipsToBounds = true
            footerView.addSubview($0)
        }
        profilePic.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.width.height.equalTo(39)
            $0.bottom.equalToSuperview().inset(15)
        }
        
        textView = UITextView {
            $0.delegate = self
            $0.backgroundColor = UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1)
            $0.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 17)
            $0.alpha = 0.65
            $0.text = emptyTextString
            $0.textContainerInset = UIEdgeInsets(top: 11, left: 12, bottom: 11, right: 60)
            $0.isScrollEnabled = false
            $0.returnKeyType = .send
            $0.textContainer.maximumNumberOfLines = 6
            $0.textContainer.lineBreakMode = .byTruncatingHead
            $0.delegate = self
            $0.layer.cornerRadius = 11
            footerView.addSubview($0)
        }
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
        var ct = 0
        for id in post.likers {
            getUserInfo(userID: id) { [weak self] user in
                guard let self = self else { return }
                self.likers.append(user)
                ct += 1; if ct == self.post.likers.count { self.reloadLikers()}
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
        
        if let i = commentList.firstIndex(where: {$0.id == comment.id}) { commentList[i] = comment }
        updateParent()
        DispatchQueue.main.async { self.tableView.reloadData() }

        if uid == comment.commenterID { return } /// user liked their own comment
        DispatchQueue.global().async {
            self.db.collection("posts").document(post.id!).collection("comments").document(comment.id!).updateData(["likers" : FieldValue.arrayUnion([self.uid])])
            self.db.collection("users").document(comment.commenterID).collection("notifications").addDocument(data: [
                "commentID" : comment.id!,
                "imageURL" : post.imageURLs.first ?? "",
                "postID" : post.id!,
                "seen" : false,
                "senderID" : self.uid,
                "senderUsername" : UserDataModel.shared.userInfo.username,
                "spotID" : post.spotID ?? "",
                "timestamp" : Timestamp(date: Date()),
                "type" : "commentLike"
            ])
        }
    }
    
    func unlikeComment(comment: MapComment, post: MapPost) {
        var comment = comment
        var likers = comment.likers == nil ? [] : comment.likers
        likers!.removeAll(where: {$0 == uid})
        comment.likers = likers
        DispatchQueue.main.async { self.tableView.reloadData() }
        
        if let i = commentList.firstIndex(where: {$0.id == comment.id}) { commentList[i] = comment }
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
        
        db.collection("posts").document(self.post.id!).updateData(["commentCount" : FieldValue.increment(Int64(-1))])
        incrementTopFriends(friendID: post.posterID, increment: -1)
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
        let excludingFirstCommenter = Array(commentList.map({$0.commenterID}).suffix(suffixCount))
        commenterIDList.append(contentsOf: excludingFirstCommenter)
        
        let commentID = UUID().uuidString
        let taggedUsers = getTaggedUsers(text: commentText)
        let taggedUsernames = taggedUsers.map({$0.username})
        let taggedUserIDs = taggedUsers.map({$0.id ?? ""})
        
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
            "addedUsers" : post.addedUsers ?? [],
            "comment": comment.comment,
            "commenterID": comment.commenterID,
            "commenterIDList" : commenterIDList,
            "commenterUsername" : UserDataModel.shared.userInfo.username,
            "imageURL" : post.imageURLs.first ?? "",
            "likers": [],
            "posterID": post.posterID,
            "posterUsername" : post.userInfo?.username ?? "",
            "taggedUserIDs": taggedUserIDs,
            "taggedUsers": comment.taggedUsers ?? [],
            "timestamp": comment.timestamp
        ] as [String: Any] )
        /// set extraneous values
        self.db.collection("posts").document(self.post.id!).updateData(["commentCount" : FieldValue.increment(Int64(1))])
        self.incrementTopFriends(friendID: post.posterID, increment: 1)
   
    }
    
    func resetTextView() {
        textView.text = ""
        textView.resignFirstResponder()
    }
    
    func updateParent() {
        let infoPass = ["commentList": commentList, "postID": post.id as Any] as [String : Any]
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
        
        ///add tag table if @ used
        let cursor = textView.getCursorPosition()
        let tagTuple = getTagUserString(text: textView.text ?? "", cursorPosition: cursor)
        let tagString = tagTuple.text
        let containsAt = tagTuple.containsAt
        if !containsAt {
            removeTagTable()
        } else {
            addTagTable(tagString: tagString)
        }
    }
    
    func removeTagTable() {
        if tagFriendsView != nil {
            tagFriendsView!.removeFromSuperview()
            tagFriendsView = nil
            textView.autocorrectionType = .default
        }
    }
    
    func addTagTable(tagString: String) {
        if tagFriendsView == nil {
            tagFriendsView = TagFriendsView {
                $0.delegate = self
                $0.textColor = .black
                $0.searchText = tagString
                view.addSubview($0)
            }
            tagFriendsView!.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(90)
                $0.bottom.equalTo(footerView.snp.top)
            }
            textView.autocorrectionType = .no
        } else {
            tagFriendsView?.searchText = tagString
        }
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
        animateWithKeyboard(notification: notification) { keyboardFrame in
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
        if (editingStyle == .delete) {
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

class CommentCell: UITableViewCell {
    var comment: MapComment!
    var post: MapPost!
    
    var profilePic: UIImageView!
    var username: UILabel!
    var commentLabel: UILabel!
    var likeButton: UIButton!
    var numLikes: UILabel!
    
    var tagRect: [(rect: CGRect, username: String)] = []
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    
    var likeCount: Int = 0 {
        didSet {
            if likeCount > 0 {
                numLikes.isHidden = false
                numLikes.text = String(likeCount)
            } else {
                numLikes.isHidden = true
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?){
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        translatesAutoresizingMaskIntoConstraints = true
        backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        tag = 30
        setUpView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpView() {
        resetCell()
            
        likeButton = UIButton {
            $0.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
            $0.contentHorizontalAlignment = .center
            $0.contentVerticalAlignment = .center
            contentView.addSubview($0)
        }
        likeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.top.equalTo(21)
            $0.width.equalTo(28.8)
            $0.height.equalTo(27)
        }
  
        numLikes = UILabel {
            $0.textColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Heavy", size: 10.5)
            $0.textAlignment = .center
            $0.isHidden = false
            contentView.addSubview($0)
        }
        numLikes.snp.makeConstraints {
            $0.leading.equalTo(likeButton.snp.trailing)
            $0.bottom.equalTo(likeButton.snp.bottom).inset(5)
        }
        
        profilePic = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.cornerRadius = 39/2
            $0.clipsToBounds = true
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(userTap))
            $0.addGestureRecognizer(tap)
            contentView.addSubview($0)
        }
        profilePic.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.top.equalTo(15)
            $0.width.height.equalTo(39)
        }

        username = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            $0.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(userTap))
            $0.addGestureRecognizer(tap)
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(9)
            $0.top.equalTo(17)
            $0.trailing.lessThanOrEqualTo(likeButton.snp.leading).inset(5)
        }
                
        commentLabel = UILabel {
            $0.lineBreakMode = .byWordWrapping
            $0.numberOfLines = 0
            $0.textColor = UIColor(red: 0.562, green: 0.562, blue: 0.562, alpha: 1)
            $0.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
            $0.isUserInteractionEnabled = true
            contentView.addSubview($0)
        }
        commentLabel.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(9)
            $0.trailing.lessThanOrEqualTo(likeButton.snp.leading).offset(-8)
            $0.top.equalTo(username.snp.bottom).offset(1)
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }
    
    func setUp(comment: MapComment, post: MapPost) {
        self.comment = comment
        self.post = post
        
        let commentString = NSAttributedString(string: comment.comment)
        commentLabel.attributedText = commentString
        commentLabel.sizeToFit()
        addAttString()
        
        username.text = comment.userInfo?.username ?? ""
        username.sizeToFit()
        
        let liked = comment.likers?.contains(where: {$0 == uid}) ?? false
        let image = liked ? UIImage(named: "CommentLikeButtonFilled") : UIImage(named: "CommentLikeButton")?.withTintColor(UIColor(red: 0.342, green: 0.342, blue: 0.342, alpha: 1))
        likeButton.setImage(image, for: .normal)
        liked ? likeButton.addTarget(self, action: #selector(unlikeTap(_:)), for: .touchUpInside) : likeButton.addTarget(self, action: #selector(likeTap(_:)), for: .touchUpInside)
        likeCount = comment.likers?.count ?? 0
        
        let url = comment.userInfo?.imageURL ?? ""
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
    }
        
    func resetCell() {
        if profilePic != nil { profilePic.removeFromSuperview() }
        if username != nil { username.text = ""; username.removeFromSuperview() }
        if commentLabel != nil { commentLabel.text = ""; commentLabel.attributedText = nil; commentLabel.removeFromSuperview() }
        if likeButton != nil { likeButton.removeFromSuperview() }
        if numLikes != nil { numLikes.text = ""; numLikes.removeFromSuperview() }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    func addAttString() {
        if !(comment.taggedUsers?.isEmpty ?? true) {
            let attString = self.getAttString(caption: comment.comment, taggedFriends: comment.taggedUsers!, font: commentLabel.font, maxWidth: UIScreen.main.bounds.width - 105)
            commentLabel.attributedText = attString.0
            tagRect = attString.1
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:)))
            commentLabel.isUserInteractionEnabled = true
            commentLabel.addGestureRecognizer(tap)
        }
    }

    func tagUser() {
        /// @ tapped comment's poster at the end of the active comment text
        let username = "@\(comment.userInfo?.username ?? "") "
        
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        if !commentsVC.textView.isFirstResponder {
            var text = (commentsVC.textView.text ?? "")
            if text == commentsVC.emptyTextString { text = ""; commentsVC.textView.alpha = 1.0; commentsVC.postButton.isEnabled = true } /// have to enable manually because the textView didn't technically "edit"
            text.insert(contentsOf: username, at: text.startIndex)
            commentsVC.textView.text = text
        }
    }
    
    @objc func likeTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsLikeComment")
        if let commentsVC = viewContainingController() as? CommentsController {
            commentsVC.likeComment(comment: comment, post: post)
        }
    }
    
    @objc func unlikeTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsUnlikeComment")
        if let commentsVC = viewContainingController() as? CommentsController {
            commentsVC.unlikeComment(comment: comment, post: post)
        }
    }
        
    @objc func tappedLabel(_ sender: UITapGestureRecognizer) {
        // tag tap
        for r in tagRect {
            if r.rect.contains(sender.location(in: sender.view)) {
                Mixpanel.mainInstance().track(event: "CommentsOpenTaggedUserProfile")
                /// open tag from friends list
                if let friend = UserDataModel.shared.userInfo.friendsList.first(where: {$0.username == r.username}) {
                    openProfile(user: friend)
                    return
                } else {
                    /// pass blank user object to open func, run get user func on profile load
                    let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                    self.openProfile(user: user)
                }
            }
        }
        Mixpanel.mainInstance().track(event: "CommentsTapTagUser")
        tagUser()
    }
    
    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "CommentsUserTap")
        guard let user = comment.userInfo else { return }
        openProfile(user: user)
    }
    

    func openProfile(user: UserProfile) {
        if let commentsVC = self.viewContainingController() as? CommentsController {
            commentsVC.openProfile(user: user)
        }
    }
}

class CommentsControl: UITableViewHeaderFooterView {
    var buttonBar: UIView!
    var commentSeg: CommentSeg!
    var likeSeg: LikeSeg!
    
    var selectedIndex: Int = 0 {
        didSet {
            commentSeg.index = selectedIndex
            likeSeg.index = selectedIndex
            setBarConstraints()
        }
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        isUserInteractionEnabled = true
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        self.backgroundView = backgroundView
        
        setUp()
    }
    
    func setUp() {
        let segWidth: CGFloat = 125
        if commentSeg != nil { return }
        
        commentSeg = CommentSeg {
            $0.addTarget(self, action: #selector(commentSegTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        commentSeg.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-3.5)
            $0.trailing.equalTo(snp.centerX).offset(-5)
            $0.width.equalTo(segWidth)
        }

        likeSeg = LikeSeg {
            $0.addTarget(self, action: #selector(likeSegTap(_:)), for: .touchUpInside)
            addSubview($0)
        }
        likeSeg.snp.makeConstraints {
            $0.bottom.equalToSuperview().offset(-3.5)
            $0.leading.equalTo(snp.centerX).offset(5)
            $0.width.equalTo(segWidth)
        }
    
        buttonBar = UIButton {
            $0.backgroundColor = .black
            $0.layer.cornerRadius = 1
            addSubview($0)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc func commentSegTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsCommentsSegTap")
        if selectedIndex == 1 {
            switchToCommentSeg()
        }
    }
        
    @objc func likeSegTap(_ sender: UIButton) {
        Mixpanel.mainInstance().track(event: "CommentsLikeSegTap")
        if selectedIndex == 0 {
            switchToLikeSeg()
            guard let commentsVC = viewContainingController() as? CommentsController else { return }
            commentsVC.textView.resignFirstResponder()
        }
    }
    
    func switchToLikeSeg() {
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 1
        commentsVC.tableView.reloadData()
        commentsVC.footerView.isHidden = true
    }

    func switchToCommentSeg() {
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 0
        commentsVC.tableView.reloadData()
        commentsVC.footerView.isHidden = false
        commentsVC.footerView.becomeFirstResponder()
    }
    
    func setBarConstraints() {
        buttonBar.snp.removeConstraints()
        let selectedButton = selectedIndex == 0 ? commentSeg : likeSeg
        buttonBar.snp.makeConstraints {
            $0.leading.equalTo(selectedButton!.snp.leading)
            $0.top.equalTo(selectedButton!.snp.bottom)
            $0.width.equalTo(selectedButton!.snp.width)
            $0.height.equalTo(3.5)
        }
    }
    
    func animateSegmentSwitch() {
        let selectedButton = selectedIndex == 0 ? commentSeg : likeSeg
        UIView.animate(withDuration: 0.2) {
            self.buttonBar.snp.updateConstraints {
                $0.leading.equalTo(selectedButton!.snp.leading)
            }
            self.buttonBar.layoutIfNeeded()
        }
    }
}

class CommentSeg: UIButton {
    var commentIcon: UIImageView!
    var commentLabel: UILabel!
    
    var commentCount: Int = 0 {
        didSet {
            var commentText = "\(max(commentCount, 0)) comment"
            if commentCount - 1 != 1 { commentText += "s" }
            commentLabel.text = commentText
        }
    }
    
    var index: Int = 0 {
        didSet {
            let selectedSeg = index == 0
            commentIcon.alpha = selectedSeg ? 1.0 : 0.6
            commentLabel.alpha = selectedSeg ? 1.0 : 0.6
            commentLabel.font = selectedSeg ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        }
    }
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commentIcon = UIImageView {
            $0.image = UIImage(named: "CommentSegCommentIcon")
            addSubview($0)
        }
        commentIcon.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22.4)
        }
        
        commentLabel = UILabel {
            $0.textColor = .black
            addSubview($0)
        }
        commentLabel.snp.makeConstraints {
            $0.leading.equalTo(commentIcon.snp.trailing).offset(5)
            $0.centerY.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LikeSeg: UIButton {
    var likeIcon: UIImageView!
    var likeLabel: UILabel!
    
    var likeCount: Int = 0 {
        didSet {
            var likeText = "\(max(likeCount, 0)) like"
            if likeCount - 1 != 1 { likeText += "s" }
            likeLabel.text = likeText
        }
    }
    
    var index: Int = 0 {
        didSet {
            let selectedSeg = index == 1
            likeIcon.alpha = selectedSeg ? 1.0 : 0.6
            likeLabel.alpha = selectedSeg ? 1.0 : 0.6
            likeLabel.font = selectedSeg ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        }
    }
        
    override init(frame: CGRect) {
        super.init(frame: frame)
                
        likeLabel = UILabel {
            $0.textColor = .black
            addSubview($0)
        }
        likeLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview().offset(12.5)
            $0.centerY.equalToSuperview()
        }
        
        likeIcon = UIImageView {
            $0.image = UIImage(named: "CommentSegLikeIcon")
            addSubview($0)
        }
        likeIcon.snp.makeConstraints {
            $0.trailing.equalTo(likeLabel.snp.leading).offset(-5)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(22.5)
            $0.height.equalTo(20)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LikerCell: UITableViewCell {
    var profilePic: UIImageView!
    var username: UILabel!
    var user: UserProfile!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(likerCellTap)))
        
        profilePic = UIImageView {
            $0.layer.cornerRadius = 39/2
            $0.clipsToBounds = true
            $0.contentMode = .scaleAspectFill
            contentView.addSubview($0)
        }
        profilePic.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.top.equalTo(15)
            $0.width.height.equalTo(39)
        }
      
        username = UILabel {
            $0.textColor = .black
            $0.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
            contentView.addSubview($0)
        }
        username.snp.makeConstraints {
            $0.leading.equalTo(profilePic.snp.trailing).offset(9)
            $0.centerY.equalTo(profilePic.snp.centerY)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUp(user: UserProfile) {
        let url = user.imageURL
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        username.text = user.username
        self.user = user
    }
                                         
    @objc func likerCellTap() {
        Mixpanel.mainInstance().track(event: "CommentsLikerCellTap")
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.openProfile(user: user)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        /// cancel image fetch when cell leaves screen
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}
