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
import FirebaseAuth
import SDWebImage

protocol CommentCellDelegate: AnyObject {
    func tagUserFromCell(username: String)
    func likeCommentFromCell(comment: MapComment)
    func unlikeCommentFromCell(comment: MapComment)
    func openProfileFromCell(user: UserProfile)
}

final class CommentCell: UITableViewCell {
    private var comment: MapComment?
    private var post: MapPost?
    public weak var delegate: CommentCellDelegate?

    private(set) lazy var likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        return button
    }()
    private(set) lazy var numLikes: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Heavy", size: 10.5)
        label.textAlignment = .center
        label.isHidden = false
        return label
    }()
    private(set) lazy var avatarImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(userTap))
        view.addGestureRecognizer(tap)
        return view
    }()
    private(set) lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont(name: "SFCompactText-Semibold", size: 14.5)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return label
    }()
    private(set) lazy var commentLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.562, green: 0.562, blue: 0.562, alpha: 1)
        label.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tappedLabel(_:))))
        return label
    }()

    private lazy var tagRect: [(rect: CGRect, username: String)] = []
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
        contentView.addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.top.equalTo(21)
            $0.width.equalTo(28.8)
            $0.height.equalTo(27)
        }

        contentView.addSubview(numLikes)
        numLikes.snp.makeConstraints {
            $0.leading.equalTo(likeButton.snp.trailing)
            $0.bottom.equalTo(likeButton.snp.bottom).inset(5)
        }

        contentView.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.top.equalTo(15)
            $0.width.equalTo(36)
            $0.height.equalTo(40.5)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(9)
            $0.top.equalTo(17)
            $0.trailing.lessThanOrEqualTo(likeButton.snp.leading).inset(5)
        }

        contentView.addSubview(commentLabel)
        commentLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(9)
            $0.trailing.lessThanOrEqualTo(likeButton.snp.leading).offset(-8)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(1)
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

        usernameLabel.text = comment.userInfo?.username ?? ""
        usernameLabel.sizeToFit()

        let liked = comment.likers?.contains(where: { $0 == uid }) ?? false
        let image = liked ? UIImage(named: "CommentLikeButtonFilled") : UIImage(named: "CommentLikeButton")?.withTintColor(UIColor(red: 0.342, green: 0.342, blue: 0.342, alpha: 1))
        likeButton.setImage(image, for: .normal)
        if liked {
            likeButton.addTarget(self, action: #selector(unlikeTap(_:)), for: .touchUpInside)
        } else {
            likeButton.addTarget(self, action: #selector(likeTap(_:)), for: .touchUpInside)
        }

        likeCount = comment.likers?.count ?? 0

        let url = comment.userInfo?.avatarURL ?? ""
        if url != "" {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: url), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImage.sd_cancelCurrentImageLoad()
    }

    func addAttString() {
        if !(comment?.taggedUsers?.isEmpty ?? true) {
            let attString = NSAttributedString.getAttString(
                caption: comment?.comment ?? "",
                taggedFriends: comment?.taggedUsers ?? [],
                font: commentLabel.font,
                maxWidth: UIScreen.main.bounds.width - 105
            )
            commentLabel.attributedText = attString.0
            tagRect = attString.1
        }
    }
    // https://stackoverflow.com/questions/37942812/turn-some-parts-of-uilabel-to-act-like-a-uibutton

    func tagUser() {
        /// @ tapped comment's poster at the end of the active comment text
        let username = "@\(comment?.userInfo?.username ?? "") "
        delegate?.tagUserFromCell(username: username)
    }

    @objc func likeTap(_ sender: UIButton) {
        if let comment {
            Mixpanel.mainInstance().track(event: "CommentsLikeComment")
            delegate?.likeCommentFromCell(comment: comment)
        }
    }

    @objc func unlikeTap(_ sender: UIButton) {
        if let comment {
            Mixpanel.mainInstance().track(event: "CommentsUnlikeComment")
            delegate?.unlikeCommentFromCell(comment: comment)
        }
    }

    @objc func tappedLabel(_ sender: UITapGestureRecognizer) {
        print("tapped label")
        // tag tap
        for r in tagRect where r.rect.contains(sender.location(in: sender.view)) {
            Mixpanel.mainInstance().track(event: "CommentsOpenTaggedUserProfile")
            /// open tag from friends list
            if let friend = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == r.username }) {
                delegate?.openProfileFromCell(user: friend)
            } else {
                /// pass blank user object to open func, run get user func on profile load
                let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                delegate?.openProfileFromCell(user: user)
            }
            return
        }

        Mixpanel.mainInstance().track(event: "CommentsTapTagUser")
        tagUser()
    }

    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "CommentsUserTap")
        guard let user = comment?.userInfo else { return }
        openProfile(user: user)
    }

    func openProfile(user: UserProfile) {
        delegate?.openProfileFromCell(user: user)
    }
}
