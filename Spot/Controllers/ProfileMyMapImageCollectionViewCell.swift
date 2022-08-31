//
//  ProfileMyMapImageCollectionViewCell.swift
//  Spot
//
//  Created by Arnold on 7/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit
import FirebaseUI

class ProfileMyMapImageCollectionViewCell: UICollectionViewCell {
    var mapImageView: UIImageView!
    var count: Int = 0
    var imageURL: String = "" {
        didSet {
            let scale: CGFloat = count == 9 ? 100 : count == 1 ? 200 : 150
            print("scale", scale)
            let transformer = SDImageResizingTransformer(size: CGSize(width: scale, height: scale), scaleMode: .aspectFill)
            if mapImageView != nil { mapImageView.sd_setImage(with: URL(string: imageURL), placeholderImage: UIImage(color: UIColor(named: "BlankImage")!), options: .highPriority, context: [.imageTransformer: transformer]) }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        mapImageView.sd_cancelCurrentImageLoad()
    }
}

extension ProfileMyMapImageCollectionViewCell {
    private func viewSetup() {
        mapImageView = UIImageView {
            $0.contentMode = .scaleAspectFill
            $0.layer.masksToBounds = true
            self.addSubview($0)
        }
        mapImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
