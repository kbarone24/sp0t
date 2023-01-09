//
//  PostImagePreview.swift
//  Spot
//
//  Created by Kenny Barone on 11/2/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import Foundation
import UIKit

final class PostImagePreview: PostImageView {
    var index: Int = 0

    convenience init(frame: CGRect, index: Int) {
        self.init(frame: frame)
        self.index = index

        contentMode = .scaleAspectFill
        clipsToBounds = true
        isUserInteractionEnabled = true
        layer.cornerRadius = 5
        backgroundColor = nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func makeConstraints() {
        snp.removeConstraints()

        guard let post = UploadPostModel.shared.postObject else { return }
        let currentImage = post.postImage[safe: post.frameIndexes?[safe: index] ?? -1] ??
        UIImage(color: .black, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)) ??
        UIImage()

        let currentAspect = (currentImage.size.height) / (currentImage.size.width)
        let layoutValues = getImageLayoutValues(imageAspect: currentAspect)
        let currentHeight = layoutValues.imageHeight
        let bottomConstraint = layoutValues.bottomConstraint

        snp.makeConstraints {
            $0.height.equalTo(currentHeight)
            $0.bottom.equalTo(-bottomConstraint)
            if index == post.selectedImageIndex {
                $0.leading.trailing.equalToSuperview()
            } else if index < post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(-UIScreen.main.bounds.width)
            } else if index > post.selectedImageIndex ?? 0 { $0.leading.trailing.equalToSuperview().offset(UIScreen.main.bounds.width) }
        }

        for sub in subviews { sub.removeFromSuperview() } /// remove any old masks
        if currentAspect > 1.45 { addTop() }
    }

    func setCurrentImage() {
        guard let post = UploadPostModel.shared.postObject else { return }
        let images = post.postImage
        let frameIndexes = post.frameIndexes ?? []

        animationImages?.removeAll()

        let still = images[safe: frameIndexes[safe: index] ?? -1] ??
        UIImage(color: UIColor(named: "SpotBlack") ?? .black, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)) ??
        UIImage()

        image = still
        stillImage = still

        let animationImages = getGifImages(selectedImages: images, frameIndexes: post.frameIndexes ?? [], imageIndex: index)
        self.animationImages = animationImages
        animationIndex = 0

        if !animationImages.isEmpty && !activeAnimation {
            animateGIF(directionUp: true, counter: animationIndex)
        }
    }

    func getGifImages(selectedImages: [UIImage], frameIndexes: [Int], imageIndex: Int) -> [UIImage] {
        /// return empty set of images if there's only one image for this frame index (still image), return all images at this frame index if there's more than 1 image
        guard let selectedFrame = frameIndexes[safe: imageIndex] else { return [] }

        if frameIndexes.count == 1 {
            return selectedImages.count > 1 ? selectedImages : []
        } else if frameIndexes.count - 1 == imageIndex {
            return selectedImages[selectedFrame] != selectedImages.last ? selectedImages.suffix(selectedImages.count - 1 - selectedFrame) : []
        } else {
            let frame1 = frameIndexes[imageIndex + 1]
            return frame1 - selectedFrame > 1 ? Array(selectedImages[selectedFrame...frame1 - 1]) : []
        }
    }

    func addTop() {
        let topMask = UIView {
            addSubview($0)
        }
        topMask.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(100)
        }
        let layer = CAGradientLayer()
        layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100)
        layer.colors = [
          UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
          UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.45).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.5, y: 1.0)
        layer.endPoint = CGPoint(x: 0.5, y: 0.0)
        layer.locations = [0, 1]
        topMask.layer.addSublayer(layer)
    }
}

