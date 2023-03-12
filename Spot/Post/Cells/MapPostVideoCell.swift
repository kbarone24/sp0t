//
//  MapPostVideoCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/8/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import AVFoundation
import SDWebImage
import Mixpanel

final class MapPostVideoCell: UITableViewCell {
    
    private(set) lazy var mapButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 15)
        button.contentVerticalAlignment = .center
        button.addTarget(self, action: #selector(mapTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.25)
        return view
    }()
    
    private(set) lazy var spotButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 15)
        button.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.6)
        label.font = UIFont(name: "SFCompactText-Medium", size: 15)
        return label
    }()

    private(set) lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        label.isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap)))
        return label
    }()
    
    private(set) lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.masksToBounds = true
        image.backgroundColor = .gray
        image.layer.cornerRadius = 33 / 2
        image.isUserInteractionEnabled = true
        image.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return image
    }()

    private(set) lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        // replace with actual font
        label.font = UIFont(name: "UniversCE-Black", size: 15)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return label
    }()

    private(set) lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.font = UIFont(name: "SFCompactText-Medium", size: 13.5)
        return label
    }()
    
    private(set) lazy var buttonView = UIView()
    private(set) lazy var likeButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "LikeButton"), for: .normal)
        button.addTarget(self, action: #selector(likeTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var numLikes: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 12)
        return label
    }()
    
    private(set) lazy var commentButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "CommentButton"), for: .normal)
        button.addTarget(self, action: #selector(commentsTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var numComments: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "UniversCE-Black", size: 12)
        return label
    }()
    
    private(set) lazy var moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "MoreButton"), for: .normal)
        button.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
        return button
    }()
    
    private(set) lazy var locationView = LocationScrollView()
    private(set) lazy var mapIcon = UIImageView(image: UIImage(named: "FeedMapIcon"))
    private(set) lazy var spotIcon = UIImageView(image: UIImage(named: "FeedSpotIcon"))
    private(set) lazy var playerView = PlayerView()
    
    weak var delegate: ContentViewerDelegate?
    private var moreShowing = false
    private var tagRect: [(rect: CGRect, username: String)] = []
    private var post: MapPost?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .black
        
        addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.centerY.centerX.equalToSuperview()
            make.width.equalTo(UIScreen.main.bounds.width - 5)
            make.height.equalTo(UIScreen.main.bounds.height - 45)
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem, queue: nil) { [weak self] _ in
            self?.playerView.player?.seek(to: CMTime.zero)
            self?.playerView.player?.play()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem)
        
        playerView.player?.pause()
        playerView.player = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        animateLocation()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        playerView.player?.pause()
        playerView.player = nil
        self.post = nil
    }
    
    func configure(post: MapPost, url: URL) {
        self.post = post
        configureVideo(url: url)
        setLocationView(post: post)
        setPostInfo(post: post)
        setCommentsAndLikes(post: post)
    }
    
    private func configureVideo(url: URL) {
        let player = AVPlayer(url: url)
        playerView.player = player
        player.play()
    }
    
    private func setUpView() {
        // lay out views from bottom to top

        contentView.addSubview(buttonView)
        buttonView.snp.makeConstraints {
            $0.trailing.equalTo(-4)
            $0.bottom.equalToSuperview().offset(-12)
            $0.height.equalTo(186)
            $0.width.equalTo(52)
        }

        buttonView.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(52)
        }

        buttonView.addSubview(numComments)
        numComments.snp.makeConstraints {
            $0.bottom.equalTo(moreButton.snp.top).offset(-5)
            $0.height.greaterThanOrEqualTo(11)
            $0.centerX.equalToSuperview()
        }

        buttonView.addSubview(commentButton)
        commentButton.snp.makeConstraints {
            $0.bottom.equalTo(numComments.snp.top).offset(1)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }

        buttonView.addSubview(numLikes)
        numLikes.snp.makeConstraints {
            $0.bottom.equalTo(commentButton.snp.top).offset(-5)
            $0.height.greaterThanOrEqualTo(11)
            $0.centerX.equalToSuperview()
        }

        buttonView.addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.bottom.equalTo(numLikes.snp.top).offset(1)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }

        // location view subviews are added when cell is dequeued
        contentView.addSubview(locationView)
        locationView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.trailing.equalTo(buttonView.snp.leading).offset(-7)
            $0.bottom.equalToSuperview().offset(-15)
            $0.height.equalTo(32)
        }

        contentView.addSubview(captionLabel)
        captionLabel.snp.makeConstraints {
            $0.leading.equalTo(55)
            $0.bottom.equalTo(locationView.snp.top).offset(-15)
            $0.trailing.lessThanOrEqualTo(buttonView.snp.leading).offset(-7)
            $0.height.lessThanOrEqualTo(52)
        }

        contentView.addSubview(usernameLabel)
        usernameLabel.snp.makeConstraints {
            $0.leading.equalTo(captionLabel)
            $0.bottom.equalTo(captionLabel.snp.top).offset(-4)
        }

        contentView.addSubview(timestampLabel)
        timestampLabel.snp.makeConstraints {
            $0.leading.equalTo(usernameLabel.snp.trailing).offset(4)
            $0.bottom.equalTo(usernameLabel)
        }

        contentView.addSubview(profileImage)
        profileImage.snp.makeConstraints {
            $0.leading.equalTo(14)
            $0.top.equalTo(usernameLabel)
            $0.height.width.equalTo(33)
        }
    }
    
    private func setLocationView(post: MapPost) {
        locationView.stopAnimating()
        locationView.contentOffset.x = -locationView.contentInset.left
        locationView.subviews.forEach {
            $0.removeFromSuperview()
        }
        
        // add map if map exists unless parent == map
        var mapShowing = false
        if let mapName = post.mapName, mapName != "" {
            mapShowing = true

            locationView.addSubview(mapIcon)
            mapIcon.snp.makeConstraints {
                $0.leading.equalToSuperview()
                $0.width.equalTo(15)
                $0.height.equalTo(16)
                $0.centerY.equalToSuperview()
            }

            mapButton.setTitle(mapName, for: .normal)
            locationView.addSubview(mapButton)
            mapButton.snp.makeConstraints {
                $0.leading.equalTo(mapIcon.snp.trailing).offset(6)
                $0.bottom.equalTo(mapIcon).offset(6.5)
                $0.trailing.lessThanOrEqualToSuperview()
            }

            locationView.addSubview(separatorView)
            separatorView.snp.makeConstraints {
                $0.leading.equalTo(mapButton.snp.trailing).offset(9)
                $0.height.equalToSuperview()
                $0.width.equalTo(2)
            }
        }
        
        var spotShowing = false
        if let spotName = post.spotName, spotName != "" {
            // add spot if spot exists unless parent == spot
            spotShowing = true

            locationView.addSubview(spotIcon)
            spotIcon.snp.makeConstraints {
                if mapShowing {
                    $0.leading.equalTo(separatorView.snp.trailing).offset(9)
                } else {
                    $0.leading.equalToSuperview()
                }
                $0.centerY.equalToSuperview().offset(-0.5)
                $0.width.equalTo(14.17)
                $0.height.equalTo(17)
            }

            spotButton.setTitle(spotName, for: .normal)
            locationView.addSubview(spotButton)
            spotButton.snp.makeConstraints {
                $0.leading.equalTo(spotIcon.snp.trailing).offset(6)
                $0.bottom.equalTo(spotIcon).offset(7)
                $0.trailing.lessThanOrEqualToSuperview()
            }
        }
        // always add city
        cityLabel.text = post.city ?? ""
        locationView.addSubview(cityLabel)
        cityLabel.snp.makeConstraints {
            if spotShowing {
                $0.leading.equalTo(spotButton.snp.trailing).offset(6)
                $0.bottom.equalTo(spotIcon).offset(0.5)
            } else if mapShowing {
                $0.leading.equalTo(separatorView.snp.trailing).offset(9)
                $0.bottom.equalTo(mapIcon).offset(0.5)
            } else {
                $0.leading.equalToSuperview()
                $0.bottom.equalTo(-8)
            }
            $0.trailing.lessThanOrEqualToSuperview()
        }

        // animate location if necessary
        layoutIfNeeded()
        animateLocation()
    }
    
    private func setPostInfo(post: MapPost) {
        // add caption and check for more buton after laying out subviews / frame size is determined
        captionLabel.attributedText = NSAttributedString(string: post.caption)
        addCaptionAttString(post: post)

        // update username constraint with no caption -> will also move prof pic, timestamp
        if post.caption.isEmpty {
            profileImage.snp.removeConstraints()
            profileImage.snp.makeConstraints {
                $0.leading.equalTo(14)
                $0.centerY .equalTo(usernameLabel)
                $0.height.width.equalTo(33)
            }
        }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: post.userInfo?.imageURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        usernameLabel.text = post.userInfo?.username ?? ""
        timestampLabel.text = post.timestamp.toString(allowDate: true)

        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }
    
    private func addCaptionAttString(post: MapPost) {
        if let taggedUsers = post.taggedUsers, !taggedUsers.isEmpty {
            // maxWidth = button view width (52) + spacing (12) + leading constraint (55)
            let attString = NSAttributedString.getAttString(caption: post.caption , taggedFriends: taggedUsers, font: captionLabel.font, maxWidth: UIScreen.main.bounds.width - 159)
            captionLabel.attributedText = attString.0
            tagRect = attString.1
        }
    }
    
    private func addMoreIfNeeded() {
        if captionLabel.intrinsicContentSize.height > captionLabel.frame.height {
            moreShowing = true
            captionLabel.addTrailing(with: "... ", moreText: "more", moreTextFont: UIFont(name: "SFCompactText-Bold", size: 14.5), moreTextColor: .white)
        }
    }
    
    private func animateLocation() {
        if locationView.bounds.width == 0 {
            return
        }
        
        if locationView.contentSize.width > locationView.bounds.width {
            DispatchQueue.main.async { [weak self] in
                self?.locationView.startAnimating()
            }
        }
    }
    
    private func setCommentsAndLikes(post: MapPost) {
        let liked = post.likers.contains(UserDataModel.shared.uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = post.likers.count > 0 ? String(post.likers.count) : ""
        likeButton.setImage(likeImage, for: .normal)

        let commentCount = max((post.commentList.count) - 1, 0)
        numComments.text = commentCount > 0 ? String(commentCount) : ""
    }
}

// MARK: - Actions

extension MapPostVideoCell {
    @objc private func likeTap() {
        delegate?.likePost(postID: post?.id ?? "")
    }

    @objc private func commentsTap() {
        Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromButton")
        delegate?.openPostComments()
    }

    @objc private func moreTap() {
        delegate?.openPostActionSheet()
    }
    
    @objc private func captionTap(_ sender: UITapGestureRecognizer) {
        if tapInTagRect(sender: sender) {
            /// profile open handled on function call
            return
        } else if moreShowing {
            Mixpanel.mainInstance().track(event: "PostPageExpandCaption")
            expandCaption()
        } else {
            Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromCaption")
            delegate?.openPostComments()
        }
    }
    
    @objc private func userTap() {
        if let user = post?.userInfo {
            delegate?.openProfile(user: user)
        }
    }

    @objc private func spotTap() {
        if let post = post {
            delegate?.openSpot(post: post)
        }
    }
    
    @objc private func mapTap() {
        if let mapID = post?.mapID, let mapName = post?.mapName {
            delegate?.openMap(mapID: mapID, mapName: mapName)
        }
    }

    func tapInTagRect(sender: UITapGestureRecognizer) -> Bool {
        for r in tagRect {
            let expandedRect = CGRect(x: r.rect.minX - 3, y: r.rect.minY, width: r.rect.width + 6, height: r.rect.height + 3)
            if expandedRect.contains(sender.location(in: sender.view)) {
                Mixpanel.mainInstance().track(event: "PostPageOpenTaggedUserProfile")
                // open tag from friends list
                if let user = UserDataModel.shared.userInfo.friendsList.first(where: { $0.username == r.username }) {
                    delegate?.openProfile(user: user)
                    return true
                } else {
                    // pass blank user object to open func, run get user func on profile load
                    let user = UserProfile(currentLocation: "", imageURL: "", name: "", userBio: "", username: r.username)
                    delegate?.openProfile(user: user)
                }
            }
        }
        return false
    }
    
    private func expandCaption() {
        moreShowing = false
        captionLabel.numberOfLines = 0
        captionLabel.snp.updateConstraints { $0.height.lessThanOrEqualTo(300) }
        captionLabel.attributedText = NSAttributedString(string: post?.caption ?? "")
        
        if let post {
            addCaptionAttString(post: post)
        }
    }

    private func stopLocationAnimation() {
        locationView.stopAnimating()
    }
}