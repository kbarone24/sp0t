//
//  AnimatedImageCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import PINCache
import SDWebImage

extension MapPostImageCell {
    final class AnimatedImageCell: UICollectionViewCell {
        private lazy var imageView: PostImageView = {
            let imageView = PostImageView(frame: .zero)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = true
            imageView.layer.cornerRadius = 5
            imageView.layer.masksToBounds = true
            imageView.backgroundColor = .black
            
            return imageView
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            
            contentView.addSubview(imageView)
            imageView.snp.makeConstraints {
                $0.leading.trailing.top.bottom.equalToSuperview()
            }
            
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
        }

        func configure(animatedImageURLs: [String]) {
            var animatedImages: [UIImage] = []
            _ = animatedImageURLs.map { url in
                if let image = PINCache.shared.object(forKey: url) as? UIImage {
                    animatedImages.append(image)
                }
            }
            
            if animatedImages.count > 2 {
                imageView.animationImages = animatedImages
                imageView.animateGIF(directionUp: true, counter: 0)
            } else {
                imageView.sd_imageIndicator = SDWebImageActivityIndicator.whiteLarge
                imageView.sd_setImage(with: URL(string: animatedImageURLs[0]), placeholderImage: nil)
            }
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            imageView.image = nil
            imageView.animationImages?.removeAll()
            imageView.animationImages = nil
        }
    }
}
