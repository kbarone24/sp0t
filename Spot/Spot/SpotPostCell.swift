//
//  SpotPostCell.swift
//  Spot
//
//  Created by Kenny Barone on 7/7/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDWebImage
import Mixpanel

protocol PostCellDelegate: AnyObject {
    func likePost(post: MapPost)
    func unlikePost(post: MapPost)
    func dislikePost(post: MapPost)
    func undislikePost(post: MapPost)
    func moreButtonTap(post: MapPost)
    func viewMoreTap(parentPostID: String)
    func replyTap(parentPostID: String, replyUsername: String, parentPosterID: String)
}

final class SpotPostCell: UITableViewCell {
    weak var delegate: PostCellDelegate?
    var post: MapPost?

    private lazy var postArea = UIView()

    private lazy var topLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = true
        image.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return image
    }()

    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Semibold", size: 17.5)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return label
    }()

    private lazy var replyArrow = UIImageView(image: UIImage(named: "ReplyArrow"))

    private lazy var parentUsernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        return label
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        return label
    }()

    private lazy var moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "SimpleMoreButton"), for: .normal)
        button.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
        return button
    }()

    private lazy var thumbnailView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 25
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(thumbnailTap)))
        return view
    }()

    private lazy var playButton = UIImageView(image: UIImage(named: "PlayButton"))

    private var viewMorePostsButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.setTitleColor(UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactRounded-Semibold", size: 17.5)
        button.addTarget(self, action: #selector(viewMoreTap), for: .touchUpInside)
        return button
    }()

    private var morePostsActivityIndicator = UIActivityIndicatorView()

    private lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Regular", size: 20.5)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        return label
    }()

    private lazy var replyButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1), for: .normal)
        button.titleLabel?.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        button.addTarget(self, action: #selector(replyTap), for: .touchUpInside)
        return button
    }()

    private lazy var likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "LikeButton"), for: .normal)
        button.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
        return button
    }()

    private lazy var numLikes: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        return label
    }()

    private lazy var dislikeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "DislikeButton"), for: .normal)
        button.addTarget(self, action: #selector(dislikeTap), for: .touchUpInside)
        return button
    }()

    private lazy var numDislikes: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        label.font = UIFont(name: "SFCompactRounded-Medium", size: 17.5)
        return label
    }()


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = SpotColors.SpotBlack.color
        setUpView()
    }


    private func setUpView() {
        contentView.addSubview(topLine)
        topLine.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(1)
        }

        contentView.addSubview(postArea)

        postArea.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.top.equalTo(5)
            $0.width.equalTo(37.33)
            $0.height.equalTo(42)
        }

        postArea.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.top.equalTo(10)
        }

        postArea.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.top.equalTo(20)
            $0.trailing.equalTo(-13)
            $0.width.equalTo(13.6)
            $0.height.equalTo(28)
        }

        // set constraints in set up
        postArea.addSubview(replyArrow)
        postArea.addSubview(parentUsernameLabel)
        postArea.addSubview(separatorView)
        postArea.addSubview(timestampLabel)

        postArea.addSubview(thumbnailView)
        thumbnailView.addSubview(playButton)

        // layout from bottom
        postArea.addSubview(viewMorePostsButton)
        viewMorePostsButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(10)
            $0.leading.equalTo(19)
        }

        postArea.addSubview(morePostsActivityIndicator)
        morePostsActivityIndicator.isHidden = true
        morePostsActivityIndicator.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(12)
            $0.leading.equalTo(85)
        }

        postArea.addSubview(replyButton)
        replyButton.snp.makeConstraints {
            $0.bottom.equalTo(viewMorePostsButton.snp.top).offset(-14)
            $0.leading.equalTo(19)
        }

        postArea.addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.leading.equalTo(replyButton.snp.trailing).offset(30)
            $0.bottom.equalTo(replyButton).offset(-2)
        }

        postArea.addSubview(numLikes)
        numLikes.snp.makeConstraints {
            $0.leading.equalTo(likeButton.snp.trailing).offset(2)
            $0.bottom.equalTo(likeButton).offset(-3)
        }

        postArea.addSubview(dislikeButton)
        dislikeButton.snp.makeConstraints {
            $0.leading.equalTo(numLikes.snp.trailing).offset(24)
            $0.bottom.equalTo(likeButton)
        }

        postArea.addSubview(numDislikes)
        numDislikes.snp.makeConstraints {
            $0.leading.equalTo(dislikeButton.snp.trailing).offset(2)
            $0.bottom.equalTo(dislikeButton).offset(-3)
        }

        postArea.addSubview(captionLabel)
    }

    func configure(post: MapPost, delegate: PostCellDelegate) {
        self.post = post
        self.delegate = delegate

        let lastReply = post.parentCommentCount > 0
        configurePostArea(reply: post.parentPostID ?? "" != "", lastReply: lastReply)

        if let image = post.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: post.userInfo?.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        usernameLabel.text = post.userInfo?.username ?? ""
        timestampLabel.text = post.timestamp.toString(allowDate: true)

        if post.parentPostID ?? "" != "" {
            parentUsernameLabel.text = post.parentPosterUsername ?? ""
            addReplyUsername()
        } else {
            removeReplyUsername()
        }

        var replyString = "Reply"
        if let commentCount = post.commentCount, commentCount > 0 {
            replyString += " (\(commentCount))"
        }
        replyButton.setTitle(replyString, for: .normal)
        captionLabel.text = post.caption

        var viewMoreTitle = lastReply ? "View \(post.parentCommentCount) more" : ""
        if viewMoreTitle != "" { viewMoreTitle += post.parentCommentCount > 1 ? " replies" : " reply" }
        viewMorePostsButton.setTitle(viewMoreTitle, for: .normal)
        setLikesAndDislikes(post: post)

        configureThumbnailView(post: post)
    }

    private func configurePostArea(reply: Bool, lastReply: Bool) {
        topLine.isHidden = reply
        postArea.snp.removeConstraints()
        viewMorePostsButton.snp.removeConstraints()

        if reply {
            postArea.snp.makeConstraints {
                $0.top.equalTo(0)
                $0.bottom.trailing.equalToSuperview()
                $0.leading.equalTo(24)
            }
        } else {
            postArea.snp.makeConstraints {
                $0.top.equalTo(10)
                $0.bottom.trailing.equalToSuperview()
                $0.leading.equalToSuperview()
            }
        }

        morePostsActivityIndicator.isHidden = true
        if lastReply {
            viewMorePostsButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().inset(10)
                $0.leading.equalTo(19)
            }
        } else {
            viewMorePostsButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().inset(10)
                $0.leading.equalTo(19)
                $0.height.equalTo(0)
            }
        }
    }

    private func configureThumbnailView(post: MapPost) {
        thumbnailView.snp.removeConstraints()
        playButton.snp.removeConstraints()
        captionLabel.snp.removeConstraints()

        playButton.isHidden = true
        thumbnailView.isHidden = true

        var imageHeight: CGFloat = 0
        var imageWidth: CGFloat = 0

        if let imageURL = post.imageURLs.first, imageURL != "" {
            thumbnailView.isHidden = false
            let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height), scaleMode: .aspectFit)
            thumbnailView.sd_imageIndicator = SDWebImageActivityIndicator.whiteLarge

            thumbnailView.sd_setImage(
                with: URL(string: imageURL),
                placeholderImage: UIImage(color: .darkGray),
                options: .highPriority,
                context: [.imageTransformer : transformer],
                progress: nil,
                completed: { [weak self] (_, _, _, _) in
                    if let videoURL = post.videoURL, videoURL != "" {
                        self?.playButton.isHidden = false
                    }
                })

            imageWidth = UIScreen.main.bounds.width - 62
            imageHeight = min(post.aspectRatios?.first ?? 1.23, 1.23) * (imageWidth)
        }

        captionLabel.snp.makeConstraints {
            $0.bottom.equalTo(replyButton.snp.top).offset(-12)
            $0.leading.trailing.equalToSuperview().inset(19)
        }

        thumbnailView.snp.makeConstraints {
            $0.top.equalTo(avatarImage.snp.bottom).offset(13)
            $0.leading.equalTo(17)
            $0.width.equalTo(imageWidth)
            $0.height.equalTo(imageHeight).priority(.high)

            if post.caption.isEmpty {
                $0.bottom.equalTo(replyButton.snp.top).offset(-12)
            } else {
                $0.bottom.equalTo(captionLabel.snp.top).offset(-12)
            }
        }

        playButton.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.height.width.equalTo(40)
        }

    }

    private func removeReplyUsername() {
        replyArrow.isHidden = true
        parentUsernameLabel.isHidden = true
        separatorView.isHidden = true

        timestampLabel.snp.removeConstraints()
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(2)
        }
    }

    private func addReplyUsername() {
        replyArrow.snp.removeConstraints()
        parentUsernameLabel.snp.removeConstraints()
        separatorView.snp.removeConstraints()
        timestampLabel.snp.removeConstraints()

        replyArrow.isHidden = false
        replyArrow.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel).offset(1)
            $0.top.equalTo(usernameLabel.snp.bottom).offset(5.5)
        }

        parentUsernameLabel.isHidden = false
        parentUsernameLabel.snp.makeConstraints {
            $0.leading.equalTo(replyArrow.snp.trailing).offset(4)
            $0.centerY.equalTo(replyArrow)
        }

        separatorView.isHidden = false
        separatorView.snp.makeConstraints {
            $0.leading.equalTo(parentUsernameLabel.snp.trailing).offset(7)
            $0.centerY.equalTo(parentUsernameLabel).offset(2)
            $0.width.equalTo(2)
            $0.height.equalTo(11)
        }

        timestampLabel.isHidden = false
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(separatorView.snp.trailing).offset(7)
            $0.centerY.equalTo(parentUsernameLabel)
            $0.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-12)
        }
    }

    private func setLikesAndDislikes(post: MapPost) {
        let liked = post.likers.contains(UserDataModel.shared.uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = String(post.likers.count)
        numLikes.textColor = liked ? UIColor(red: 0.225, green: 0.952, blue: 1, alpha: 1) : UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        likeButton.setImage(likeImage, for: .normal)

        let disliked = post.dislikers.contains(UserDataModel.shared.uid)
        let dislikeImage = disliked ? UIImage(named: "DislikeButtonFilled") : UIImage(named: "DislikeButton")

        numDislikes.text = String(post.dislikers.count)
        numDislikes.textColor = disliked ?  UIColor(red: 0.988, green: 0.694, blue: 0.141, alpha: 1) : UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)
        dislikeButton.setImage(dislikeImage, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func userTap() {
        Mixpanel.mainInstance().track(event: "PostCellUserTap")
    }

    @objc func moreTap() {
        Mixpanel.mainInstance().track(event: "PostCellMoreTap")
        guard let post else { return }
        delegate?.moreButtonTap(post: post)
    }

    @objc func replyTap() {
        Mixpanel.mainInstance().track(event: "PostCellReplyTap")
        // pass through the parent post if this is a reply, pass through this post if no parent
        let parentPostID = post?.parentPostID ?? post?.id ?? ""
        delegate?.replyTap(parentPostID: parentPostID, replyUsername: post?.posterUsername ?? "", parentPosterID: post?.posterID ?? "")
    }

    @objc func thumbnailTap() {
        Mixpanel.mainInstance().track(event: "PostCellThumbnailTap")
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        layoutIfNeeded()
        // patch for x value being doubled (34 instead of 17)
        let frameInCell = CGRect(x: 0, y: thumbnailView.frame.minY, width: thumbnailView.frame.width, height: thumbnailView.frame.height)
        let frameInWindow = thumbnailView.convert(frameInCell, to: window)
        let thumbnailImage = thumbnailView.image ?? UIImage()

        if let urlString = post?.videoURL, urlString != "" {
            let fullscreenView = FullScreenVideoView(
                thumbnailImage: thumbnailImage,
                urlString: urlString,
                initialFrame: frameInWindow
            )
            window.addSubview(fullscreenView)
            fullscreenView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            fullscreenView.expand()

        } else {
            let fullscreenView = FullScreenImageView(
                image: thumbnailImage,
                urlString: post?.imageURLs.first ?? "",
                imageAspect: post?.aspectRatios?.first ?? 1.0,
                initialFrame: frameInWindow
            )
            window.addSubview(fullscreenView)
            fullscreenView.snp.makeConstraints {
                $0.edges.equalToSuperview()
            }
            fullscreenView.expand()
        }
    }

    @objc func viewMoreTap() {
        Mixpanel.mainInstance().track(event: "PostCellViewMoreTap")
        guard let post else { return }
        delegate?.viewMoreTap(parentPostID: post.parentPostID ?? "")
        viewMorePostsButton.isHidden = true
        morePostsActivityIndicator.startAnimating()
    }

    @objc func likeTap() {
        Mixpanel.mainInstance().track(event: "PostCellLikeTap")
        guard let post else { return }
        if post.likers.contains(where: { $0 == UserDataModel.shared.uid }) {
            delegate?.unlikePost(post: post)
        } else {
            delegate?.likePost(post: post)
        }
        HapticGenerator.shared.play(.light)
    }

    @objc func dislikeTap() {
        Mixpanel.mainInstance().track(event: "PostCellDislikeTap")
        guard let post else { return }
        if post.dislikers.contains(where: { $0 == UserDataModel.shared.uid }) {
            delegate?.undislikePost(post: post)
        } else {
            delegate?.dislikePost(post: post)
        }
        HapticGenerator.shared.play(.light)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
        avatarImage.sd_cancelCurrentImageLoad()
        avatarImage.image = nil
        thumbnailView.sd_cancelCurrentImageLoad()
        thumbnailView.image = nil
    }

    deinit {
        print("cell deinit")
    }
}
