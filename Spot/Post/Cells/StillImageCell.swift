//
//  StillImageCell.swift
//  Spot
//
//  Created by Oforkanji Odekpe on 3/11/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

extension MapPostImageCell {
    final class StillImageCell: UICollectionViewCell {
        
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
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
        }
        
        func configure(imageURL: String) {
            imageView.sd_imageIndicator = SDWebImageActivityIndicator.whiteLarge
            imageView.sd_setImage(with: URL(string: imageURL), placeholderImage: nil)
        }

        func makeConstraints(aspectRatio: CGFloat) {
            let roundedAspect = imageView.getRoundedAspectRatio(aspect: aspectRatio)
            imageView.snp.removeConstraints()
            imageView.snp.makeConstraints {
                $0.leading.trailing.equalToSuperview()
                if roundedAspect >= UserDataModel.shared.maxAspect - 0.2 {
                    // stretch full size
                    $0.top.bottom.equalToSuperview()
                } else {
                    $0.height.equalTo(aspectRatio * UIScreen.main.bounds.width)
                    $0.centerY.equalToSuperview().offset(-46)
                }
            }
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            imageView.image = nil
            imageView.animationImages?.removeAll()
            imageView.animationImages = nil
            imageView.disableZoom()
        }
    }
}
