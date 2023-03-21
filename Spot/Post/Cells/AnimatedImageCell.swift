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

        private lazy var topMask = UIView()
        private lazy var bottomMask = UIView()
        
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
            if topMask.superview == nil { addTopMask() }
            if bottomMask.superview == nil { addBottomMask() }
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
        
        private func addTopMask() {
            topMask = UIView()
            addSubview(topMask)
            topMask.snp.makeConstraints {
                $0.leading.trailing.top.equalToSuperview()
                $0.height.equalTo(100)
            }
            let layer = CAGradientLayer()
            layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
            layer.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0.0, alpha: 1.0).cgColor
            ]
            layer.startPoint = CGPoint(x: 0.5, y: 1.0)
            layer.endPoint = CGPoint(x: 0.5, y: 0.0)
            layer.locations = [0, 1]
            topMask.layer.addSublayer(layer)
        }
        
        private func addBottomMask() {
            bottomMask = UIView()
            addSubview(bottomMask)
            bottomMask.snp.makeConstraints {
                $0.leading.trailing.bottom.equalToSuperview()
                $0.height.equalTo(120)
            }
            let layer = CAGradientLayer()
            layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
            layer.colors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 1.0).cgColor
            ]
            layer.locations = [0, 1]
            layer.startPoint = CGPoint(x: 0.5, y: 0)
            layer.endPoint = CGPoint(x: 0.5, y: 1.0)
            bottomMask.layer.addSublayer(layer)
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            imageView.image = nil
            imageView.animationImages?.removeAll()
            imageView.animationImages = nil
        }
    }
}
