//
//  CommentCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 12/24/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import Mixpanel
import Firebase
import SDWebImage

final class CommentCell: UITableViewCell {
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        translatesAutoresizingMaskIntoConstraints = true
        backgroundColor = UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1)
        tag = 30
        setUpView()
    }

    @available(*, unavailable)
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
            $0.layer.cornerRadius = 39 / 2
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

        let liked = comment.likers?.contains(where: { $0 == uid }) ?? false
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
            let attString = NSAttributedString.getAttString(caption: comment.comment, taggedFriends: comment.taggedUsers!, font: commentLabel.font, maxWidth: UIScreen.main.bounds.width - 105)
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
                if let friend = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == r.username }) {
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

