//
//  SpotPageBodyCell.swift
//  Spot
//
//  Created by Arnold on 8/10/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import SDWebImage

class SpotPageBodyCell: UICollectionViewCell {
    
    private var postImage: UIImageView!
    private var postID: String!
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
        if postImage != nil {
            postImage.image = UIImage()
            postImage.sd_cancelCurrentImageLoad()
        }
    }
    
    public func cellSetup(mapPost: MapPost) {
        let transformer = SDImageResizingTransformer(size: CGSize(width: UIScreen.main.bounds.width * 2/3, height: (UIScreen.main.bounds.width * 2/3) * 1.5), scaleMode: .aspectFill)
        postImage.sd_setImage(with: URL(string: mapPost.imageURLs.first ?? ""), placeholderImage: UIImage(color: UIColor(red: 0.957, green: 0.957, blue: 0.957, alpha: 1)), options: .highPriority, context: [.imageTransformer: transformer])
    }
}

extension SpotPageBodyCell {
    private func viewSetup() {
        contentView.backgroundColor = .white
        
        postImage = UIImageView {
            $0.image = UIImage()
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            $0.layer.cornerRadius = 2
            contentView.addSubview($0)
        }
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
