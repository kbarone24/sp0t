//
//  AnimatedImageCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit

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
            
            addTopMask()
            addBottomMask()
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func configure(animatedImages: [UIImage]) {
            imageView.animationImages = animatedImages
            imageView.animateGIF(directionUp: true, counter: 0)
        }
        
        private func addTopMask() {
            let topMask = UIView()
            addSubview(topMask)
            topMask.snp.makeConstraints {
                $0.leading.trailing.top.equalToSuperview()
                $0.height.equalTo(100)
            }
            let layer = CAGradientLayer()
            layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
            layer.colors = [
              UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
              UIColor(red: 0, green: 0, blue: 0.0, alpha: 0.45).cgColor
            ]
            layer.startPoint = CGPoint(x: 0.5, y: 1.0)
            layer.endPoint = CGPoint(x: 0.5, y: 0.0)
            layer.locations = [0, 1]
            topMask.layer.addSublayer(layer)
        }
        
        private func addBottomMask() {
            let bottomMask = UIView()
            addSubview(bottomMask)
            bottomMask.snp.makeConstraints {
                $0.leading.trailing.bottom.equalToSuperview()
                $0.height.equalTo(120)
            }
            let layer = CAGradientLayer()
            layer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
            layer.colors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.0).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.6).cgColor
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
