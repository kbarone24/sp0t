//
//  ContentViewerCell.swift
//  Spot
//
//  Created by Kenny Barone on 1/26/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import Mixpanel
import FirebaseStorageUI

protocol ContentViewerDelegate: AnyObject {
    func openPostComments()
    func openProfile(user: UserProfile)
    func openMap(mapID: String, mapName: String)
    func openSpot(post: MapPost)
    func imageViewOffset(offset: Bool)
    func getSelectedPostIndex() -> Int
    func tapToPreviousPost()
    func tapToNextPost()
}

class ContentViewerCell: UITableViewCell {
    lazy var parentVC: PostParent = .Home
    public var post: MapPost?
    public var globalRow = 0
    public weak var delegate: ContentViewerDelegate?

    lazy var dotView = UIView()

    lazy var locationView = LocationScrollView()
    lazy var mapIcon = UIImageView(image: UIImage(named: "FeedMapIcon"))
    lazy var mapButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 16.5)
        button.contentVerticalAlignment = .center
        button.addTarget(self, action: #selector(mapTap), for: .touchUpInside)
        return button
    }()
    lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.25)
        return view
    }()
    lazy var spotIcon = UIImageView(image: UIImage(named: "FeedSpotIcon"))
    lazy var spotButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        // replace with actual font
        button.titleLabel?.font = UIFont(name: "UniversCE-Black", size: 16.5)
        button.addTarget(self, action: #selector(spotTap), for: .touchUpInside)
        return button
    }()
    lazy var cityLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.6)
        label.font = UIFont(name: "SFCompactText-Medium", size: 15)
        return label
    }()

    lazy var captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        label.isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(captionTap)))
        return label
    }()
    lazy var tagRect: [(rect: CGRect, username: String)] = []
    var moreShowing = false

    lazy var profileImage: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.layer.masksToBounds = true
        image.backgroundColor = .gray
        image.layer.cornerRadius = 33 / 2
        image.isUserInteractionEnabled = true
        image.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return image
    }()

    lazy var usernameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        // replace with actual font
        label.font = UIFont(name: "UniversCE-Black", size: 16.5)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userTap)))
        return label
    }()

    lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.font = UIFont(name: "SFCompactText-Medium", size: 14.5)
        return label
    }()

    lazy var currentImage = PostImagePreview()
    lazy var nextImage = PostImagePreview()
    lazy var previousImage = PostImagePreview()
    var cellOffset = false
    var imageSwiping = false {
        didSet {
            delegate?.imageViewOffset(offset: imageSwiping)
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .black
        setUpView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        animateLocation()
    }

    public func setUp(post: MapPost, parentVC: PostParent, row: Int) {
        self.post = post
        self.parentVC = parentVC
        globalRow = row

        setLocationView()
        setPostInfo()
        addDotView()
    }

    private func setUpView() {
        // lay out views from bottom to top
        contentView.addSubview(dotView)
        dotView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(3)
        }
        // location view subviews are added when cell is dequeued
        contentView.addSubview(locationView)
        locationView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(dotView.snp.top).offset(-10)
            $0.height.equalTo(32)
        }

        contentView.addSubview(captionLabel)
        captionLabel.snp.makeConstraints {
            $0.leading.equalTo(55)
            $0.bottom.equalTo(locationView.snp.top).offset(-15)
            $0.trailing.lessThanOrEqualTo(-18)
            $0.height.lessThanOrEqualTo(54)
          //  $0.height.greaterThanOrEqualTo(12)
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
    }
}
