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
    var postIndex = 0
    
    var likers: [UserProfile] = []
    var commentList: [MapComment] = []
    
    var selectedIndex = 0 /// tableView cells are comment when 0, like when 1
    var commentsTable: UITableView!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    var listener1: ListenerRegistration!
    
    var footerView: UIView!
    var profilePic: UIImageView!
    var textView: UITextView!
    var postButton: UIButton!
    
    var panGesture: UIPanGestureRecognizer!
    
    override var canBecomeFirstResponder: Bool { return true }
    override var canResignFirstResponder: Bool { return true }
    
    var downloads: [StorageDownloadTask] = []
    var active = true
    
    let emptyTextString = "Comment..."
    
    override var inputAccessoryView: UIView {
        if footerView == nil {
            addFooter()
        }
        return footerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyCommentLike(_:)), name: NSNotification.Name("CommentLike"), object: nil)
        view.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        post.captionHeight = getCaptionHeight(caption: post.caption, noImage: false, maxCaption: 0, truncated: false) /// run get captionheight again for 14.7 font caption at full length
        
        addTable()
        DispatchQueue.global().async { self.getLikers() }
        
        db.collection("users").getDocuments { snap, err in
            for doc in snap!.documents {
                doc.reference.collection("notifications").whereField("type", isEqualTo: "commenComment").getDocuments { com, err in
                    for doc in com!.documents {
                        doc.reference.updateData(["type" : "commentComment"])
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        active = false
        for download in downloads { download.cancel() }
        if postVC != nil && postVC.mapVC != nil { postVC.mapVC.removeTable() }
        
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = false
        Mixpanel.mainInstance().track(event: "CommentsOpen")
    }
        
    func addTable() {
        
        commentsTable = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        commentsTable.backgroundColor = nil
        commentsTable.separatorStyle = .none
        commentsTable.dataSource = self
        commentsTable.delegate = self
        commentsTable.showsVerticalScrollIndicator = false
        commentsTable.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        commentsTable.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
        commentsTable.register(CommentsControl.self, forHeaderFooterViewReuseIdentifier: "CommentsControl")
        commentsTable.register(LikerCell.self, forCellReuseIdentifier: "LikerCell")
        view.addSubview(commentsTable)
    }
        
    func addFooter() {
        
        /// footerView isn't a true footer but the input accessory view used to fix text to the keyboard
        
        footerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 112))
        footerView.autoresizingMask = .flexibleHeight
        footerView.backgroundColor = nil
        
        profilePic = UIImageView(frame: CGRect(x: 11, y: 11, width: 42, height: 41))
        let image = UserDataModel.shared.userInfo.avatarPic == UIImage() ? UserDataModel.shared.userInfo.profilePic : UserDataModel.shared.userInfo.avatarPic
        profilePic.image = image
        profilePic.contentMode = .scaleAspectFill
        profilePic.layer.cornerRadius = 14.5
        profilePic.clipsToBounds = true
        footerView.addSubview(profilePic)
        
        textView = UITextView(frame: CGRect(x: profilePic.frame.maxX + 10, y: 11, width: UIScreen.main.bounds.width - 77, height: 42))
        textView.backgroundColor = UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1)
        textView.font = UIFont(name: "SFCompactText-Semibold", size: 18)
        textView.textColor = UIColor(red: 0.462, green: 0.462, blue: 0.462, alpha: 1)
        textView.text = emptyTextString
        textView.alpha = 0.65
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 60)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.delegate = self
        textView.layer.cornerRadius = 11
        textView.inputAccessoryView = footerView
        
        postButton = UIButton(frame: CGRect(x: textView.bounds.maxX - 47, y: 2, width: 38, height: 38))
        postButton.setImage(UIImage(named: "PostCommentButton"), for: .normal)
        postButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        postButton.addTarget(self, action: #selector(postComment(_:)), for: .touchUpInside)
        postButton.isEnabled = false
        textView.addSubview(postButton)
        
        footerView.addSubview(textView)
    }
    
    func getLikers() {
        
        var ct = 0
        for id in post.likers {
            getUserInfo(userID: id) { user in
                self.likers.append(user)
                ct += 1; if ct == self.post.likers.count { self.reloadLikers()}
            }
        }
    }
    
    func reloadLikers() {
        if selectedIndex == 1 { DispatchQueue.main.async { self.commentsTable.reloadData() } }
    }
        
    @objc func notifyCommentLike(_ sender: NSNotification) {
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let comment = infoPass["comment"] as? MapComment else { return }
        if let i = commentList.firstIndex(where: {$0.id == comment.id}) {
            commentList[i] = comment
            DispatchQueue.main.async { self.commentsTable.reloadData() }
        }
    }
            
    @objc func tagSelect(_ sender: NSNotification) {
        
        guard let infoPass = sender.userInfo as? [String: Any] else { return }
        guard let username = infoPass["username"] as? String else { return }
        guard let tag = infoPass["tag"] as? Int else { return }
        if tag != 0 { return } /// tag 2 for upload tag. This notification should only come through if tag = 2 because upload will always be topmost VC

        let cursorPosition = textView.getCursorPosition()
        let text = textView.text ?? ""
     //   let tagText = addTaggedUserTo(text: text, username: username, cursorPosition: cursorPosition)
      //  textView.text = tagText
    }

    @objc func postComment(_ sender: UIButton) {

        guard var commentText = textView.text else { return }
        if commentText == emptyTextString { return }
        
        while commentText.last?.isNewline ?? false {
            commentText = String(commentText.dropLast())
        }
        
        let spaceCheck = commentText.replacingOccurrences(of: " ", with: "")
        if spaceCheck == "" { return }
        
        Mixpanel.mainInstance().track(event: "CommentsPost")
        postVC.mapVC.removeTable()
        
        let timestamp = NSDate().timeIntervalSince1970
        let date = Date()
        let firTimestamp = Firebase.Timestamp(date: date)
        
        let commentID = UUID().uuidString
        
        var taggedUsernames: [String] = []
        var selectedUsers: [UserProfile] = []
        
        ///for tagging users on comment post
        
        let words = commentText.components(separatedBy: .whitespacesAndNewlines)
        
        for w in words {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = UserDataModel.shared.friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append(f)
                }
            }
        }
        
        taggedUsernames = selectedUsers.map({$0.username})
        
        let temp = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 68, height: 15))
        temp.text = commentText
        temp.lineBreakMode = .byWordWrapping
        temp.numberOfLines = 0
        temp.font = UIFont(name: "SFCompactText-Regular", size: 12.5)
        temp.sizeToFit()
        
        let comment = MapComment(id: commentID, comment: commentText, commenterID: self.uid, taggedUsers: taggedUsernames, timestamp: firTimestamp, userInfo: UserDataModel.shared.userInfo, commentHeight: temp.frame.height, seconds: Int64(timestamp))
        commentList.append(comment)
        commentsTable.reloadData()
        updateParent()
        
        textView.text = ""
        textView.resignFirstResponder()
        commentsTable.removeGestureRecognizer(panGesture)
        
        resizeFooter(type: 2)
        let commenterIDList = commentList.map({$0.commenterID})
        let taggedUserIDs = selectedUsers.map({$0.id ?? ""})
        
        /// not using codable here due to extra values that are added for sending comment notification
        let values = ["addedUsers" : post.addedUsers ?? [],
                      "comment" : commentText,
                      "commenterID" : self.uid,
                      "commenterIDList" : commenterIDList,
                      "commenterUsername" : UserDataModel.shared.userInfo.username,
                      "imageURL" : post.imageURLs.first ?? "",
                      "posterID": post.posterID,
                      "posterUsername" : post.userInfo?.username ?? "",
                      "timestamp" : firTimestamp,
                      "taggedUsers" : taggedUsernames,
                      "taggedUserIDs": taggedUserIDs]  as [String : Any]
                
        DispatchQueue.global(qos: .userInitiated).async {
            self.db.collection("posts").document(self.post.id!).collection("comments").document(commentID).setData(values, merge: true)
        }
    }
    
    func updateParent() {
        post.commentList = self.commentList
        if let index = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
            postVC.postsList[index].commentList = self.commentList
            postVC.postsList[index] = setSecondaryPostValues(post: postVC.postsList[index])
        }
        
        postVC.postsCollection.reloadData()
        let infoPass = ["commentList": self.commentList, "postID": post.id!] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("PostComment"), object: nil, userInfo: infoPass)
    }
}

extension CommentsController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        return updatedText.count <= 560
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let trimText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.postButton.isEnabled = trimText != ""
        self.textView.alpha = trimText == "" ? 0.65 : 1.0
        
        resizeFooter(type: 2)
        
        ///add tag table if @ used
        let cursor = textView.getCursorPosition()
      //  postVC.addRemoveTagTable(text: textView.text ?? "", cursorPosition: cursor, tableParent: .comments)
    }
    
    func resizeFooter(type: Int) {
        
        let amountOfLinesToBeShown: CGFloat = 6
        let maxHeight: CGFloat = textView.font!.lineHeight * amountOfLinesToBeShown
        
        let size = textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: maxHeight))
        if size.height != textView.frame.size.height || type != 2 {
            let diff = size.height - textView.frame.height
            inputAccessoryView.invalidateIntrinsicContentSize()
            textView.frame = CGRect(x: textView.frame.minX, y: textView.frame.minY, width: textView.frame.width, height: textView.frame.height + diff)
            
            guard let constraint = inputAccessoryView.superview?.constraints.first(where: { $0.identifier == "accessoryHeight" }) else {
                return
            }
            
            constraint.isActive = false
            
            //0 = resize on initial edit, 1 = reset on close, other = resize on post
            let height = type == 0 ? 92 : type == 1 ? 112 : inputAccessoryView.frame.height + diff
            
            inputAccessoryView.frame = CGRect(x: inputAccessoryView.frame.minX, y: inputAccessoryView.frame.minY, width: inputAccessoryView.frame.width, height: height)
            
            constraint.constant = inputAccessoryView.bounds.height
            constraint.isActive = true
            inputAccessoryView.superview?.addConstraint(constraint)
            inputAccessoryView.superview?.superview?.layoutIfNeeded()
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        resignFirstResponder()
        commentsTable.addGestureRecognizer(panGesture)
        
        resizeFooter(type: 0)
            
        if textView.alpha < 0.7 {
            textView.text = nil
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        becomeFirstResponder()
        commentsTable.removeGestureRecognizer(panGesture)
                
        self.resizeFooter(type: 1)

        if textView.text.isEmpty {
            textView.alpha = 0.65
            textView.text = emptyTextString
        }
    }
    
    
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        
        let direction = sender.velocity(in: view)
        
        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            commentsTable.removeGestureRecognizer(panGesture)
        }
    }
}


extension CommentsController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selectedIndex == 0 ? commentList.count - 1 : likers.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return selectedIndex == 0 ? commentList[indexPath.row + 1].commentHeight + 35 : 46
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch selectedIndex {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
            cell.setUp(comment: commentList[indexPath.row + 1], post: post)
            return cell
            
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "LikerCell", for: indexPath) as! LikerCell
            cell.setUp(friend: likers[indexPath.row])
            return cell
            
        default: return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return commentList[indexPath.row + 1].commenterID == self.uid ? .delete : .none
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        // swipe to delete comment
        if (editingStyle == .delete) {
            Mixpanel.mainInstance().track(event: "CommentsDelete")
            
            let commentID = commentList[indexPath.row + 1].id!
            let postID = post.id!
            
            let postsRef = self.db.collection("posts").document(postID).collection("comments").document(commentID)
                    postsRef.delete()
                
            commentList.remove(at: indexPath.row + 1)
            
            let path2 = IndexPath(row: indexPath.row, section: 0)
            
            tableView.performBatchUpdates {
                tableView.deleteRows(at: [path2], with: .fade)
            } completion: { _ in
                tableView.reloadData()
            }
            
            updateParent()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "CommentsControl") as? CommentsControl {
            header.setUp(post: post, selectedIndex: selectedIndex)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    ///https://stackoverflow.com/questions/37942812/turn-some-parts-of-uilabel-to-act-like-a-uibutton
    
}

class CommentCell: UITableViewCell {
    
    var comment: MapComment!
    var post: MapPost!
    
    var profilePic: UIImageView!
    var username: UILabel!
    var commentText: UILabel!
    var likeButton: UIButton!
    var numLikes: UILabel!
    
    var tagRect: [(rect: CGRect, username: String)] = []
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"

    func setUp(comment: MapComment, post: MapPost) {
        
        self.selectionStyle = .none
        self.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)

        
        self.comment = comment
        self.post = post
        self.tag = 30
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 8, y: 15, width: 32, height: 32))
        profilePic.contentMode = .scaleAspectFill
        profilePic.layer.cornerRadius = 16
        profilePic.clipsToBounds = true
        contentView.addSubview(profilePic)

        let avatar = (comment.userInfo?.avatarURL ?? "") != ""
        let url = avatar ? comment.userInfo!.avatarURL! : comment.userInfo?.imageURL ?? ""
        if avatar { profilePic.frame = CGRect(x: 8, y: 8, width: 32.4, height: 42); profilePic.layer.cornerRadius = 0 }
        
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 14, width: UIScreen.main.bounds.width - 108, height: 16))
        username.text = comment.userInfo?.username ?? ""
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        username.sizeToFit()
        contentView.addSubview(username)
        
        let userButton = UIButton(frame: CGRect(x: 10, y: 0, width: 50 + username.bounds.width, height: 40))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
   //     self.addSubview(userButton)
        
        commentText = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: username.frame.maxY + 3, width: UIScreen.main.bounds.width - 94, height: comment.commentHeight))
        commentText.text = comment.comment
        commentText.lineBreakMode = .byWordWrapping
        commentText.numberOfLines = 0
        commentText.textColor = UIColor(red: 0.629, green: 0.629, blue: 0.629, alpha: 1)
        commentText.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        
        if !(comment.taggedUsers?.isEmpty ?? true) {
            let attString = self.getAttString(caption: comment.comment, taggedFriends: comment.taggedUsers!, fontSize: 12.5)
             commentText.attributedText = attString.0
             tagRect = attString.1
             
             let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:)))
             commentText.isUserInteractionEnabled = true
             commentText.addGestureRecognizer(tap)
         }
        contentView.addSubview(commentText)
        
        let commentButton = UIButton(frame: CGRect(x: commentText.frame.minX, y: commentText.frame.minY, width: commentText.frame.width, height: commentText.frame.height))
        commentButton.addTarget(self, action: #selector(commentTap(_:)), for: .touchUpInside)
        contentView.addSubview(commentButton)
        
        let likesEmpty = comment.likers?.isEmpty ?? true
        let liked = comment.likers?.contains(where: {$0 == uid}) ?? false
        let image = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")?.withTintColor(UIColor(red: 0.342, green: 0.342, blue: 0.342, alpha: 1))
    
        likeButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 43, y: 7, width: 36.6, height: 35))
        likeButton.setImage(image, for: .normal)
        likeButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        likeButton.contentHorizontalAlignment = .center
        likeButton.contentVerticalAlignment = .center
        liked ? likeButton.addTarget(self, action: #selector(unlikeTap(_:)), for: .touchUpInside) : likeButton.addTarget(self, action: #selector(likeTap(_:)), for: .touchUpInside)
        contentView.addSubview(likeButton)
        
        if !likesEmpty {
            numLikes = UILabel(frame: CGRect(x: likeButton.frame.minX, y: likeButton.frame.maxY - 5, width: likeButton.frame.width, height: 12))
            numLikes.text = "\(comment.likers?.count ?? 0)"
            numLikes.textColor = UIColor(red: 0.342, green: 0.342, blue: 0.342, alpha: 1)
            numLikes.font = UIFont(name: "SFCompactText-Semibold", size: 11)
            numLikes.textAlignment = .center
            contentView.addSubview(numLikes)
        }
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
        if commentText != nil { commentText.text = "" }
        if likeButton != nil { likeButton.setImage(UIImage() , for: .normal) }
        if numLikes != nil { numLikes.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    @objc func commentTap(_ sender: UIButton) {
        
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
        var likers = comment.likers == nil ? [] : comment.likers
        likers!.append(uid)
        comment.likers = likers
        let infoPass = ["comment": self.comment as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("CommentLike"), object: nil, userInfo: infoPass)
        
        DispatchQueue.global().async {
            let db = Firestore.firestore()
            db.collection("posts").document(self.post.id!).collection("comments").document(self.comment.id!).updateData(["likers" : FieldValue.arrayUnion([self.uid])])
            
            let functions = Functions.functions()
            functions.httpsCallable("likeComment").call(["commentID": self.comment.id!, "commenterID": self.comment.commenterID, "imageURL": self.post.imageURLs.first ?? "", "likerID": self.uid, "likerUsername": UserDataModel.shared.userInfo.username, "postID": self.post.id!, "spotID": self.post.spotID ?? "", "posterID": self.post.posterID]) { result, error in
                print(result?.data as Any, error as Any)
            }
        }
    }
    
    @objc func unlikeTap(_ sender: UIButton) {
        var likers = comment.likers == nil ? [] : comment.likers
        likers!.removeAll(where: {$0 == uid})
        comment.likers = likers
        let infoPass = ["comment": self.comment as Any] as [String : Any]
        NotificationCenter.default.post(name: Notification.Name("CommentLike"), object: nil, userInfo: infoPass)
        
        DispatchQueue.global().async {
            let db = Firestore.firestore()
            db.collection("posts").document(self.post.id!).collection("comments").document(self.comment.id!).updateData(["likers" : FieldValue.arrayRemove([self.uid])])
        }
    }
    
    @objc func usernameTap(_ sender: UIButton) {
        guard let user = comment.userInfo else { return }
        openProfile(user: user)
    }
    
    @objc func tappedLabel(_ sender: UITapGestureRecognizer) {
        // tag tap
        for r in tagRect {
            if r.rect.contains(sender.location(in: sender.view)) {
                /// open tag from friends list
                if let friend = UserDataModel.shared.friendsList.first(where: {$0.username == r.username}) {
                    openProfile(user: friend)
                } else {
                    /// pass blank user object to open func, run get user func on profile load
                    var user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                    user.id = ""
                    self.openProfile(user: user)
                }
            }
        }
    }
    
    func openProfile(user: UserProfile) {
      /*  if let commentsVC = self.viewContainingController() as? CommentsController {
            
            if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
                
                if user.id != "" {
                    vc.userInfo = user /// already have user info
                } else {
                    vc.passedUsername = user.username /// run username query from tapped tag on profile open
                }
                
                vc.id = user.id ?? ""
                vc.commentsSelectedPost = commentsVC.post
                vc.postCaptionHeight = commentsVC.captionHeight
                vc.mapVC = commentsVC.postVC.mapVC
                
                commentsVC.postVC.cancelDownloads()
                if let feedVC = commentsVC.postVC.parent as? FeedViewController { feedVC.hideFeedSeg() }
                
                vc.view.frame = commentsVC.postVC.view.frame
                commentsVC.postVC.addChild(vc)
                commentsVC.postVC.view.addSubview(vc.view)
                vc.didMove(toParent: commentsVC.postVC)
                                
                commentsVC.dismiss(animated: false, completion: nil)
            }
        } */
    }
}

class CommentsControl: UITableViewHeaderFooterView {
    
    var selectedIndex = 0
    var buttonBar: UIView!
    var commentSeg: UIButton!
    var likeSeg: UIButton!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        isUserInteractionEnabled = true
        backgroundColor = nil
    }
    
    func setUp(post: MapPost, selectedIndex: Int) {
        
        let segWidth: CGFloat = 131
        self.selectedIndex = selectedIndex
                
        if commentSeg != nil { commentSeg.setTitle("", for: .normal) }
        commentSeg = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 - segWidth - 10, y: 0, width: segWidth, height: 25))
        commentSeg.titleEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 5)
        
        var commentText = "\(max(post.commentList.count - 1, 0)) comment"
        if post.commentList.count - 1 != 1 { commentText += "s" }
        commentSeg.setTitle(commentText, for: .normal)
        commentSeg.setTitleColor(.black, for: .normal)
        commentSeg.titleLabel?.alpha = selectedIndex == 0 ? 1.0 : 0.6
        
        let font0 = selectedIndex == 0 ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        commentSeg.titleLabel?.font = font0
        commentSeg.contentHorizontalAlignment = .center
        commentSeg.contentVerticalAlignment = .center
        commentSeg.addTarget(self, action: #selector(commentSegTap(_:)), for: .touchUpInside)
        addSubview(commentSeg)
        
        if likeSeg != nil { likeSeg.setTitle("", for: .normal) }
        likeSeg = UIButton(frame: CGRect(x: UIScreen.main.bounds.width/2 + 10, y: 0, width: segWidth, height: 25))
        likeSeg.titleEdgeInsets = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 5)
        var likeText = "\(max(post.likers.count, 0)) like"
        if post.likers.count != 1 { likeText += "s" }
        likeSeg.setTitle(likeText, for: .normal)
        likeSeg.setTitleColor(.black, for: .normal)
        likeSeg.titleLabel?.alpha = selectedIndex == 1 ? 1.0 : 0.6
        
        let font1 = selectedIndex == 1 ? UIFont(name: "SFCompactText-Bold", size: 16) : UIFont(name: "SFCompactText-Semibold", size: 16)
        likeSeg.titleLabel?.font = font1
        likeSeg.contentHorizontalAlignment = .center
        likeSeg.contentVerticalAlignment = .center
        likeSeg.addTarget(self, action: #selector(likeSegTap(_:)), for: .touchUpInside)
        addSubview(likeSeg)

        let minX = selectedIndex == 0 ? UIScreen.main.bounds.width/2 - segWidth + 5 : UIScreen.main.bounds.width/2 + 25
        if buttonBar != nil { buttonBar.backgroundColor = nil }
        buttonBar = UIView(frame: CGRect(x: minX, y: 27.5, width: segWidth - 30, height: 3))
        buttonBar.backgroundColor = .black
        addSubview(buttonBar)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc func commentSegTap(_ sender: UIButton) {
        if selectedIndex == 1 {
            switchToCommentSeg()
        } else {
            /// scroll comments to top
        }
    }
        
    @objc func likeSegTap(_ sender: UIButton) {
        if selectedIndex == 0 {
            switchToLikeSeg()
        } else {
            ///scroll likers to top
        }
    }
    
    func switchToLikeSeg() {
        
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 1
        commentsVC.commentsTable.reloadData()
        animateSegmentSwitch()
    }

    func switchToCommentSeg() {
        
        guard let commentsVC = viewContainingController() as? CommentsController else { return }
        commentsVC.selectedIndex = 0
        commentsVC.commentsTable.reloadData()
        animateSegmentSwitch()
    }
    
    func animateSegmentSwitch() {
        let segWidth: CGFloat = 131
        let minX = selectedIndex == 0 ? UIScreen.main.bounds.width/2 - segWidth + 5 : UIScreen.main.bounds.width/2 + 25
        self.buttonBar.frame = CGRect(x: minX, y: self.buttonBar.frame.minY, width: self.buttonBar.frame.width, height: self.buttonBar.frame.height)
        self.commentSeg.titleLabel?.alpha = self.selectedIndex == 0 ? 1.0 : 0.6
        self.likeSeg.titleLabel?.alpha = self.selectedIndex == 1 ? 1.0 : 0.6
    }
}

class LikerCell: UITableViewCell {
    
    var profilePic: UIImageView!
    var username: UILabel!
    
    func setUp(friend: UserProfile) {
        
        self.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        
        resetCell()
        
        profilePic = UIImageView(frame: CGRect(x: 8, y: 13, width: 32, height: 32))
        profilePic.layer.cornerRadius = 16
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        addSubview(profilePic)

        let avatar = (friend.avatarURL ?? "") != ""
        let url = avatar ? friend.avatarURL! : friend.imageURL
        if avatar { profilePic.frame = CGRect(x: 8, y: 6, width: 32.4, height: 42); profilePic.layer.cornerRadius = 0 }
        
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }
                        
        username = UILabel(frame: CGRect(x: profilePic.frame.maxX + 8, y: 20.5, width: 150, height: 15))
        username.text = friend.username
        username.textColor = .black
        username.font = UIFont(name: "SFCompactText-Bold", size: 13.5)
        addSubview(username)
    }
    
    func resetCell() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        /// cancel image fetch when cell leaves screen
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
}
