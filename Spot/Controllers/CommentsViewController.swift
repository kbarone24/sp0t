//
//  CommentsViewController.swift
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

class CommentsViewController: UIViewController {
    
    // var friendsList: [UserProfile] = []
    weak var postVC: PostViewController!
    var post: MapPost!
    var captionHeight: CGFloat = 0
    var commentList: [MapComment] = []
    var userInfo: UserProfile!
    var tableView: UITableView!
    
    let uid: String = Auth.auth().currentUser?.uid ?? "invalid user"
    let db: Firestore! = Firestore.firestore()
    var listener1: ListenerRegistration!
    
    var footerView: UIView!
    var profileImage: UIImageView!
    var textView: UITextView!
    var postButton: UIButton!
    
    var panGesture: UIPanGestureRecognizer!
    
    override var canBecomeFirstResponder: Bool { return true }
    override var canResignFirstResponder: Bool { return true }
    
    var downloads: [StorageDownloadTask] = []
    var active = true
    
    override var inputAccessoryView: UIView {
        if footerView == nil {
            addFooter()
        }
        return footerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(tagSelect(_:)), name: NSNotification.Name("TagSelect"), object: nil)
        if userInfo == nil { userInfo = postVC.mapVC.userInfo }
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        
        addTable()
        DispatchQueue.global().async { self.getCommenterInfo() }
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
        
        IQKeyboardManager.shared.enable = true
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TagSelect"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = false
        Mixpanel.mainInstance().track(event: "CommentsOpen")
    }
    
    func addTable() {
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = UIColor(named: "SpotBlack")
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        tableView.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
        tableView.register(CommentHeader.self, forHeaderFooterViewReuseIdentifier: "CommentHeader")
        view.addSubview(tableView)
    }
    
    @objc func tagSelect(_ sender: NSNotification) {
        if let username = sender.userInfo?.first?.value as? String {
            if let word = textView.text?.split(separator: " ").last {
                if word.hasPrefix("@") {
                    var text = String(textView.text.dropLast(word.count - 1))
                    text.append(contentsOf: username)
                    self.textView.text = text
                }
            }
        }
    }
    
    func addFooter() {
        
        /// footerView isn't a true footer but the input accessory view used to fix text to the keyboard
        
        footerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 90))
        footerView.autoresizingMask = .flexibleHeight
        footerView.backgroundColor = UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1)
        
        profileImage = UIImageView(frame: CGRect(x: 14, y: 14, width: 32, height: 32))
        profileImage.image = userInfo.profilePic
        profileImage.contentMode = .scaleAspectFill
        profileImage.layer.cornerRadius = 16
        profileImage.clipsToBounds = true
        footerView.addSubview(profileImage)
        
        textView = UITextView(frame: CGRect(x: 54, y: 15, width: UIScreen.main.bounds.width - 68, height: 32))
        textView.backgroundColor = nil
        textView.font = UIFont(name: "SFCamera-Regular", size: 13)
        textView.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        textView.text = "Comment..."
        textView.alpha = 0.65
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 60)
        textView.isScrollEnabled = false
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingHead
        textView.delegate = self
        textView.inputAccessoryView = footerView
        
        postButton = UIButton(frame: CGRect(x: textView.bounds.maxX - 55, y: 2, width: 55, height: 28))
        postButton.setTitle("Post", for: .normal)
        postButton.setTitleColor(UIColor(named: "SpotGreen"), for: .normal)
        postButton.contentHorizontalAlignment = .center
        postButton.contentVerticalAlignment = .center
        postButton.titleEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        postButton.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 13)
        postButton.addTarget(self, action: #selector(postComment(_:)), for: .touchUpInside)
        postButton.isEnabled = false
        textView.addSubview(postButton)
        
        footerView.addSubview(textView)
    }
    
    func getCommenterInfo() {
        
        var index = 0
        func commentEscape() {
            index += 1
            if index >= commentList.count - 1 {
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
        
        /// we don't show the first comment because it's the caption so don't need to fetch anything additional
        if commentList.count < 2 {
            commentEscape()
            return
        }
        
        for i in 1...commentList.count - 1 {
            var comment = commentList[i]
            self.db.collection("users").document(comment.commenterID).getDocument { [weak self] (snap, err) in
                guard let self = self else { return }
                
                do {
                    
                    let userProf = try snap?.data(as: UserProfile.self)
                    guard var userProfile = userProf else { commentEscape(); return }
                    
                    userProfile.id = snap!.documentID
                    
                    if let url = URL(string: userProfile.imageURL) {
                        SDWebImagePrefetcher.shared.prefetchURLs([url], progress: nil) }
                    
                    comment.userInfo = userProfile
                    self.commentList[i] = comment
                    self.post.commentList = self.commentList
                    commentEscape()
                    
                } catch { commentEscape() }
            }
        }
    }
    
    @objc func postComment(_ sender: UIButton) {

        guard var commentText = textView.text else { return }
        if commentText == "Comment..." { return }
        
        while commentText.last?.isNewline ?? false {
            commentText = String(commentText.dropLast())
        }
        
        let spaceCheck = commentText.replacingOccurrences(of: " ", with: "")
        if spaceCheck == "" { return }
        
        Mixpanel.mainInstance().track(event: "CommentsPost")
        postVC.mapVC.removeTable()
        
        let timestamp = NSDate().timeIntervalSince1970
        let date = Date(timeIntervalSince1970: timestamp)
        let firTimestamp = Firebase.Timestamp(date: date)
        
        let commentID = UUID().uuidString
        
        var taggedUsernames: [String] = []
        var selectedUsers: [UserProfile] = []
        
        ///for tagging users on comment post
        let word = commentText.split(separator: " ")
        
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") {
                if let f = postVC.mapVC.friendsList.first(where: {$0.username == username}) {
                    selectedUsers.append(f)
                }
            }
        }
        
        taggedUsernames = selectedUsers.map({$0.username})
        
        let temp = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 68, height: 15))
        temp.text = commentText
        temp.lineBreakMode = .byWordWrapping
        temp.numberOfLines = 0
        temp.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        temp.sizeToFit()
        
        let comment = MapComment(id: commentID, comment: commentText, commenterID: self.uid, timestamp: firTimestamp, userInfo: userInfo, taggedUsers: taggedUsernames, commentHeight: temp.frame.height, seconds: Int64(timestamp))
        commentList.append(comment)
        tableView.reloadData()
        updateParent()
        
        textView.text = ""
        textView.resignFirstResponder()
        tableView.removeGestureRecognizer(panGesture)
        
        resizeFooter(type: 2)
        
        let values = ["comment" : commentText,
                      "commenterID" : self.uid,
                      "timestamp" : firTimestamp,
                      "taggedUsers": taggedUsernames] as [String : Any]
                
        DispatchQueue.global(qos: .userInitiated).async {
            self.db.collection("posts").document(self.post.id!).collection("comments").document(commentID).setData(values, merge: true)
            self.incrementSpotScore(user: self.post.posterID, increment: 1)
        }
        
        // send comment notification to the original poster first
        var dontSendList: [String] = [self.uid]
        
        if self.uid != self.post.posterID {
            dontSendList.append(self.post.posterID)
            
            let notiID = UUID().uuidString
            let notificationRef = self.db.collection("users").document(self.post.posterID).collection("notifications")
            
            let acceptRef = notificationRef.document(notiID)
            
            let notiValues = ["seen" : false, "timestamp" : firTimestamp, "senderID": self.uid, "type": "comment", "spotID": self.post.spotID!, "postID": self.post.id!, "imageURL": self.post.imageURLs.first ?? "" as Any] as [String : Any]
            
            acceptRef.setData(notiValues)
            
            let sender = PushNotificationSender()
            var token: String!
            
            self.db.collection("users").document(self.post.posterID).getDocument { (tokenSnap, err) in
                if (tokenSnap == nil) {
                    return
                } else {
                    token = tokenSnap?.get("notificationToken") as? String
                    if (token != nil && token != "") {
                        sender.sendPushNotification(token: token, title: "", body: "\(self.userInfo.username) commented on your post")
                    }
                }
            }
        }
        
        // send notifications to tagged users
        if !selectedUsers.isEmpty {
            let values = ["seen" : false, "timestamp" : firTimestamp, "senderID": self.uid, "type": "commentTag", "spotID": post.spotID ?? "", "postID": post.id!, "imageURL": self.post.imageURLs.first ?? "" as Any] as [String : Any]
            
            for user in selectedUsers {
                if dontSendList.contains(user.id!) { continue }
                dontSendList.append(user.id!)
                let nID = UUID().uuidString
                let notiRef = self.db.collection("users").document(user.id!).collection("notifications").document(nID)
                notiRef.setData(values)
                
                let sender = PushNotificationSender()
                var token: String!
                
                db.collection("users").document(user.id!).getDocument { (tokenSnap, err) in
                    if (tokenSnap == nil) {
                        return
                    } else {
                        token = tokenSnap?.get("notificationToken") as? String
                    }
                    if (token != nil && token != "") {
                        sender.sendPushNotification(token: token, title: "", body: "\(self.postVC.mapVC.userInfo.username) tagged you in a comment")
                    }
                }
            }
        }
        
        // send notifications to other commenters
        if commentList.count > 2 {
            
            for comment in commentList {
                if (!dontSendList.contains(comment.commenterID)) {
                    dontSendList.append(comment.commenterID)
                    let nID = UUID().uuidString
                    let notiRef = self.db.collection("users").document(comment.commenterID).collection("notifications").document(nID)
                    
                    let sender = PushNotificationSender()
                    var token: String!
                    
                    self.db.collection("users").document(comment.commenterID).getDocument { [weak self] (tokenSnap, err) in
                        
                        guard let self = self else { return }
                        
                        if (tokenSnap == nil) {
                            return
                        } else {
                            token = tokenSnap?.get("notificationToken") as? String
                        }
                        
                        guard let posterInfo = self.post.userInfo else { return }
                        let username = posterInfo.username
                        
                        sender.sendPushNotification(token: token, title: "", body: "\(self.userInfo.username) also commented on \(username)'s post")
                        let values = ["seen" : false, "timestamp" : firTimestamp, "senderID": self.uid, "type": "commentComment", "spotID": self.post.spotID!, "postID": self.post.id!, "imageURL": self.post.imageURLs.first ?? "" as Any, "originalPoster": username] as [String : Any]
                        notiRef.setData(values)
                    }
                }
            }
        }
    }
    
    func updateParent() {
        post.commentList = self.commentList
        if let index = postVC.postsList.firstIndex(where: {$0.id == post.id}) {
            postVC.postsList[index].commentList = self.commentList
        }
        postVC.tableView.reloadData()
    }
}

extension CommentsViewController: UITextViewDelegate {
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
        if textView.text.last != " " {
            if let word = textView.text?.split(separator: " ").last {
                if word.hasPrefix("@") {
                    self.postVC.mapVC.addTable(text: String(word.lowercased().dropFirst()), parent: .comments)
                    return
                }
            }
        }
        
        postVC.mapVC.removeTable()
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
            let height = type == 0 ? 70 : type == 1 ? 90 : inputAccessoryView.frame.height + diff
            
            inputAccessoryView.frame = CGRect(x: inputAccessoryView.frame.minX, y: inputAccessoryView.frame.minY, width: inputAccessoryView.frame.width, height: height)
            
            constraint.constant = inputAccessoryView.bounds.height
            constraint.isActive = true
            inputAccessoryView.superview?.addConstraint(constraint)
            inputAccessoryView.superview?.superview?.layoutIfNeeded()
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        resignFirstResponder()
        tableView.addGestureRecognizer(panGesture)
        
        resizeFooter(type: 0)
            
        if textView.alpha < 0.7 {
            textView.text = nil
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        becomeFirstResponder()
        tableView.removeGestureRecognizer(panGesture)
                
        resizeFooter(type: 1)
        
        if textView.text.isEmpty {
            textView.alpha = 0.65
            textView.text = "Comment..."
        }
    }
    
    
    
    @objc func pan(_ sender: UIPanGestureRecognizer) {
        if !self.textView.isFirstResponder { return }
        
        let direction = sender.velocity(in: view)
        
        if abs(direction.y) > 100 {
            textView.resignFirstResponder()
            tableView.removeGestureRecognizer(panGesture)
        }
    }
}


extension CommentsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commentList.count - 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return commentList[indexPath.row + 1].commentHeight + 30
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
        cell.setUp(comment: commentList[indexPath.row + 1])
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "CommentHeader") as? CommentHeader {
            header.setUp(post: post)
            return header
        } else { return UITableViewHeaderFooterView() }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return captionHeight + 58
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
            let posterID = post.posterID
            
            DispatchQueue.global(qos: .default).async {
                self.postVC.incrementSpotScore(user: posterID, increment: -1)
                let postsRef = self.db.collection("posts").document(postID).collection("comments").document(commentID)
                    postsRef.delete()
            }
                
            commentList.remove(at: indexPath.row + 1)
            
            let path2 = IndexPath(row: indexPath.row, section: 0)
            tableView.deleteRows(at: [path2], with: .fade)
            
            updateParent()
        }
    }
    
    ///https://stackoverflow.com/questions/37942812/turn-some-parts-of-uilabel-to-act-like-a-uibutton
    
}

class CommentCell: UITableViewCell {
    
    var comment: MapComment!
    var profileImage: UIImageView!
    var username: UIButton!
    var commentText: UILabel!
    var tagRect: [(rect: CGRect, username: String)] = []
    
    func setUp(comment: MapComment) {
        
        self.selectionStyle = .none
        self.backgroundColor = UIColor(named: "SpotBlack")
        self.comment = comment
        self.tag = 30
        
        resetCell()
        
        profileImage = UIImageView(frame: CGRect(x: 14, y: 6, width: 32, height: 32))
        profileImage.contentMode = .scaleAspectFill
        profileImage.layer.cornerRadius = 16
        profileImage.clipsToBounds = true
        self.addSubview(profileImage)

        let url = comment.userInfo?.imageURL ?? ""
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profileImage.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UIButton(frame: CGRect(x: 54, y: 1, width: UIScreen.main.bounds.width - 108, height: 14))
        username.setTitle(comment.userInfo?.username ?? "", for: .normal)
        username.setTitleColor(UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1), for: .normal)
        username.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12)
        username.sizeToFit()
        username.contentHorizontalAlignment = .left
        self.addSubview(username)
        
        let userButton = UIButton(frame: CGRect(x: 10, y: 0, width: 50 + username.bounds.width, height: 40))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(usernameTap(_:)), for: .touchUpInside)
        self.addSubview(userButton)
        
        commentText = UILabel(frame: CGRect(x: 54, y: 23, width: UIScreen.main.bounds.width - 68, height: comment.commentHeight))
        commentText.text = comment.comment
        commentText.lineBreakMode = .byWordWrapping
        commentText.numberOfLines = 0
        commentText.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        commentText.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        
        if !(comment.taggedUsers?.isEmpty ?? true) {
             let attString = self.getAttString(caption: comment.comment, taggedFriends: comment.taggedUsers!)
             commentText.attributedText = attString.0
             tagRect = attString.1
             
             let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:)))
             commentText.isUserInteractionEnabled = true
             commentText.addGestureRecognizer(tap)
         }
        
        commentText.sizeToFit()
        self.addSubview(commentText)
    }
    
    func resetCell() {
        if profileImage != nil { profileImage.image = UIImage() }
        if username != nil { username.setTitle("", for: .normal) }
        if commentText != nil { commentText.text = "" }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profileImage != nil { profileImage.sd_cancelCurrentImageLoad() }
    }
    
    @objc func usernameTap(_ sender: UIButton) {
        guard let user = comment.userInfo else { return }
        openProfile(user: user)
    }
    
    @objc func tappedLabel(_ sender: UITapGestureRecognizer) {
        // tag tap
        if let commentsVC = self.viewContainingController() as? CommentsViewController {
            for r in tagRect {
                if r.rect.contains(sender.location(in: sender.view)) {
                    /// open tag from friends list
                    if let friend = commentsVC.postVC.mapVC.friendsList.first(where: {$0.username == r.username}) {
                        openProfile(user: friend)
                    } else {
                        /// pass blank user object to open func, run get user func on profile load
                        var user = UserProfile(username: r.username, name: "", imageURL: "", currentLocation: "")
                        user.id = ""
                        self.openProfile(user: user)
                    }
                }
            }
        }
    }
    
    func openProfile(user: UserProfile) {
        if let commentsVC = self.viewContainingController() as? CommentsViewController {
            
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
                
                vc.view.frame = commentsVC.postVC.view.frame
                commentsVC.postVC.addChild(vc)
                commentsVC.postVC.view.addSubview(vc.view)
                vc.didMove(toParent: commentsVC.postVC)
                
                commentsVC.postVC.mapVC.customTabBar.tabBar.isHidden = true
                commentsVC.dismiss(animated: false, completion: nil)
            }
        }
    }
}

class CommentHeader: UITableViewHeaderFooterView {

    var profilePic: UIImageView!
    var username: UIButton!
    var userButton: UIButton!
    var timestamp: UILabel!
    var exitButton: UIButton!
    var postCaption: UILabel!
    var bottomLine: UIView!
    
    var post: MapPost!
    
    lazy var tagRect: [(rect: CGRect, username: String)] = []
    
    func setUp(post: MapPost) {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor(named: "SpotBlack")
        self.backgroundView = backgroundView
        self.post = post
        
        resetView()
        
        profilePic = UIImageView(frame: CGRect(x: 17, y: 12.5, width: 24, height: 24))
        profilePic.layer.cornerRadius = 12
        profilePic.clipsToBounds = true
        self.addSubview(profilePic)

        let url = post.userInfo?.imageURL ?? ""
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
            profilePic.sd_setImage(with: URL(string: url), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer])
        }

        username = UIButton(frame: CGRect(x: 47, y: 12, width: 200, height: 16))
        username.setTitle(post.userInfo.username, for: .normal)
        username.setTitleColor(UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1), for: .normal)
        username.titleLabel?.font = UIFont(name: "SFCamera-Semibold", size: 12)
        username.sizeToFit()
        username.contentHorizontalAlignment = .left
        self.addSubview(username)
        
        userButton = UIButton(frame: CGRect(x: 0, y: 8, width: username.frame.maxX + 10, height: 45))
        userButton.backgroundColor = nil
        userButton.addTarget(self, action: #selector(userTap(_:)), for: .touchUpInside)
        self.addSubview(userButton)
        
        timestamp = UILabel(frame: CGRect(x: username.frame.maxX + 8, y: 18.5, width: 150, height: 16))
        timestamp.font = UIFont(name: "SFCamera-Regular", size: 12)
        timestamp.textColor = UIColor(red: 0.706, green: 0.706, blue: 0.706, alpha: 1)
        timestamp.text = getTimestamp(postTime: post.timestamp)
        timestamp.sizeToFit()
        self.addSubview(timestamp)
        
        postCaption = UILabel(frame: CGRect(x: 16, y: 42, width: UIScreen.main.bounds.width - 32, height: 15))
        postCaption.text = post.caption
        postCaption.textColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1)
        postCaption.font = UIFont(name: "SFCamera-Regular", size: 12.5)
        postCaption.numberOfLines = 0
        postCaption.lineBreakMode = .byWordWrapping
        self.addSubview(postCaption)
        
        if !(post.taggedUsers?.isEmpty ?? true) {
            let attString = self.getAttString(caption: post.caption, taggedFriends: post.taggedUsers!)
            postCaption.attributedText = attString.0
            tagRect = attString.1
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:)))
            postCaption.isUserInteractionEnabled = true
            postCaption.addGestureRecognizer(tap)
        }
        
        postCaption.sizeToFit()
        
        exitButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - 42, y: 7, width: 38, height: 32))
        exitButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        exitButton.setImage(UIImage(named: "CancelButton"), for: .normal)
        exitButton.addTarget(self, action: #selector(exitComments(_:)), for: .touchUpInside)
        self.addSubview(exitButton)
        
        bottomLine = UIView(frame: CGRect(x: 16, y: self.bounds.height - 5, width: UIScreen.main.bounds.width - 32, height: 1.5))
        bottomLine.backgroundColor = UIColor(red: 0.162, green: 0.162, blue: 0.162, alpha: 1)
        self.addSubview(bottomLine)

    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func resetView() {
        if profilePic != nil { profilePic.image = UIImage() }
        if username != nil { username.setTitle("", for: .normal) }
        if timestamp != nil { timestamp.text = "" }
        if postCaption != nil { postCaption.text = "" }
        if exitButton != nil { exitButton.setImage(UIImage(), for: .normal) }
        if bottomLine != nil { bottomLine.backgroundColor = nil }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if profilePic != nil { profilePic.sd_cancelCurrentImageLoad() }
    }
    
    @objc func tappedLabel(_ sender: UIGestureRecognizer) {
        if let commentsVC = self.viewContainingController() as? CommentsViewController {
            for r in tagRect {
                if r.rect.contains(sender.location(in: sender.view)) {
                    // open tag from friends list
                    if let friend = commentsVC.postVC.mapVC.friendsList.first(where: {$0.username == r.username}) {
                        openProfile(user: friend)
                    } else {
                        /// pass blank user object to open func, run get user func on profile load
                        var user = UserProfile(username: r.username, name: "", imageURL: "", currentLocation: "")
                        user.id = ""
                        self.openProfile(user: user)
                    }
                }
            }
        }
    }
    
    @objc func exitComments(_ sender: UIButton) {
        if let commentsVC = self.viewContainingController() as? CommentsViewController { commentsVC.dismiss(animated: true, completion: nil) }
    }
    
    @objc func userTap(_ sender: UIButton) {
        guard let user = self.post.userInfo else { return }
        openProfile(user: user)
    }
    
    func openProfile(user: UserProfile) {
        if let commentsVC = self.viewContainingController() as? CommentsViewController {
            if let vc = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Profile") as? ProfileViewController {
                vc.userInfo = user
                vc.id = user.id!
                vc.commentsSelectedPost = self.post /// open comments on this row on return from profile 
                vc.postCaptionHeight = commentsVC.captionHeight
                vc.mapVC = commentsVC.postVC.mapVC
                
                vc.view.frame = commentsVC.postVC.view.frame
                commentsVC.postVC.addChild(vc)
                commentsVC.postVC.view.addSubview(vc.view)
                vc.didMove(toParent: commentsVC.postVC)
                
                commentsVC.postVC.mapVC.customTabBar.tabBar.isHidden = true
                commentsVC.dismiss(animated: false, completion: nil)
            }
        }
    }
    
    func getTimestamp(postTime: Firebase.Timestamp) -> String {
        let seconds = postTime.seconds
        let current = NSDate().timeIntervalSince1970
        let currentTime = Int64(current)
        let timeSincePost = currentTime - seconds
        
        if timeSincePost < 604800 {
            // return time since post
            
            if (timeSincePost <= 86400) {
                if (timeSincePost <= 3600) {
                    if (timeSincePost <= 60) {
                        return "\(timeSincePost)s"
                    } else {
                        let minutes = timeSincePost / 60
                        return "\(minutes)m"
                    }
                } else {
                    let hours = timeSincePost / 3600
                    return "\(hours)h"
                }
            } else {
                let days = timeSincePost / 86400
                return "\(days)d"
            }
        } else {
            // return date
            let timeInterval = TimeInterval(integerLiteral: seconds)
            let date = Date(timeIntervalSince1970: timeInterval)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/dd/yy"
            let dateString = dateFormatter.string(from: date)
            return dateString
        }
    }
    
    func getAttString(caption: String, taggedFriends: [String]) -> ((NSMutableAttributedString, [(rect: CGRect, username: String)])) {
        let attString = NSMutableAttributedString(string: caption)
        var freshRect: [(rect: CGRect, username: String)] = []
        
        var tags: [(username: String, range: NSRange)] = []
        
        let word = caption.split(separator: " ")
        var index = 0
        for w in word {
            let username = String(w.dropFirst())
            if w.hasPrefix("@") && taggedFriends.contains(where: {$0 == username}) {
                let tag = (username: String(w.dropFirst()), range: NSMakeRange(index + 1, w.count - 1))
                if !tags.contains(where: {$0 == tag}) {
                    tags.append(tag)
                    let range = NSMakeRange(index, w.count)
                    attString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "SFCamera-Semibold", size: 12.5) as Any, range: range)
                }
            }
            index = index + w.count + 1
        }
        
        for tag in tags {
            var rect = (rect: getRect(str: attString, range: tag.range, maxWidth: UIScreen.main.bounds.width - 72), username: tag.username)
            rect.0 = CGRect(x: rect.0.minX, y: rect.0.minY, width: rect.0.width, height: rect.0.height)
            if (!freshRect.contains(where: {$0 == rect})) {
                freshRect.append(rect)
            }
        }
        return ((attString, freshRect))
    }
    
    func getRect(str: NSAttributedString, range: NSRange, maxWidth: CGFloat) -> CGRect {
        let textStorage = NSTextStorage(attributedString: str)
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 5
        let pointer = UnsafeMutablePointer<NSRange>.allocate(capacity: 1)
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: pointer)
        return layoutManager.boundingRect(forGlyphRange: pointer.move(), in: textContainer)
    }
}
