//
//  ContentViewerSetUp.swift
//  Spot
//
//  Created by Kenny Barone on 2/1/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit
import FirebaseStorageUI

extension ContentViewerCell {
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
        if let mapName = post?.mapName, mapName != "", parentVC != .Map {
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
        if let spotName = post?.spotName, spotName != "", parentVC != .Spot {
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

    // TODO: modify for video -> adding the image view only when images are ready should make it easier to add a video player instead of images if content type == video
    public func setContentData(images: [UIImage]) {
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

    func addImageView() {
        resetImages()
        currentImage = PostImagePreview(frame: .zero, index: post?.selectedImageIndex ?? 0, parent: .ContentPage)
        contentView.addSubview(currentImage)
        contentView.sendSubviewToBack(currentImage)
        currentImage.makeConstraints(post: post)
        currentImage.setCurrentImage(post: post)

        imageTap = UITapGestureRecognizer(target: self, action: #selector(imageTap(_:)))
        contentView.addGestureRecognizer(imageTap ?? UITapGestureRecognizer())

        if post?.frameIndexes?.count ?? 0 > 1 {
            nextImage = PostImagePreview(frame: .zero, index: (post?.selectedImageIndex ?? 0) + 1, parent: .ContentPage)
            contentView.addSubview(nextImage)
            contentView.sendSubviewToBack(nextImage)
            nextImage.makeConstraints(post: post)
            nextImage.setCurrentImage(post: post)

            previousImage = PostImagePreview(frame: .zero, index: (post?.selectedImageIndex ?? 0) - 1, parent: .ContentPage)
            contentView.addSubview(previousImage)
            contentView.sendSubviewToBack(previousImage)
            previousImage.makeConstraints(post: post)
            previousImage.setCurrentImage(post: post)

            imagePan = UIPanGestureRecognizer(target: self, action: #selector(imageSwipe(_:)))
            imagePan?.delegate = self
            contentView.addGestureRecognizer(imagePan ?? UIPanGestureRecognizer())
            addDots()
        }
    }
    // only called after user increments / decrements image
    func setImages() {
        let selectedIndex = post?.selectedImageIndex ?? 0
        currentImage.index = selectedIndex
        currentImage.makeConstraints(post: post)
        currentImage.setCurrentImage(post: post)

        previousImage.index = selectedIndex - 1
        previousImage.makeConstraints(post: post)
        previousImage.setCurrentImage(post: post)

        nextImage.index = selectedIndex + 1
        nextImage.makeConstraints(post: post)
        nextImage.setCurrentImage(post: post)
        addDots()
    }
}
