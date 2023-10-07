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
    func likePost(post: Post)
    func unlikePost(post: Post)
    func dislikePost(post: Post)
    func undislikePost(post: Post)
    func moreButtonTap(post: Post)
    func viewMoreTap(parentPostID: String)
    func replyTap(spot: Spot?, parentPostID: String, parentPosterID: String, replyToID: String, replyToUsername: String)
    func profileTap(userInfo: UserProfile)
    func spotTap(post: Post)
    func mapTap(post: Post)
}

enum SpotPostParent {
    case Home
    case SpotPage
    case Profile
    case CustomMap
}

final class SpotPostCell: UITableViewCell {
    weak var delegate: PostCellDelegate?
    var post: Post?
    private var tagRect: [(rect: CGRect, username: String)] = []
    private var imageWidth: CGFloat = 0
    
    private lazy var highlightView: UIView = {
        let view = UIView()
        view.alpha = 0.0
        view.backgroundColor = SpotColors.SpotGreen.color.withAlphaComponent(0.1)
        return view
    }()
    
    private lazy var postArea = UIView()
    
    private(set) lazy var bottomLine: UIView = {
        /// removed 3.02
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()
    
    private lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.isUserInteractionEnabled = true
        image.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        return image
    }()

    private lazy var scrollContainer: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        return view
    }()

    private lazy var spotIcon = UIImageView(image: UIImage(named: "LocationPin"))

    private lazy var spotLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        label.isUserInteractionEnabled = true
        label.isHidden = true
        label.lineBreakMode = .byTruncatingTail
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotTap)))
        return label
    }()

    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.179, green: 0.179, blue: 0.179, alpha: 1)
        return view
    }()

    private lazy var mapIcon: UIImageView = {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15.5, weight: .regular)
        let view = UIImageView(image: UIImage(systemName: "map", withConfiguration: symbolConfig))
        view.tintColor = SpotColors.SublabelGray.color
        return view
    }()

    private lazy var mapLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        label.isUserInteractionEnabled = true
        label.isHidden = true
        label.lineBreakMode = .byTruncatingTail
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTap)))
        return label
    }()
    
    private lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTap)))
        return label
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.308, green: 0.308, blue: 0.308, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        return label
    }()
    
    private lazy var moreButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
        button.setImage(UIImage(named: "GrayMoreButton"), for: .normal)
        button.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var thumbnailView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 17
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(thumbnailTap)))
        return view
    }()
    
    private lazy var playButton: UIImageView = {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        let view = UIImageView(image: UIImage(systemName: "play.fill", withConfiguration: symbolConfig))
        view.tintColor = .white
        return view
    }()
    
    private var viewMorePostsButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.setTitleColor(SpotColors.SublabelGray.color, for: .normal)
        button.titleLabel?.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        button.contentHorizontalAlignment = .left
        button.addTarget(self, action: #selector(viewMoreTap), for: .touchUpInside)
        return button
    }()
    
    private var morePostsActivityIndicator = UIActivityIndicatorView()
    
    private lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(red: 0.954, green: 0.954, blue: 0.954, alpha: 1)
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 18)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap)))
        return label
    }()
    
    private lazy var replyButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        let attributedString = NSAttributedString(string: "Reply", attributes: [
            .foregroundColor: SpotColors.SublabelGray.color,
            .font: SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        ])
        button.setAttributedTitle(attributedString, for: .normal)
        button.addTarget(self, action: #selector(replyTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var likeButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "LikeButton"), for: .normal)
        button.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var numLikes: UILabel = {
        let label = UILabel()
        label.textColor = SpotColors.SublabelGray.color
        label.font = SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5)
        return label
    }()
    
    private lazy var dislikeButton: UIButton = {
        let button = UIButton(withInsets: NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        button.setImage(UIImage(named: "DislikeButton"), for: .normal)
        button.addTarget(self, action: #selector(dislikeTap), for: .touchUpInside)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = SpotColors.SpotBlack.color
        setUpView()
    }

    override func layoutSubviews() {
        let maxXValue =
        post?.mapID ?? "" != "" ? mapLabel.frame.maxX :
        post?.spotID ?? "" != "" ? spotLabel.frame.maxX :
        usernameLabel.frame.maxX

        scrollContainer.contentSize = CGSize(width: maxXValue, height: scrollContainer.frame.height)
    }

    private func setUpView() {
        contentView.addSubview(highlightView)
        highlightView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        contentView.addSubview(postArea)
        postArea.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(moreTap)))
        
        postArea.addSubview(avatarImage)
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(9)
            $0.top.equalTo(5)
            $0.width.equalTo(33)
            $0.height.equalTo(37.12)
        }

        postArea.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.top.equalTo(7)
            $0.trailing.equalTo(-14)
            $0.width.equalTo(24.73)
            $0.height.equalTo(23)
        }

        postArea.addSubview(scrollContainer)
        scrollContainer.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(8).priority(.high)
            $0.trailing.equalTo(moreButton.snp.leading).offset(-3).priority(.high)
            $0.top.equalTo(8)
            $0.height.equalTo(20)
        }

        scrollContainer.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
        }

        // lay out in configureUsernameArea
        scrollContainer.addSubview(spotIcon)
        scrollContainer.addSubview(spotLabel)
        scrollContainer.addSubview(separatorView)
        scrollContainer.addSubview(mapIcon)
        scrollContainer.addSubview(mapLabel)

        postArea.addSubview(captionLabel)
        
        // lay out in configure
        postArea.addSubview(thumbnailView)
        thumbnailView.addSubview(playButton)
        
        // layout from bottom
        postArea.addSubview(viewMorePostsButton)
        viewMorePostsButton.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(10)
            $0.leading.equalTo(scrollContainer)
        }
        
        postArea.addSubview(morePostsActivityIndicator)
        morePostsActivityIndicator.isHidden = true
        morePostsActivityIndicator.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(12)
            $0.leading.equalTo(85)
        }

        /*
        postArea.addSubview(dislikeButton)
        dislikeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(11)
            $0.bottom.equalTo(replyButton).offset(-2)
        }

         */
        postArea.addSubview(replyButton)
        replyButton.snp.makeConstraints {
            $0.leading.equalTo(scrollContainer).offset(-5)
            $0.bottom.equalTo(viewMorePostsButton.snp.top).offset(-6)
        }

        postArea.addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.leading.equalTo(replyButton.snp.trailing).offset(8)
            $0.bottom.equalTo(replyButton).offset(-2)
        }

        postArea.addSubview(numLikes)
        numLikes.snp.makeConstraints {
            $0.leading.equalTo(likeButton.snp.trailing).offset(-1)
            $0.bottom.equalTo(likeButton).offset(-2)
        }

        postArea.addSubview(timestampLabel)
        timestampLabel.snp.makeConstraints {
            $0.trailing.equalTo(moreButton).offset(-5)
            $0.bottom.equalTo(replyButton).offset(-5)
        }

        layoutIfNeeded()
        layoutSubviews()
    }
    
    func configure(post: Post, parent: SpotPostParent) {
        self.post = post
        
        let lastReply = post.parentCommentCount > 0
        configurePostArea(reply: post.parentPostID ?? "" != "", lastReply: lastReply)
        
        if let image = post.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: post.userInfo?.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }
        
        configureUsernameArea(post: post, postParent: parent)
        
        replyButton.isEnabled = parent != .Profile
        replyButton.alpha = parent != .Profile ? 1.0 : 0.5
        
        timestampLabel.text = post.timestamp.toString(allowDate: false)
        
        captionLabel.attributedText = NSAttributedString(string: post.caption)
        addTaggedUsersToCaption()
        
        let viewMoreString = NSMutableAttributedString(string: "—", attributes: [.font : SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5), .foregroundColor: UIColor(red: 0.308, green: 0.308, blue: 0.308, alpha: 1)])
        var viewMoreTitle = lastReply ? "  View \(post.parentCommentCount)" : ""
        if viewMoreTitle != "" { viewMoreTitle += post.parentCommentCount > 1 ? " replies" : " reply" }
        let textString = NSAttributedString(string: viewMoreTitle, attributes: [.font: SpotFonts.SFCompactRoundedMedium.fontWith(size: 15.5), .foregroundColor: SpotColors.SublabelGray.color])
        viewMoreString.append(textString)

        viewMorePostsButton.isHidden = false
        viewMorePostsButton.setAttributedTitle(viewMoreString, for: .normal)
        setLikesAndDislikes(post: post, postParent: parent)
        
        configureThumbnailView(post: post)
    }
    
    private func configurePostArea(reply: Bool, lastReply: Bool) {
        postArea.snp.removeConstraints()
        viewMorePostsButton.snp.removeConstraints()
        
        //TODO: replace variable with autolayout constraints -> (username minX) - trailing spacing
        imageWidth = UIScreen.main.bounds.width - 52 - 14
        if reply {
            imageWidth -= 34
            
            postArea.snp.makeConstraints {
                $0.top.equalTo(0)
                $0.bottom.trailing.equalToSuperview()
                $0.leading.equalTo(34)
            }
        } else {
            postArea.snp.makeConstraints {
                $0.top.equalTo(14)
                $0.bottom.trailing.equalToSuperview()
                $0.leading.equalToSuperview()
            }
        }
        
        morePostsActivityIndicator.isHidden = true
        if lastReply {
            viewMorePostsButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().inset(12)
                $0.leading.equalTo(scrollContainer)
                $0.trailing.equalToSuperview().inset(19)
            }
        } else {
            viewMorePostsButton.snp.makeConstraints {
                $0.bottom.equalToSuperview().inset(7)
                $0.leading.equalTo(scrollContainer)
                $0.trailing.equalToSuperview().inset(19)
                $0.height.equalTo(0)
            }
        }
        viewMorePostsButton.layoutIfNeeded()
    }
    
    private func configureUsernameArea(post: Post, postParent: SpotPostParent) {
        // hide username if showing spot / map
        spotIcon.isHidden = true
        spotIcon.snp.removeConstraints()
        spotLabel.isHidden = true
        spotLabel.snp.removeConstraints()
        separatorView.isHidden = true
        separatorView.snp.removeConstraints()
        mapIcon.isHidden = true
        mapIcon.snp.removeConstraints()
        mapLabel.isHidden = true
        mapLabel.snp.removeConstraints()

        usernameLabel.isHidden = false
        usernameLabel.snp.removeConstraints()
        usernameLabel.attributedText = NSAttributedString(string: post.userInfo?.username ?? "")

        // slide username down if post doesn't have a caption (will also slide down spot and map)
        let topOffset: CGFloat = post.caption.isEmpty ? 5 : 0
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarImage.snp.trailing).offset(7)
            $0.top.equalTo(topOffset)
        }

        if let spotName = post.spotName, spotName != "", postParent != .SpotPage {
            usernameLabel.isHidden = true
            spotIcon.isHidden = false
            spotLabel.isHidden = false
            spotLabel.text = spotName

            spotIcon.snp.makeConstraints {
                $0.leading.top.equalToSuperview()
            }

            spotLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(spotTap)))
            spotLabel.snp.makeConstraints {
                $0.bottom.equalTo(spotIcon).offset(2)
                $0.leading.equalTo(spotIcon.snp.trailing).offset(4)
            }
        }

        if let mapName = post.mapName, mapName != "", postParent != .CustomMap {
            usernameLabel.isHidden = true
            mapIcon.isHidden = false
            mapLabel.isHidden = false
            mapLabel.text = mapName

            if spotLabel.isHidden {
                // left align map info
                mapIcon.snp.makeConstraints {
                    $0.leading.top.equalToSuperview()
                }
            } else {
                // add separator view and adjust map constraints
                separatorView.isHidden = false
                separatorView.snp.makeConstraints {
                    $0.leading.equalTo(spotLabel.snp.trailing).offset(8)
                    $0.width.equalTo(2)
                    $0.height.equalTo(19)
                    $0.centerY.equalTo(spotLabel)
                }

                mapIcon.snp.makeConstraints {
                    $0.leading.equalTo(separatorView.snp.trailing).offset(8)
                    $0.top.equalToSuperview()
                }
            }

            mapLabel.snp.makeConstraints {
                $0.bottom.equalTo(mapIcon)
                $0.leading.equalTo(mapIcon.snp.trailing).offset(4)
            }
        }
    }

    private func configureThumbnailView(post: Post) {
        thumbnailView.snp.removeConstraints()
        playButton.snp.removeConstraints()
        captionLabel.snp.removeConstraints()

        playButton.isHidden = true
        thumbnailView.isHidden = true

        thumbnailView.sd_cancelCurrentImageLoad()
        thumbnailView.image = nil

        var imageHeight: CGFloat = 0

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

            imageHeight = min(post.aspectRatios?.first ?? 1.2, 1.2) * (imageWidth)

            thumbnailView.snp.makeConstraints {
                $0.top.equalTo(captionLabel.snp.bottom).offset(9).priority(.high)
                $0.leading.equalTo(scrollContainer)
                $0.width.equalTo(imageWidth)
                $0.height.equalTo(imageHeight).priority(.high)
                $0.bottom.equalTo(replyButton.snp.top).offset(-6)
            }

            playButton.snp.makeConstraints {
                $0.centerX.centerY.equalToSuperview()
                $0.height.width.equalTo(40)
            }
        }

        captionLabel.snp.makeConstraints {
            $0.leading.equalTo(scrollContainer)
            $0.top.equalTo(scrollContainer.snp.bottom)
            $0.trailing.equalTo(moreButton.snp.leading)

            if thumbnailView.isHidden {
                $0.bottom.equalTo(replyButton.snp.top).offset(-9).priority(.high)
            }
        }
    }

    private func setLikesAndDislikes(post: Post, postParent: SpotPostParent) {
        let liked = post.likers.contains(UserDataModel.shared.uid)

        let likeImage = liked ?
        UIImage(named: "LikeButtonFilled") :
        UIImage(named: "LikeButton")
        likeButton.setImage(likeImage, for: .normal)

        numLikes.text = String(post.likers.count)
        numLikes.textColor = liked ?
        UIColor(hexString: "FF39A4") :
        UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1)

        let disliked = post.dislikers?.contains(UserDataModel.shared.uid) ?? false
        let dislikeImage = disliked ?
        UIImage(named: "DislikeButtonFilled") :
        UIImage(named: "DislikeButton")

        dislikeButton.setImage(dislikeImage, for: .normal)
    }

    private func addTaggedUsersToCaption() {
        if let taggedUsers = post?.taggedUsers, !taggedUsers.isEmpty {
            captionLabel.layoutIfNeeded()
            let attString = NSAttributedString.getTaggedUsers(caption: post?.caption ?? "", taggedFriends: taggedUsers, font: captionLabel.font, textColor: UIColor(hexString: "A9EBFA"), maxWidth: captionLabel.bounds.width)
            captionLabel.attributedText = attString.0
            tagRect = attString.1
        }
    }

    func highlightCell(duration: TimeInterval, delay: TimeInterval) {
        highlightView.alpha = 1.0
        UIView.animate(withDuration: duration, delay: delay) { [weak self] in
            self?.highlightView.alpha = 0.0
        }
    }

    @objc func profileTap() {
        Mixpanel.mainInstance().track(event: "PostCellProfileTap")
        guard let post, let userInfo = post.userInfo else { return }
        delegate?.profileTap(userInfo: userInfo)
    }

    @objc func moreTap() {
        Mixpanel.mainInstance().track(event: "PostCellMoreTap")
        guard let post else { return }
        delegate?.moreButtonTap(post: post)
    }

    @objc func replyTap() {
        Mixpanel.mainInstance().track(event: "PostCellReplyTap")
        HapticGenerator.shared.play(.light)
        // pass through the parent post if this is a reply, pass through this post if no parent
        let parentPostID = post?.parentPostID ?? post?.id ?? ""
        let parentPosterID = post?.parentPosterID ?? post?.posterID ?? ""

        let replyToUsername = post?.posterUsername ?? ""
        var spot: Spot?
        if let spotID = post?.spotID, spotID != "", let spotName = post?.spotName {
            spot = Spot(id: spotID, spotName: spotName)
        }
        delegate?.replyTap(spot: spot, parentPostID: parentPostID, parentPosterID: parentPosterID, replyToID: post?.posterID ?? "", replyToUsername: replyToUsername)
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
        // if comment, send through parent post, otherwise send through current post
        let postID = post.parentPostID ?? post.id ?? ""
        delegate?.viewMoreTap(parentPostID: postID)
        viewMorePostsButton.isHidden = true
        morePostsActivityIndicator.startAnimating()

        HapticGenerator.shared.play(.soft)
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
        if post.dislikers?.contains(where: { $0 == UserDataModel.shared.uid }) ?? false {
            delegate?.undislikePost(post: post)
        } else {
            delegate?.dislikePost(post: post)
        }
        HapticGenerator.shared.play(.light)
    }

    @objc private func captionTap(_ sender: UITapGestureRecognizer) {
        for r in tagRect {
            let expandedRect = CGRect(x: r.rect.minX - 3, y: r.rect.minY, width: r.rect.width + 6, height: r.rect.height + 3)
            if expandedRect.contains(sender.location(in: sender.view)) {
                Mixpanel.mainInstance().track(event: "PostPageOpenTaggedUserProfile")
                // open tag from friends list
                if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == r.username }) {
                    delegate?.profileTap(userInfo: user)

                } else {
                    // pass blank user object to open func, run get user func on profile load
                    var user = UserProfile()
                    user.username = r.username
                    delegate?.profileTap(userInfo: user)
                }
            }
        }
    }

    @objc func spotTap() {
        Mixpanel.mainInstance().track(event: "PostCellSpotTap")
        guard let post else { return }
        delegate?.spotTap(post: post)
    }

    @objc func mapTap() {
        Mixpanel.mainInstance().track(event: "PostCellMapTap")
        guard let post else { return }
        delegate?.mapTap(post: post)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
        avatarImage.sd_cancelCurrentImageLoad()
        avatarImage.image = nil
        thumbnailView.sd_cancelCurrentImageLoad()
        thumbnailView.image = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
