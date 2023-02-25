//
//  ContentViewerCell.swift
//  Spot
//
//  Created by Kenny Barone on 1/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import Firebase
import Mixpanel
import FirebaseStorageUI
import AVFoundation

protocol ContentViewerDelegate: AnyObject {
    func likePost(postID: String)
    func openPostComments()
    func openPostActionSheet()
    func openProfile(user: UserProfile)
    func openMap(mapID: String, mapName: String)
    func openSpot(post: MapPost)
    func imageViewOffset(offset: Bool)
    func getSelectedPostIndex() -> Int
    func tapToPreviousPost()
    func tapToNextPost()
}

enum ContentViewerCellMode: Hashable {
    case video
    case image
}

final class ContentViewerCell: UITableViewCell {

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
    
    var cellOffset = false
    var imageSwiping = false {
        didSet {
            delegate?.imageViewOffset(offset: imageSwiping)
        }
    }

    var imagePan: UIPanGestureRecognizer?
    var imageTap: UITapGestureRecognizer?
    
    internal var tagRect: [(rect: CGRect, username: String)] = []
    var moreShowing = false
    private(set) lazy var dotView = UIView()
    private(set) lazy var locationView = LocationScrollView()
    private(set) lazy var mapIcon = UIImageView(image: UIImage(named: "FeedMapIcon"))
    private(set) lazy var spotIcon = UIImageView(image: UIImage(named: "FeedSpotIcon"))
    internal lazy var currentImage = PostImagePreview()
    internal lazy var nextImage = PostImagePreview()
    internal lazy var previousImage = PostImagePreview()

    internal var post: MapPost?
    var globalRow = 0
    var mode: ContentViewerCellMode = .image // Default
    weak var delegate: ContentViewerDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .black
        setUpView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        animateLocation()
    }

    func setUp(post: MapPost, row: Int, mode: ContentViewerCellMode) {
        self.post = post
        self.globalRow = row
        self.mode = mode
        
        getImages(mapPost: post)
        setLocationView()
        setPostInfo()
        setCommentsAndLikes()
        addDotView()
    }
    
    private func getImages(mapPost: MapPost) {
        guard mapPost.imageURLs.isEmpty else {
            return
        }
    }

    private func setUpView() {
        // lay out views from bottom to top
        contentView.addSubview(dotView)
        dotView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(3)
        }

        contentView.addSubview(buttonView)
        buttonView.snp.makeConstraints {
            $0.trailing.equalTo(-4)
            $0.bottom.equalTo(dotView.snp.top).offset(-12)
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
            $0.bottom.equalTo(dotView.snp.top).offset(-15)
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

    override func prepareForReuse() {
        super.prepareForReuse()
        stopLocationAnimation()
        resetImages()
    }

    func resetImages() {
        currentImage.image = UIImage(); currentImage.removeFromSuperview()
        nextImage.image = UIImage(); nextImage.removeFromSuperview()
        previousImage.image = UIImage(); previousImage.removeFromSuperview()

        contentView.removeGestureRecognizer(imagePan ?? UIPanGestureRecognizer())
        contentView.removeGestureRecognizer(imageTap ?? UITapGestureRecognizer())
    }
    
    func addDotView() {
        let frameCount = post?.frameIndexes?.count ?? 1
        let dotViewHeight: CGFloat = frameCount < 2 ? 0 : 3
        dotView.snp.updateConstraints {
            $0.height.equalTo(dotViewHeight)
        }
    }

    func addDots() {
        dotView.subviews.forEach {
            $0.removeFromSuperview()
        }

        let frameCount = post?.frameIndexes?.count ?? 1
        let spaces = CGFloat(6 * frameCount)
        let lineWidth = (UIScreen.main.bounds.width - spaces) / CGFloat(frameCount)
        var leading: CGFloat = 0

        for i in 0...(frameCount) - 1 {
            let line = UIView()
            line.backgroundColor = i <= post?.selectedImageIndex ?? 0 ? UIColor(named: "SpotGreen") : UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
            line.layer.cornerRadius = 1
            dotView.addSubview(line)
            line.snp.makeConstraints {
                $0.top.bottom.equalToSuperview()
                $0.leading.equalTo(leading)
                $0.width.equalTo(lineWidth)
            }
            leading += 7 + lineWidth
        }
    }

    func setLocationView() {
        locationView.stopAnimating()
        locationView.contentOffset.x = -locationView.contentInset.left
        for view in locationView.subviews { view.removeFromSuperview() }
        // add map if map exists unless parent == map
        var mapShowing = false
        if let mapName = post?.mapName, mapName != "" {
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
        if let spotName = post?.spotName, spotName != "" {
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
        cityLabel.text = post?.city ?? ""
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

    func setPostInfo() {
        // add caption and check for more buton after laying out subviews / frame size is determined
        captionLabel.attributedText = NSAttributedString(string: post?.caption ?? "")
        addCaptionAttString()

        // update username constraint with no caption -> will also move prof pic, timestamp
        if post?.caption.isEmpty ?? true {
            profileImage.snp.removeConstraints()
            profileImage.snp.makeConstraints {
                $0.leading.equalTo(14)
                $0.centerY .equalTo(usernameLabel)
                $0.height.width.equalTo(33)
            }
        }

        let transformer = SDImageResizingTransformer(size: CGSize(width: 100, height: 100), scaleMode: .aspectFill)
        profileImage.sd_setImage(with: URL(string: post?.userInfo?.imageURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])

        usernameLabel.text = post?.userInfo?.username ?? ""
        timestampLabel.text = post?.timestamp.toString(allowDate: true) ?? ""

        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }
    
    func setVideo(url: URL?) {
        guard let url, let post else { return }
        currentImage.configure(mode: .video(post, url))
    }
    
    func setImages(images: [UIImage]) {
        if images.isEmpty { return }
        var frameIndexes = post?.frameIndexes ?? []
        if let imageURLs = post?.imageURLs, !imageURLs.isEmpty {
            if frameIndexes.isEmpty { for i in 0...imageURLs.count - 1 { frameIndexes.append(i)} }
            post?.frameIndexes = frameIndexes
            post?.postImage = images

            addImageView()
        }
    }

    public func addCaptionAttString() {
        if let taggedUsers = post?.taggedUsers, !taggedUsers.isEmpty {
            // maxWidth = button view width (52) + spacing (12) + leading constraint (55)
            let attString = NSAttributedString.getAttString(caption: post?.caption ?? "", taggedFriends: taggedUsers, font: captionLabel.font, maxWidth: UIScreen.main.bounds.width - 159)
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

    func setCommentsAndLikes() {
        let liked = post?.likers.contains(UserDataModel.shared.uid) ?? false
        let likeImage = liked ? UIImage(named: "LikeButtonFilled") : UIImage(named: "LikeButton")

        numLikes.text = post?.likers.count ?? 0 > 0 ? String(post?.likers.count ?? 0) : ""
        likeButton.setImage(likeImage, for: .normal)

        let commentCount = max((post?.commentList.count ?? 0) - 1, 0)
        numComments.text = commentCount > 0 ? String(commentCount) : ""
    }

    private func addImageView() {
        guard let post else {
            return
        }
        
        currentImage = PostImagePreview(frame: .zero, index: post.selectedImageIndex ?? 0, parent: .ContentPage)
        contentView.addSubview(currentImage)
        contentView.sendSubviewToBack(currentImage)
        currentImage.configure(mode: .image(post))

        imageTap = UITapGestureRecognizer(target: self, action: #selector(imageTap(_:)))
        contentView.addGestureRecognizer(imageTap ?? UITapGestureRecognizer())

        if post.frameIndexes?.count ?? 0 > 1 {
            nextImage = PostImagePreview(frame: .zero, index: (post.selectedImageIndex ?? 0) + 1, parent: .ContentPage)
            contentView.addSubview(nextImage)
            contentView.sendSubviewToBack(nextImage)
            nextImage.configure(mode: .image(post))

            previousImage = PostImagePreview(frame: .zero, index: (post.selectedImageIndex ?? 0) - 1, parent: .ContentPage)
            contentView.addSubview(previousImage)
            contentView.sendSubviewToBack(previousImage)
            previousImage.configure(mode: .image(post))

            imagePan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            imagePan?.delegate = self
            contentView.addGestureRecognizer(imagePan ?? UIPanGestureRecognizer())
            addDots()
        }
    }
    // only called after user increments / decrements image
    func setImages() {
        guard let post else {
            return
        }
        
        let selectedIndex = post.selectedImageIndex ?? 0
        currentImage.index = selectedIndex
        currentImage.configure(mode: .image(post))

        previousImage.index = selectedIndex - 1
        previousImage.configure(mode: .image(post))

        nextImage.index = selectedIndex + 1
        nextImage.configure(mode: .image(post))
        addDots()
    }
}
