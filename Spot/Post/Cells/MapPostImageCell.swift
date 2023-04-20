//
//  MapPostImageCell.swift
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
import CoreLocation

protocol ContentViewerDelegate: AnyObject {
    func likePost(postID: String)
    func openPostComments(post: MapPost)
    func openPostActionSheet(post: MapPost)
    func openProfile(user: UserProfile)
    func openMap(mapID: String, mapName: String)
    func openSpot(post: MapPost)
    func joinMap(mapID: String)
}

final class MapPostImageCell: UICollectionViewCell {

    private(set) lazy var mapButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 15)
        button.contentVerticalAlignment = .center
        button.isUserInteractionEnabled = false
        //  button.addTarget(self, action: #selector(mapTap), for: .touchUpInside)
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
        button.isUserInteractionEnabled = false
        //  button.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
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
        button.setImage(UIImage(named: "FeedShareButton"), for: .normal)
        button.addTarget(self, action: #selector(moreTap), for: .touchUpInside)
        return button
    }()
    
    private lazy var photosCollectionView: CollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.sectionInsetReference = .fromContentInset
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.collectionView?.isPagingEnabled = true

        let collectionView = CollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.allowsSelection = false
        collectionView.imageDelegate = self
        collectionView.register(StillImageCell.self, forCellWithReuseIdentifier: StillImageCell.reuseID)
        collectionView.register(AnimatedImageCell.self, forCellWithReuseIdentifier: AnimatedImageCell.reuseID)
        
        return collectionView
    }()

    lazy var joinMapButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(configuration: configuration)
        button.setImage(UIImage(named: "FeedJoinButton"), for: .normal)
        button.addTarget(self, action: #selector(joinMapTap), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private(set) lazy var dotView = UIView()

    private lazy var topMask = UIView()
    private lazy var bottomMask = UIView()

    internal var tagRect: [(rect: CGRect, username: String)] = []
    var moreShowing = false
    private(set) lazy var locationView = LocationScrollView()
    private(set) lazy var mapIcon = UIImageView(image: UIImage(named: "FeedMapIcon"))
    private(set) lazy var spotIcon = UIImageView(image: UIImage(named: "FeedSpotIcon"))

    internal var post: MapPost?
    private var parentVC: PostParent = .AllPosts
    weak var delegate: ContentViewerDelegate?
    var cancelLocationAnimation = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        
        contentView.addSubview(photosCollectionView)
        photosCollectionView.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalToSuperview()
        }
        
        setUpView()

        layoutIfNeeded()
        addMasks()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func configure(post: MapPost, parent: PostParent, row: Int) {
        self.post = post
        self.parentVC = parent

        getImages(mapPost: post)
        setLocationView()
        setPostInfo()
        setCommentsAndLikes()
        addDotView()
    }
    
    private func getImages(mapPost: MapPost) {
        guard let snapshot = mapPost.imageCollectionSnapshot, let aspectRatios = mapPost.aspectRatios, !snapshot.itemIdentifiers.isEmpty else {
            return
        }

        photosCollectionView.configure(snapshot: snapshot, aspectRatios: aspectRatios)
        if mapPost.frameIndexes?.count ?? 0 > 1 {
            addDots(index: photosCollectionView.imageIndex)
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

        contentView.addSubview(joinMapButton)
        joinMapButton.snp.makeConstraints {
            $0.leading.equalTo(16)
            $0.trailing.equalTo(buttonView.snp.leading).offset(-14)
            $0.bottom.equalTo(dotView.snp.top).offset(-15)
        }

        // location view subviews are added when cell is dequeued
        locationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(locationViewTap)))
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

        contentView.addSubview(avatarImage)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopLocationAnimation()
        photosCollectionView.contentOffset.x = 0
        joinMapButton.isHidden = true
    }

    func setLocationView() {
        cancelLocationAnimation = false
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
                $0.height.equalToSuperview().inset(5)
                $0.centerY.equalToSuperview()
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
                $0.leading.equalTo(spotIcon.snp.trailing).offset(5)
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

        // animate location if necessary
        layoutIfNeeded()
    }

    func setPostInfo() {
        // add caption and check for more buton after laying out subviews / frame size is determined
        captionLabel.attributedText = NSAttributedString(string: post?.caption ?? "")
        addCaptionAttString()

        // update username constraint with no caption -> will also move prof pic, timestamp
        avatarImage.snp.removeConstraints()
        avatarImage.snp.makeConstraints {
            $0.leading.equalTo(13)
            $0.height.equalTo(40.5)
            $0.width.equalTo(36)
            if post?.caption.isEmpty ?? true {
                $0.centerY.equalTo(usernameLabel).offset(-3)
            } else {
                $0.top.equalTo(usernameLabel).offset(-6)
            }
        }

        if let image = post?.userInfo?.getAvatarImage(), image != UIImage() {
            avatarImage.image = image
        } else {
            let transformer = SDImageResizingTransformer(size: CGSize(width: 72, height: 81), scaleMode: .aspectFill)
            avatarImage.sd_setImage(with: URL(string: post?.userInfo?.avatarURL ?? ""), placeholderImage: nil, options: .highPriority, context: [.imageTransformer: transformer])
        }

        usernameLabel.text = post?.userInfo?.username ?? ""

        if parentVC == .Nearby, !UserDataModel.shared.currentLocation.coordinate.isEmpty() {
            let distance = max(CLLocation(latitude: post?.postLat ?? 0, longitude: post?.postLong ?? 0).distance(from: UserDataModel.shared.currentLocation), 1)
            timestampLabel.text = distance.getLocationString(allowFeet: false)
        } else {
            timestampLabel.text = post?.timestamp.toString(allowDate: true) ?? ""
        }

        let mapID = post?.mapID ?? ""
        joinMapButton.isHidden =
        (parentVC != .Nearby && parentVC != .AllPosts) ||
        (mapID == "" || !(post?.newMap ?? false) || UserDataModel.shared.userInfo.mapsList.contains(where: { $0.id == mapID }))
        updateLocationViewConstraints()
        
        contentView.layoutIfNeeded()
        addMoreIfNeeded()
    }

    func updateLocationViewConstraints() {
        locationView.snp.removeConstraints()
        locationView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.trailing.equalTo(buttonView.snp.leading).offset(-7)
            $0.height.equalTo(32)

            if joinMapButton.isHidden {
                $0.bottom.equalTo(dotView.snp.top).offset(-15)
            } else {
                $0.bottom.equalTo(joinMapButton.snp.top).offset(-8)
            }
        }
    }

    func addDotView() {
        let frameCount = post?.frameIndexes?.count ?? 1
        let dotViewHeight: CGFloat = frameCount < 2 ? 0 : 3
        dotView.snp.updateConstraints {
            $0.height.equalTo(dotViewHeight)
        }
    }

    func addDots(index: Int) {
        dotView.subviews.forEach {
            $0.removeFromSuperview()
        }

        let frameCount = post?.frameIndexes?.count ?? 0
        if frameCount < 2 { return }

        let spaces = CGFloat(6 * frameCount)
        let lineWidth = (UIScreen.main.bounds.width - spaces) / CGFloat(frameCount)
        var leading: CGFloat = 0

        for i in 0...(frameCount) - 1 {
            let line = UIView()
            line.backgroundColor = i <= index ? .white : UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
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

    private func addMasks() {
        if topMask.superview == nil { addTopMask() }
        if bottomMask.superview == nil { addBottomMask() }
    }

    private func addTopMask() {
        contentView.insertSubview(topMask, aboveSubview: photosCollectionView)
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
        contentView.insertSubview(bottomMask, aboveSubview: photosCollectionView)
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

extension MapPostImageCell: PostImageCollectionDelegate {
    func indexChanged(index: Int) {
        addDots(index: index)
    }
}
