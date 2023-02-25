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

    lazy var parentVC: PostParent = .Home
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

    func setUp(post: MapPost, parentVC: PostParent, row: Int, mode: ContentViewerCellMode) {
        self.post = post
        self.parentVC = parentVC
        self.globalRow = row
        self.mode = mode
        
        setLocationView()
        setPostInfo()
        setCommentsAndLikes()
        addDotView()
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
}
