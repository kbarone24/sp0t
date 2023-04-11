//
//  SpotPageBodyCell.swift
//  Spot
//
//  Created by Arnold on 8/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import SDWebImage
import UIKit

class SpotPageBodyCell: UICollectionViewCell {
    private lazy var postImage: UIImageView = {
        let view = UIImageView()
        view.image = UIImage()
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 2
        return view
    }()

    private var postID = ""
    private var postData: MapPost?
    private lazy var fetching = false
    private lazy var imageManager = SDWebImageManager()

    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        postImage.image = UIImage()
        postImage.sd_cancelCurrentImageLoad()
    }

    public func cellSetup(mapPost: MapPost) {
        let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2 / 3, height: (UIScreen.main.bounds.width * 2 / 3) * 1.5), scaleMode: .aspectFill)
        postImage.sd_setImage(
            with: URL(string: mapPost.imageURLs.first ?? ""),
            placeholderImage: UIImage(color: .darkGray),
            options: .highPriority,
            context: [.imageTransformer: transformer])
    }
}

extension SpotPageBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = UIColor(named: "SpotBlack")
        contentView.addSubview(postImage)
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
