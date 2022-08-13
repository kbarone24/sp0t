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
    
    public var delegate: CustomMapBodyCellDelegate?
    
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
        }
    }
    
    public func cellSetup(mapPost: MapPost) {
        postImage.sd_setImage(with: URL(string: mapPost.imageURLs[0]))
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
            $0.backgroundColor = .gray
            contentView.addSubview($0)
        }
        postImage.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
