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
import FirebaseFirestore
import CoreLocation

final class MapPostVideoCell: UICollectionViewCell {
    
    private(set) lazy var mapButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 15)
        button.contentVerticalAlignment = .center
     //   button.addTarget(self, action: #selector(mapTap), for: .touchUpInside)
        button.isUserInteractionEnabled = false
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
     //   button.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
        button.isUserInteractionEnabled = false
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
    
    private(set) lazy var avatarImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.masksToBounds = true
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
    private var cancelLocationAnimation = false
    private var tagRect: [(rect: CGRect, username: String)] = []
    var post: MapPost?
    private var videoURL: URL?

    lazy var topMask = UIView()
    lazy var bottomMask = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        contentView.addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        setUpView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        removeNotifications()
        playerView.player?.pause()
        playerView.player = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if topMask.superview == nil { addTopMask() }
        if bottomMask.superview == nil { addBottomMask() }
    }
    
    override func prepareForReuse() {
        playerView.player?.pause()
        playerView.player = nil
        
        super.prepareForReuse()
        self.post = nil
        self.videoURL = nil
    }
    
    func configure(post: MapPost, parent: PostParent, url: URL) {
        self.post = post
        self.videoURL = url
    //    configureVideo(url: url)
        setLocationView(post: post)
        setPostInfo(post: post, parent: parent)
        setCommentsAndLikes(post: post)
    }

    func addNotifications() {
        removeNotifications()
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem, queue: nil) { [weak self] _ in
            self?.playerView.player?.seek(to: CMTime.zero)
            self?.playerView.player?.play()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playItem),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerView.player?.currentItem)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func configureVideo(url: URL) {
        let player = AVPlayer(url: url)
        playerView.player = player
        player.play()
        addNotifications()
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
        locationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(locationViewTap)))
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

        contentView.addSubview(avatarImage)
    }
    
    func setLocationView(post: MapPost) {
        cancelLocationAnimation = false
        locationView.stopAnimating()
        locationView.contentOffset.x = -locationView.contentInset.left
        for view in locationView.subviews { view.removeFromSuperview() }
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
                $0.height.equalToSuperview().inset(5)
                $0.centerY.equalToSuperview()
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
                $0.leading.equalTo(spotIcon.snp.trailing).offset(5)
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
                $0.bottom.equalTo(spotIcon).offset(1.5)
            } else if mapShowing {
                $0.leading.equalTo(separatorView.snp.trailing).offset(9)
                $0.bottom.equalTo(mapIcon).offset(1.5)
            } else {
                $0.leading.equalToSuperview()
                $0.centerY.equalToSuperview()
            }
            $0.trailing.lessThanOrEqualToSuperview()
        }
    }

    private func setPostInfo(post: MapPost, parent: PostParent) {
        // add caption and check for more buton after laying out subviews / frame size is determined
        captionLabel.attributedText = NSAttributedString(string: post.caption)
        addCaptionAttString(post: post)

        // update username constraint with no caption -> will also move prof pic, timestamp
        avatarImage.snp.removeConstraints()
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.height.equalTo(40.5)
            $0.width.equalTo(36)
            if post.caption.isEmpty {
                $0.centerY.equalTo(usernameLabel).offset(-3)
            } else {
                $0.top.equalTo(usernameLabel).offset(-6)
            }
        }

        if let image = post.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: post.userInfo?.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        usernameLabel.text = post.userInfo?.username ?? ""

        // add distance marker for nearby feed
        if parent == .Nearby, !UserDataModel.shared.currentLocation.coordinate.isEmpty() {
            let distance = max(CLLocation(latitude: post.postLat, longitude: post.postLong).distance(from: UserDataModel.shared.currentLocation), 1)
            timestampLabel.text = distance.getLocationString()
        } else {
            timestampLabel.text = post.timestamp.toString(allowDate: true)
        }

        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }
    
    private func addCaptionAttString(post: MapPost) {
        if let taggedUsers = post.taggedUsers, !taggedUsers.isEmpty {
            // maxWidth = button view width (52) + spacing (12) + leading constraint (55)
            let attString = NSAttributedString.getAttString(caption: post.caption, taggedFriends: taggedUsers, font: captionLabel.font, maxWidth: UIScreen.main.bounds.width - 159)
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
    
    func animateLocation() {
        if locationView.bounds.width == 0 {
            return
        }
        
        if locationView.contentSize.width > locationView.bounds.width {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if !(self?.cancelLocationAnimation ?? true) {
                    self?.locationView.startAnimating()
                }
            }
        }
    }
    
    private func setCommentsAndLikes(post: MapPost) {
        let liked = post.likers.contains(UserDataModel.shared.uid)
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = post.likers.isEmpty ? "" : String(post.likers.count)
        likeButton.setImage(likeImage, for: .normal)

        let commentCount = max((post.commentList.count) - 1, 0)
        numComments.text = commentCount > 0 ? String(commentCount) : ""
    }

    private func addTopMask() {
        contentView.insertSubview(topMask, aboveSubview: playerView)
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(140)
        }
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 140)
        layer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer.endPoint = CGPoint(x: 0.5, y: 0.0)
        layer.locations = [0, 1]
        topMask.layer.addSublayer(layer)
    }

    private func addBottomMask() {
        contentView.insertSubview(bottomMask, aboveSubview: playerView)
        bottomMask.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(260)
        }
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 260)
        layer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.8).cgColor
        ]
        layer.locations = [0, 1]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomMask.layer.addSublayer(layer)
    }
}

// MARK: - Actions

extension MapPostVideoCell {
    @objc private func likeTap() {
        delegate?.likePost(postID: post?.id ?? "")
    }

    @objc private func commentsTap() {
        Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromButton")
        if let post {
            delegate?.openPostComments(post: post)
        }
    }

    @objc private func moreTap() {
        if let post {
            delegate?.openPostActionSheet(post: post)
        }
    }
    
    @objc private func captionTap(_ sender: UITapGestureRecognizer) {
        if tapInTagRect(sender: sender) {
            /// profile open handled on function call
            return
        } else if moreShowing {
            Mixpanel.mainInstance().track(event: "PostPageExpandCaption")
            expandCaption()
        } else if let post {
            Mixpanel.mainInstance().track(event: "PostPageOpenCommentsFromCaption")
            delegate?.openPostComments(post: post)
        }
    }
    
    @objc private func userTap() {
        if let user = post?.userInfo {
            delegate?.openProfile(user: user)
        }
    }

    @objc func locationViewTap(_ sender: UITapGestureRecognizer) {
        locationView.stopAnimating()
        let location = sender.location(in: locationView)
        if mapButton.frame.contains(location), let mapID = post?.mapID, let mapName = post?.mapName {
            delegate?.openMap(mapID: mapID, mapName: mapName)
        } else if spotButton.frame.contains(location), let post = post {
            delegate?.openSpot(post: post)
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
        cancelLocationAnimation = true
        locationView.stopAnimating()
    }
    
    @objc private func playItem() {
        playerView.player?.seek(to: CMTime.zero)
        playerView.player?.play()
    }
    
    func reloadVideo() {
        guard let videoURL else {
            return
        }

        let player = AVPlayer(url: videoURL)
        playerView.player = player
        player.play()
        addNotifications()
    }

    func playOnDidDisplayCell() {
        playerView.player?.play()
        addNotifications()
    }
}
