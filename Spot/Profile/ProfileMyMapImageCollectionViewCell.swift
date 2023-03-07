//
//  ProfileMyMapImageCollectionViewCell.swift
//  Spot
//
//  Created by Arnold on 7/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

final class ProfileMyMapImageCollectionViewCell: UICollectionViewCell {
    var count: Int = 0
    var imageURL: String = "" {
        didSet {
            let scale: CGFloat = count == 9 ? 100 : count == 1 ? 200 : 150
            let transformer = SDImageResizingTransformer(size: CGSize(width: scale, height: scale), scaleMode: .aspectFill)
            mapImageView.sd_setImage(
                with: URL(string: imageURL),
                placeholderImage: UIImage(color: UIColor(named: "BlankImage") ?? .darkGray),
                options: .highPriority,
                context: [.imageTransformer: transformer])
        }
    }

    var mapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        mapImageView.sd_cancelCurrentImageLoad()
    }
}

extension ProfileMyMapImageCollectionViewCell {
    private func viewSetup() {
        contentView.addSubview(mapImageView)
        mapImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
