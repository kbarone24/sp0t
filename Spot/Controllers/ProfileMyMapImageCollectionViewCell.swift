//
//  ProfileMyMapImageCollectionViewCell.swift
//  Spot
//
//  Created by Arnold on 7/3/22.
//  Copyright © 2022 sp0t, LLC. All rights reserved.
//

import UIKit

class ProfileMyMapImageCollectionViewCell: UICollectionViewCell {
    var mapImageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        viewSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        
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
